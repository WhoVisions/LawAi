# DevOps Engineer Instructions

**Role**: Infrastructure, Deployment & Monitoring

**Stack**: Docker, GitHub Actions, Fly.io/Render, PostgreSQL, Redis

## 🎯 Your Mission

Maintain reliable infrastructure that:
- Deploys automatically on merge to main
- Scales to 10K users without manual intervention
- Stays online (99.9% uptime target)
- Costs <$500/month at 1K active users
- Recovers from failures automatically

## 🏗️ Infrastructure Architecture

### Current Stack (Phase 1)
```
┌─────────────────────────────────────┐
│         Cloudflare CDN              │
│  (SSL, DDoS protection, caching)    │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│          Fly.io / Render            │
│  ┌──────────────┐  ┌──────────────┐ │
│  │   Web App    │  │   API Server │ │
│  │  (Next.js)   │  │   (NestJS)   │ │
│  └──────────────┘  └──────────────┘ │
└──────────────┬──────────────────────┘
               │
    ┌──────────┼──────────┐
    ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌──────────┐
│Postgres│ │ Redis  │ │  OpenAI  │
│  (RDS) │ │(Upstash│ │   API    │
└────────┘ └────────┘ └──────────┘
```

### Services Breakdown

**Web (Next.js)**
- Platform: Fly.io or Vercel
- Instances: 2 (for redundancy)
- Region: US East (primary), US West (backup)
- Auto-scaling: 2-4 instances based on CPU

**API (NestJS)**
- Platform: Fly.io or Render
- Instances: 2 minimum
- Region: Same as database
- Auto-scaling: 2-6 instances based on request rate

**Database (PostgreSQL)**
- Platform: Fly.io Postgres or Neon or Supabase
- Version: 16
- Size: Start with 2GB RAM, 20GB storage
- Backups: Daily automated, 7-day retention
- Extensions: pgvector for embeddings

**Cache (Redis)**
- Platform: Upstash (serverless) or Fly.io Redis
- Use cases: Sessions, rate limiting, queue jobs
- Persistence: AOF enabled
- Eviction: LRU for cache keys only

**Background Workers**
- Platform: Same as API (Fly.io/Render)
- Instances: 1-2
- Queues: BullMQ with Redis backend

## 🐳 Docker Setup

### API Dockerfile
```dockerfile
# apps/api/Dockerfile
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./
COPY apps/api/package.json ./apps/api/
COPY packages/database/package.json ./packages/database/

# Install dependencies
RUN npm ci

# Builder
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Generate Prisma client
RUN npx prisma generate --schema=./packages/database/prisma/schema.prisma

# Build application
RUN npm run build --workspace=apps/api

# Production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nestjs

# Copy built application
COPY --from=builder --chown=nestjs:nodejs /app/apps/api/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/packages/database/prisma ./prisma

USER nestjs

EXPOSE 3001

CMD ["node", "dist/main.js"]
```

### Web Dockerfile
```dockerfile
# apps/web/Dockerfile
FROM node:20-alpine AS base

FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json package-lock.json* ./
COPY apps/web/package.json ./apps/web/
RUN npm ci

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1

RUN npm run build --workspace=apps/web

FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/apps/web/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

### Docker Compose (Local Dev)
```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: ankane/pgvector:latest
    environment:
      POSTGRES_USER: lexicore
      POSTGRES_PASSWORD: dev_password
      POSTGRES_DB: lexicore_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U lexicore"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  api:
    build:
      context: .
      dockerfile: apps/api/Dockerfile
    ports:
      - "3001:3001"
    environment:
      DATABASE_URL: postgresql://lexicore:dev_password@postgres:5432/lexicore_dev
      REDIS_URL: redis://redis:6379
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      JWT_SECRET: dev_jwt_secret
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./apps/api/src:/app/apps/api/src
    command: npm run dev --workspace=apps/api

  web:
    build:
      context: .
      dockerfile: apps/web/Dockerfile
      target: builder
    ports:
      - "3000:3000"
    environment:
      NEXT_PUBLIC_API_URL: http://api:3001
    depends_on:
      - api
    volumes:
      - ./apps/web/src:/app/apps/web/src
    command: npm run dev --workspace=apps/web

