# Deployment Guide

## Overview

LexiCore is deployed on **Fly.io** with PostgreSQL, Redis, and background workers. This guide covers deployment to staging and production environments.

## Prerequisites

- [ ] Fly.io account ([signup](https://fly.io/app/sign-up))
- [ ] Fly CLI installed (`brew install flyctl` or see [docs](https://fly.io/docs/hands-on/install-flyctl/))
- [ ] OpenAI API key
- [ ] Clerk/Auth0 account for authentication
- [ ] Stripe account for payments (production only)
- [ ] Sentry account for error tracking

## Environment Setup

### 1. Install Fly CLI
```bash
# macOS
brew install flyctl

# Linux
curl -L https://fly.io/install.sh | sh

# Windows
iwr https://fly.io/install.ps1 -useb | iex

# Login
fly auth login
```

### 2. Create Fly.io Apps
```bash
# API
fly apps create lexicore-api-staging
fly apps create lexicore-api-production

# Web
fly apps create lexicore-web-staging
fly apps create lexicore-web-production

# Workers
fly apps create lexicore-workers-staging
fly apps create lexicore-workers-production
```

### 3. Create PostgreSQL Database
```bash
# Staging
fly postgres create --name lexicore-db-staging --region ewr --vm-size shared-cpu-1x --volume-size 10

# Production
fly postgres create --name lexicore-db-production --region ewr --vm-size dedicated-cpu-2x --volume-size 50

# Enable pgvector extension
fly postgres connect -a lexicore-db-production
CREATE EXTENSION IF NOT EXISTS vector;
\q
```

### 4. Create Redis Instance
```bash
# Staging
fly redis create --name lexicore-redis-staging --region ewr --plan 100mb

# Production
fly redis create --name lexicore-redis-production --region ewr --plan 1gb
```

### 5. Attach Databases to Apps
```bash
# Attach Postgres to API
fly postgres attach lexicore-db-production --app lexicore-api-production

# Attach Redis to API
fly redis attach lexicore-redis-production --app lexicore-api-production
```

## Configuration Files

### fly.api.toml (API Server)
```toml
app = "lexicore-api-production"
primary_region = "ewr"
kill_signal = "SIGINT"
kill_timeout = 30

[build]
  dockerfile = "apps/api/Dockerfile"

[env]
  NODE_ENV = "production"
  PORT = "3001"

[[services]]
  internal_port = 3001
  protocol = "tcp"
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 2

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  [services.concurrency]
    type = "connections"
    hard_limit = 250
    soft_limit = 200

  [[services.tcp_checks]]
    interval = "15s"
    timeout = "2s"
    grace_period = "5s"

  [[services.http_checks]]
    interval = "10s"
    timeout = "2s"
    grace_period = "5s"
    method = "get"
    path = "/health"
    protocol = "http"

[[vm]]
  size = "shared-cpu-2x"
  memory = "512mb"

[deploy]
  strategy = "rolling"
  max_unavailable = 0.3
```

### fly.web.toml (Next.js Frontend)
```toml
app = "lexicore-web-production"
primary_region = "ewr"

[build]
  dockerfile = "apps/web/Dockerfile"

[env]
  NODE_ENV = "production"
  NEXT_PUBLIC_API_URL = "https://api.lexicore.com"

[[services]]
  internal_port = 3000
  protocol = "tcp"
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 2

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  [services.concurrency]
    type = "connections"
    hard_limit = 300
    soft_limit = 250

  [[services.http_checks]]
    interval = "10s"
    timeout = "2s"
    grace_period = "5s"
    method = "get"
    path = "/"

[[vm]]
  size = "shared-cpu-2x"
  memory = "512mb"

[deploy]
  strategy = "rolling"
```

### fly.workers.toml (Background Workers)
```toml
app = "lexicore-workers-production"
primary_region = "ewr"

[build]
  dockerfile = "apps/workers/Dockerfile"

[env]
  NODE_ENV = "production"

# No HTTP services, workers consume from queue

[[vm]]
  size = "shared-cpu-1x"
  memory = "256mb"

[deploy]
  strategy = "immediate"
```

## Secrets Management

### Set Production Secrets
```bash
APP="lexicore-api-production"

# Database (auto-set by fly postgres attach, but verify)
fly secrets list -a $APP | grep DATABASE_URL

# Redis (auto-set by fly redis attach)
fly secrets list -a $APP | grep REDIS_URL

# JWT
fly secrets set JWT_SECRET="$(openssl rand -base64 32)" -a $APP

# OpenAI
fly secrets set OPENAI_API_KEY="sk-proj-..." -a $APP

# Auth (Clerk)
fly secrets set CLERK_SECRET_KEY="sk_live_..." -a $APP

# Stripe
fly secrets set STRIPE_SECRET_KEY="sk_live_..." -a $APP
fly secrets set STRIPE_WEBHOOK_SECRET="whsec_..." -a $APP

# Sentry
fly secrets set SENTRY_DSN="https://...@sentry.io/..." -a $APP

# Verify secrets
fly secrets list -a $APP
```

### Set Web Secrets
```bash
APP="lexicore-web-production"

fly secrets set NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="pk_live_..." -a $APP
fly secrets set CLERK_SECRET_KEY="sk_live_..." -a $APP
```

## Database Migrations

### Run Migrations on Deploy
```bash
# 1. Generate migration locally
npx prisma migrate dev --name add_new_feature

# 2. Review generated SQL in prisma/migrations/

# 3. Test on staging first
DATABASE_URL=$(fly secrets list -a lexicore-api-staging | grep DATABASE_URL | awk '{print $3}') \
  npx prisma migrate deploy

# 4. If successful, deploy to production
DATABASE_URL=$(fly secrets list -a lexicore-api-production | grep DATABASE_URL | awk '{print $3}') \
  npx prisma migrate deploy
```

### Automated Migration in CI/CD
Add to GitHub Actions:
```yaml
- name: Run migrations
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}
  run: npx prisma migrate deploy
```

## Deployment Process

### Manual Deployment

#### 1. Deploy to Staging
```bash
# Build and deploy API
fly deploy -a lexicore-api-staging -c fly.api.toml

# Build and deploy Web
fly deploy -a lexicore-web-staging -c fly.web.toml

# Build and deploy Workers
fly deploy -a lexicore-workers-staging -c fly.workers.toml
```

#### 2. Run Smoke Tests
```bash
./scripts/smoke-test.sh https://staging.lexicore.com
```

#### 3. Deploy to Production
```bash
# Same commands with production app names
fly deploy -a lexicore-api-production -c fly.api.toml
fly deploy -a lexicore-web-production -c fly.web.toml
fly deploy -a lexicore-workers-production -c fly.workers.toml
```

### Automated Deployment (GitHub Actions)

See `.github/workflows/deploy.yml`:
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'

      - run: npm ci
      - run: npm run lint
      - run: npm run type-check
      - run: npm run test

  deploy-staging:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy API to Staging
        run: flyctl deploy -a lexicore-api-staging -c fly.api.toml
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}

      - name: Deploy Web to Staging
        run: flyctl deploy -a lexicore-web-staging -c fly.web.toml
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}

      - name: Run Smoke Tests
        run: ./scripts/smoke-test.sh https://staging-api.lexicore.com

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval
    steps:
      - uses: actions/checkout@v4
      - uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy API to Production
        run: flyctl deploy -a lexicore-api-production -c fly.api.toml
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}

      - name: Deploy Web to Production
        run: flyctl deploy -a lexicore-web-production -c fly.web.toml
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}

      - name: Health Check
        run: |
          curl -f https://api.lexicore.com/health || exit 1
          curl -f https://lexicore.com || exit 1