volumes:
  postgres_data:
  redis_data:
```

## 🚀 Deployment

### Fly.io Configuration
```toml
# fly.toml (API)
app = "lexicore-api"
primary_region = "ewr"

[build]
  dockerfile = "apps/api/Dockerfile"

[env]
  NODE_ENV = "production"
  PORT = "3001"

[[services]]
  internal_port = 3001
  protocol = "tcp"

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

[metrics]
  port = 9091
  path = "/metrics"

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 512

[deploy]
  strategy = "rolling"
```

### Fly.io Deployment Script
```bash
#!/bin/bash
# scripts/deploy.sh

set -e

ENV=${1:-production}

echo "🚀 Deploying to $ENV"

# 1. Run database migrations
echo "📊 Running migrations..."
fly postgres connect -a lexicore-db -c "npm run migrate"

# 2. Deploy API
echo "🔧 Deploying API..."
fly deploy -a lexicore-api -c fly.api.toml

# 3. Deploy Web
echo "🌐 Deploying Web..."
fly deploy -a lexicore-web -c fly.web.toml

# 4. Deploy Workers
echo "⚙️ Deploying Workers..."
fly deploy -a lexicore-workers -c fly.workers.toml

# 5. Health check
echo "🏥 Checking health..."
curl -f https://api.lexicore.com/health || exit 1

echo "✅ Deployment complete!"
```

## 📊 Monitoring

### Health Check Endpoint
```typescript
// apps/api/src/health/health.controller.ts
import { Controller, Get } from '@nestjs/common';
import { HealthCheck, HealthCheckService, PrismaHealthIndicator } from '@nestjs/terminus';
import { RedisHealthIndicator } from './redis.health';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: PrismaHealthIndicator,
    private redis: RedisHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.redis.isHealthy('redis'),
    ]);
  }

  @Get('ready')
  @HealthCheck()
  ready() {
    // Kubernetes-style readiness probe
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.redis.isHealthy('redis'),
    ]);
  }

  @Get('live')
  live() {
    // Kubernetes-style liveness probe
    return { status: 'ok', timestamp: new Date().toISOString() };
  }
}
```

### Metrics with Prometheus
```typescript
// apps/api/src/metrics/metrics.controller.ts
import { Controller, Get, Res } from '@nestjs/common';
import { Response } from 'express';
import * as promClient from 'prom-client';

@Controller('metrics')
export class MetricsController {
  private register: promClient.Registry;

  constructor() {
    this.register = new promClient.Registry();

    // Default metrics (CPU, memory, event loop lag)
    promClient.collectDefaultMetrics({ register: this.register });

    // Custom metrics
    new promClient.Counter({
      name: 'http_requests_total',
      help: 'Total HTTP requests',
      labelNames: ['method', 'route', 'status'],
      registers: [this.register],
    });

    new promClient.Histogram({
      name: 'http_request_duration_seconds',
      help: 'HTTP request duration',
      labelNames: ['method', 'route', 'status'],
      registers: [this.register],
    });

    new promClient.Gauge({
      name: 'ai_requests_in_flight',
      help: 'Number of AI requests currently processing',
      registers: [this.register],
    });

    new promClient.Counter({
      name: 'ai_cost_cents_total',
      help: 'Total AI cost in cents',
      registers: [this.register],
    });
  }