```

## Scaling

### Horizontal Scaling
```bash
# Scale API to 4 instances
fly scale count 4 -a lexicore-api-production

# Scale by region
fly scale count 2 --region ewr -a lexicore-api-production
fly scale count 2 --region lax -a lexicore-api-production

# Auto-scaling
fly autoscale set min=2 max=6 -a lexicore-api-production
fly autoscale balanced cpu=80 memory=80 -a lexicore-api-production
```

### Vertical Scaling
```bash
# Increase VM size
fly scale vm shared-cpu-4x -a lexicore-api-production

# Increase memory
fly scale memory 1024 -a lexicore-api-production
```

### Database Scaling
```bash
# Increase storage
fly volumes extend vol_xxx --size 100 -a lexicore-db-production

# Upgrade instance
fly postgres update -a lexicore-db-production --vm-size dedicated-cpu-4x
```

## Monitoring

### Check Application Status
```bash
# App status
fly status -a lexicore-api-production

# Recent logs
fly logs -a lexicore-api-production

# Real-time logs
fly logs -a lexicore-api-production --follow

# Filter logs
fly logs -a lexicore-api-production --follow | grep ERROR
```

### Metrics Dashboard
```bash
# Open Fly.io dashboard
fly dashboard -a lexicore-api-production

# Check metrics
fly metrics -a lexicore-api-production
```

### Health Checks
```bash
# API health
curl https://api.lexicore.com/health

# Expected response:
# {"status":"ok","database":"up","redis":"up","timestamp":"2025-01-14T..."}

# Web health
curl https://lexicore.com

# Metrics endpoint
curl https://api.lexicore.com/metrics
```

## Rollback Procedures

### Rollback to Previous Release
```bash
# List recent releases
fly releases -a lexicore-api-production

# Rollback to previous version
fly releases rollback -a lexicore-api-production

# Rollback to specific version
fly releases rollback v42 -a lexicore-api-production
```

### Emergency Rollback
```bash
#!/bin/bash
# scripts/emergency-rollback.sh

echo "🚨 Emergency Rollback"
echo "This will rollback API, Web, and Workers to previous release"
read -p "Continue? (yes/no) " confirm

if [ "$confirm" != "yes" ]; then
  exit 0
fi

fly releases rollback -a lexicore-api-production
fly releases rollback -a lexicore-web-production
fly releases rollback -a lexicore-workers-production