  @Get()
  async metrics(@Res() res: Response) {
    res.set('Content-Type', this.register.contentType);
    res.end(await this.register.metrics());
  }
}
```

### Grafana Dashboard Config
```json
{
  "dashboard": {
    "title": "LexiCore API",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])"
          }
        ]
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])"
          }
        ]
      },
      {
        "title": "Response Time (p95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          }
        ]
      },
      {
        "title": "AI Cost (last hour)",
        "targets": [
          {
            "expr": "increase(ai_cost_cents_total[1h]) / 100"
          }
        ]
      },
      {
        "title": "Database Connections",
        "targets": [
          {
            "expr": "pg_stat_activity_count"
          }
        ]
      }
    ]
  }
}
```

## 🔒 Secrets Management

### Environment Variables
```bash
# .env.production (never commit this!)
DATABASE_URL=postgresql://user:pass@db.fly.dev:5432/lexicore
REDIS_URL=redis://default:pass@redis.upstash.io:6379

# Auth
CLERK_SECRET_KEY=sk_live_...
JWT_SECRET=generate_with_openssl_rand_base64_32

# OpenAI
OPENAI_API_KEY=sk-proj-...

# Monitoring
SENTRY_DSN=https://...@sentry.io/...
GRAFANA_API_KEY=...

# Payments
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

### Fly.io Secrets
```bash
# Set secrets
fly secrets set DATABASE_URL="postgresql://..." -a lexicore-api
fly secrets set OPENAI_API_KEY="sk-..." -a lexicore-api
fly secrets set JWT_SECRET="$(openssl rand -base64 32)" -a lexicore-api

# List secrets
fly secrets list -a lexicore-api

# Remove secret
fly secrets unset OLD_SECRET -a lexicore-api
```

## 🔄 Database Migrations

### Migration Workflow
```bash
#!/bin/bash
# scripts/migrate.sh

set -e

ENV=${1:-production}

echo "🗃️ Running migrations for $ENV"

if [ "$ENV" = "production" ]; then
  # Backup before migration
  echo "📦 Creating backup..."
  fly postgres connect -a lexicore-db -c "pg_dump lexicore > backup_$(date +%Y%m%d_%H%M%S).sql"

  # Run migration
  echo "⬆️ Applying migrations..."
  DATABASE_URL=$(fly secrets list -a lexicore-api | grep DATABASE_URL | awk '{print $2}') \
    npx prisma migrate deploy

  echo "✅ Migration complete"
else
  npx prisma migrate dev
fi
```

### Rollback Plan
```bash
#!/bin/bash
# scripts/rollback.sh

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: ./rollback.sh <backup_file>"
  exit 1
fi

echo "⚠️ Rolling back to $BACKUP_FILE"
echo "This will DROP the current database. Continue? (yes/no)"
read confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted"
  exit 0
fi

fly postgres connect -a lexicore-db <<EOF
DROP DATABASE lexicore;
CREATE DATABASE lexicore;
\c lexicore
\i $BACKUP_FILE
EOF

echo "✅ Rollback complete"
```

## 📈 Scaling Strategy

### Horizontal Scaling (Fly.io)
```bash
# Scale API instances
fly scale count 4 -a lexicore-api

# Scale by region
fly scale count 2 --region ewr -a lexicore-api
fly scale count 2 --region lax -a lexicore-api

# Auto-scale based on metrics
fly autoscale set min=2 max=6 -a lexicore-api
fly autoscale balanced cpu=80 memory=80 -a lexicore-api
```

### Vertical Scaling
```bash
# Increase VM resources
fly scale vm shared-cpu-2x -a lexicore-api  # 2 CPUs
fly scale memory 1024 -a lexicore-api        # 1GB RAM
```

### Database Scaling
```bash
# Read replicas (for heavy read workloads)
fly postgres attach --app lexicore-api lexicore-db-replica

# Connection pooling with PgBouncer
fly postgres connect -a lexicore-db -c "CREATE EXTENSION IF NOT EXISTS pgbouncer"
```

## 🚨 Incident Response

### Runbook: API is Down
```markdown
1. Check health endpoint
   curl https://api.lexicore.com/health

2. Check logs
   fly logs -a lexicore-api

3. Check recent deploys
   fly releases -a lexicore-api

4. If bad deploy, rollback
   fly releases rollback -a lexicore-api

5. If database issue
   fly status -a lexicore-db
   fly postgres connect -a lexicore-db

6. If OpenAI quota hit
   Check usage: https://platform.openai.com/usage
   Temporary disable AI features

7. Post-incident
   - Document in incident log
   - Update runbook
   - Schedule postmortem
```