echo "✅ Rollback complete"
./scripts/smoke-test.sh https://api.lexicore.com
```

## Database Backup & Restore

### Manual Backup
```bash
# Backup production database
fly postgres connect -a lexicore-db-production -c "pg_dump lexicore" > backup_$(date +%Y%m%d_%H%M%S).sql

# Compress
gzip backup_*.sql

# Upload to S3
aws s3 cp backup_*.sql.gz s3://lexicore-backups/db/
```

### Automated Backups
Fly.io Postgres has automatic daily backups. To restore:
```bash
# List available backups
fly postgres backup list -a lexicore-db-production

# Restore from backup
fly postgres backup restore <backup-id> -a lexicore-db-production
```

### Point-in-Time Recovery
```bash
# Create restore point before risky operation
fly postgres connect -a lexicore-db-production
SELECT pg_create_restore_point('before_migration');
```

## Custom Domains

### Add Custom Domain
```bash
# Add domain
fly certs add lexicore.com -a lexicore-web-production
fly certs add api.lexicore.com -a lexicore-api-production

# Check cert status
fly certs show lexicore.com -a lexicore-web-production

# Add DNS records (from cert show output)
# Add A record pointing to Fly.io IP
# Add AAAA record for IPv6
```

### Configure DNS
```
# DNS Records (Cloudflare/Route53)
A     @     <fly-ip-from-cert-show>
AAAA  @     <fly-ipv6-from-cert-show>
A     api   <fly-ip-for-api>
AAAA  api   <fly-ipv6-for-api>
```

## Environment Variables Reference

### API Environment Variables
```bash
# Required
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
JWT_SECRET=...
OPENAI_API_KEY=sk-proj-...
CLERK_SECRET_KEY=sk_live_...

# Optional
SENTRY_DSN=https://...
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
LOG_LEVEL=info
ALLOWED_ORIGINS=https://lexicore.com,https://www.lexicore.com
```

### Web Environment Variables
```bash
# Required
NEXT_PUBLIC_API_URL=https://api.lexicore.com
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_...
CLERK_SECRET_KEY=sk_live_...

# Optional
NEXT_PUBLIC_SENTRY_DSN=https://...
NEXT_PUBLIC_GA_TRACKING_ID=G-...
```

## Cost Optimization

### Staging Environment
- Shared CPU instances (cheapest)
- Smaller database (10GB)
- Single region
- Auto-stop after inactivity
- Estimated cost: ~$50/month

### Production Environment
- Dedicated CPU for database
- 2x instances for redundancy
- Multi-region if needed
- Always-on
- Estimated cost: ~$200-500/month (depending on scale)

### Cost-Saving Tips
```bash
# Auto-stop staging apps when not in use
fly apps update lexicore-api-staging --auto-stop-machines=true

# Use shared CPU for workers
fly scale vm shared-cpu-1x -a lexicore-workers-production

# Monitor AI costs (biggest variable cost)
# Set up alerts in dashboard for OpenAI usage
```

## Disaster Recovery Plan

### RTO (Recovery Time Objective): 1 hour
### RPO (Recovery Point Objective): 1 day (daily backups)

### Disaster Scenarios

**1. Database Corruption**
```bash
# Restore from latest backup
fly postgres backup restore <latest-backup-id> -a lexicore-db-production
# Run migrations
npx prisma migrate deploy
# Restart app
fly apps restart lexicore-api-production
```

**2. Bad Deployment**
```bash
# Rollback immediately
fly releases rollback -a lexicore-api-production
fly releases rollback -a lexicore-web-production
```

**3. Region Outage**
```bash
# If primary region (ewr) is down, scale up in backup region
fly scale count 4 --region lax -a lexicore-api-production
# Update DNS to point to backup region
```

**4. Complete Platform Failure**
- Have database backups in S3 (separate from Fly.io)
- Docker images in GitHub Container Registry
- Can redeploy to different platform (Render, Railway, AWS) within hours

## Pre-Deployment Checklist

- [ ] All tests pass locally
- [ ] Database migrations tested on staging
- [ ] Environment variables set
- [ ] Secrets configured
- [ ] Custom domains configured
- [ ] SSL certificates valid
- [ ] Monitoring alerts configured
- [ ] Backup strategy in place
- [ ] Rollback plan documented
- [ ] Team notified of deployment window

## Post-Deployment Checklist

- [ ] Health checks pass
- [ ] Smoke tests pass
- [ ] No errors in Sentry
- [ ] Metrics look normal (latency, error rate)
- [ ] Database migrations completed
- [ ] Background jobs processing
- [ ] Email delivery working
- [ ] Payment processing working (if changed)
- [ ] Monitor for 30 minutes post-deploy

---

**Emergency Contacts:**
- On-call Engineer: [Phone/Slack]
- Database Admin: [Contact]
- Fly.io Support: https://fly.io/docs/about/support/

**Status Page:** https://status.lexicore.com (future)

**Incident Response:** See [INCIDENT_RESPONSE.md] (future)