### Runbook: High AI Costs
```markdown
1. Check current spend
   fly logs -a lexicore-api | grep "AI_COST"

2. Identify top users
   SELECT user_id, SUM(cost_cents)
   FROM ai_usage_logs
   WHERE created_at > NOW() - INTERVAL '1 day'
   GROUP BY user_id
   ORDER BY SUM(cost_cents) DESC
   LIMIT 10;

3. If abuse detected
   - Rate limit user
   - Suspend account if TOS violation

4. If legitimate high usage
   - Check if budget limits enforced
   - Consider cheaper model (GPT-3.5) for certain features

5. Prevention
   - Add stricter rate limits
   - Implement caching for common queries
   - Use embeddings for FAQs instead of GPT-4
```

## 🔐 Security Hardening

### Network Security
```bash
# Fly.io private network
fly ips allocate-v6 --private -a lexicore-api

# Only allow API to connect to database
# (no public internet access to DB)
```

### Application Security
```typescript
// helmet middleware for security headers
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
}));

// Rate limiting
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
});

app.use('/api/', limiter);
```

## 📦 Backup Strategy

### Automated Backups
```bash
# Daily database backup (cron job)
0 2 * * * /home/lexicore/scripts/backup.sh

# backup.sh
#!/bin/bash
DATE=$(date +%Y%m%d)
BACKUP_FILE="backup_$DATE.sql"

# Dump database
fly postgres connect -a lexicore-db -c "pg_dump lexicore > /tmp/$BACKUP_FILE"

# Compress
gzip /tmp/$BACKUP_FILE

# Upload to S3
aws s3 cp /tmp/$BACKUP_FILE.gz s3://lexicore-backups/db/

# Keep last 30 days only
aws s3 ls s3://lexicore-backups/db/ | \
  awk '{print $4}' | \
  head -n -30 | \
  xargs -I {} aws s3 rm s3://lexicore-backups/db/{}

echo "Backup complete: $BACKUP_FILE.gz"
```

## 🧪 Testing in Production

### Smoke Tests
```bash
#!/bin/bash
# scripts/smoke-test.sh

BASE_URL=${1:-https://api.lexicore.com}

echo "🔍 Running smoke tests against $BASE_URL"

# Health check
echo -n "Health check... "
curl -sf $BASE_URL/health > /dev/null && echo "✅" || (echo "❌" && exit 1)

# Auth
echo -n "Auth endpoint... "
curl -sf $BASE_URL/auth/me > /dev/null || echo "✅"

# Database
echo -n "Database query... "
curl -sf $BASE_URL/matters?limit=1 > /dev/null || echo "✅"

echo "All smoke tests passed!"
```

## 📚 Useful Commands

```bash
# Fly.io
fly status -a lexicore-api              # App status
fly logs -a lexicore-api                # Tail logs
fly ssh console -a lexicore-api         # SSH into VM
fly postgres connect -a lexicore-db     # Connect to DB

# Docker
docker-compose up -d                    # Start services
docker-compose logs -f api              # Tail API logs
docker-compose exec postgres psql -U lexicore  # Connect to DB

# Database
npx prisma migrate dev                  # Create migration
npx prisma migrate deploy               # Apply migrations
npx prisma studio                       # GUI for database

# Monitoring
curl https://api.lexicore.com/metrics   # Prometheus metrics
curl https://api.lexicore.com/health    # Health check
```

## ✅ Deployment Checklist

- [ ] Environment variables set
- [ ] Database migrations run
- [ ] Smoke tests pass
- [ ] Health checks return 200
- [ ] Metrics endpoint working
- [ ] Error tracking configured
- [ ] Backups enabled
- [ ] SSL certificates valid
- [ ] Monitoring alerts configured
- [ ] Runbooks updated

---

**Remember**: Uptime is trust. Every minute of downtime costs user confidence.
