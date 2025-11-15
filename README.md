# LexiCore - Personal Legal Intelligence Platform

> Your legal coach, not your lawyer. Democratizing legal literacy while maintaining strict ethical boundaries.

[![CI/CD](https://github.com/wholegrain/lexicore/actions/workflows/ci.yml/badge.svg)](https://github.com/wholegrain/lexicore/actions)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.3-blue.svg)](https://www.typescriptlang.org/)
[![Next.js](https://img.shields.io/badge/Next.js-16-black.svg)](https://nextjs.org/)
[![NestJS](https://img.shields.io/badge/NestJS-10-red.svg)](https://nestjs.com/)

---

## 🎯 Mission

LexiCore empowers New York residents to understand their legal rights, organize their legal matters, and train toward becoming attorneys—all while maintaining strict compliance with Unauthorized Practice of Law (UPL) regulations.

**What we do:**
- ✅ Educate citizens about their legal rights in plain language
- ✅ Help users organize legal matters with AI-assisted tools
- ✅ Train pre-law students and bar candidates with NextGen curriculum
- ✅ Connect users with verified, licensed attorneys when needed

**What we DON'T do:**
- ❌ Provide specific legal advice for individual cases
- ❌ Represent users in legal proceedings
- ❌ Replace licensed attorneys

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interfaces                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Web App    │  │  Mobile App  │  │  Admin Panel │     │
│  │  (Next.js)   │  │  (React Native)│  │  (Next.js)   │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
                    ┌────────▼────────┐
                    │   API Gateway   │
                    │   (NestJS)      │
                    └────────┬────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
    ┌─────▼─────┐     ┌──────▼──────┐    ┌────▼──────┐
    │ PostgreSQL│     │   Redis     │    │  OpenAI   │
    │ + pgvector│     │   Cache     │    │    API    │
    └───────────┘     └─────────────┘    └───────────┘
```

**Tech Stack:**
- **Frontend:** Next.js 16, React 19, TypeScript, Tailwind v4, shadcn/ui
- **Backend:** NestJS 10, Prisma ORM, PostgreSQL 16 (pgvector), Redis 7
- **AI/ML:** OpenAI GPT-4 Turbo, RAG with pgvector, LangChain
- **Infrastructure:** Fly.io, Docker, GitHub Actions
- **Monitoring:** Sentry, Grafana, Prometheus

---

## 🚀 Quick Start

### Prerequisites

- Node.js 20+
- Docker Desktop (for local databases)
- Python 3.11+ (for utility scripts)
- PostgreSQL 16+ (or use Docker)
- Redis 7+ (or use Docker)

### 1. Clone and Install

```bash
git clone https://github.com/wholegrain/lexicore.git
cd lexicore

# Run automated setup
./scripts/setup.sh
```

The setup script will:
- ✅ Install all npm dependencies
- ✅ Start Docker containers (PostgreSQL + Redis)
- ✅ Run database migrations
- ✅ Generate Prisma client
- ✅ Seed development data
- ✅ Verify TypeScript compilation

### 2. Configure Environment

```bash
# Edit .env.local with your API keys
nano .env.local
```

**Required API Keys:**
- `OPENAI_API_KEY` - Get from [OpenAI](https://platform.openai.com/api-keys)
- `CLERK_SECRET_KEY` - Get from [Clerk](https://clerk.com)
- `PEXELS_API_KEY` - Optional, for stock images

### 3. Start Development

```bash
# Start all services
npm run dev

# Or start individually:
npm run dev:web      # Web app on :3000
npm run dev:api      # API server on :3001
npm run dev:workers  # Background workers
```

**Access:**
- 🌐 Web App: http://localhost:3000
- 🔌 API: http://localhost:3001
- 📊 Prisma Studio: http://localhost:5555 (run `npx prisma studio`)

---

## 📁 Project Structure

```
lexicore/
├── apps/
│   ├── web/                    # Next.js 16 frontend
│   │   ├── src/
│   │   │   ├── app/           # App Router pages
│   │   │   ├── components/    # React components
│   │   │   ├── lib/           # API clients, hooks, utils
│   │   │   └── styles/        # Tailwind CSS
│   │   ├── public/            # Static assets
│   │   └── next.config.js
│   │
│   ├── api/                    # NestJS backend
│   │   ├── src/
│   │   │   ├── modules/       # Feature modules
│   │   │   │   ├── auth/
│   │   │   │   ├── users/
│   │   │   │   ├── matters/
│   │   │   │   ├── ai/
│   │   │   │   └── learning/
│   │   │   ├── common/        # Shared code
│   │   │   ├── config/        # Configuration
│   │   │   └── main.ts
│   │   └── test/              # E2E tests
│   │
│   ├── mobile/                 # React Native (Phase 2)
│   └── workers/                # Background job processors
│
├── packages/
│   ├── database/              # Prisma schema & migrations
│   │   ├── prisma/
│   │   │   ├── schema.prisma
│   │   │   ├── migrations/
│   │   │   └── seed.ts
│   │   └── src/
│   │
│   ├── types/                 # Shared TypeScript types
│   ├── ui/                    # Shared React components
│   └── config/                # Shared configs (ESLint, TS, etc.)
│
├── docs/                      # Documentation
│   ├── ARCHITECTURE.md        # System design
│   ├── DATABASE.md            # Schema & migrations
│   ├── DEPLOYMENT.md          # Deploy guide
│   ├── COMPLIANCE.md          # Legal safeguards
│   └── API.md                 # API specifications
│
├── agents/                    # Agent instruction files
│   ├── TECH_LEAD.md
│   ├── FRONTEND_WEB.md
│   ├── BACKEND_API.md
│   ├── AI_ENGINEER.md
│   ├── DEVOPS.md
│   └── QA.md
│
├── scripts/                   # Utility scripts
│   ├── setup.sh               # Dev environment setup
│   ├── fetch_images.py        # Stock image fetcher
│   └── deploy.sh              # Deployment script
│
├── .github/
│   └── workflows/
│       └── ci.yml             # CI/CD pipeline
│
├── docker-compose.yml         # Local development
├── package.json               # Monorepo root
└── turbo.json                 # Turborepo config
```

---

## 🧪 Testing

```bash
# Run all tests
npm test

# Run specific test suites
npm run test:unit              # Unit tests
npm run test:integration       # Integration tests
npm run test:e2e               # End-to-end tests (Playwright)

# Test coverage
npm run test:coverage

# Type checking
npm run type-check

# Linting
npm run lint
npm run lint:fix
```

**Test Coverage Goals:**
- Unit tests: >80% for business logic
- Integration tests: All API endpoints
- E2E tests: All critical user flows

---

## 🔒 Security & Compliance

### Unauthorized Practice of Law (UPL) Prevention

**Technical Safeguards:**
1. **Intent Classification** - Every AI query is classified before response
2. **Mandatory Disclaimers** - All AI content includes legal disclaimers
3. **High-Risk Flagging** - Criminal, eviction, custody cases auto-flagged
4. **Attorney Redirect** - Users seeking specific advice redirected to lawyers
5. **Audit Logging** - Every AI interaction logged for compliance

**Code Example:**
```typescript
if (intent === Intent.SEEKING_ADVICE) {
  return {
    response: "I can only provide general information. For your specific " +
              "case, please consult a licensed New York attorney.",
    action: "REDIRECT_TO_ATTORNEY_MARKETPLACE"
  };
}
```

### Data Privacy (GDPR/CCPA)

- ✅ User consent on signup
- ✅ Data export (right to access)
- ✅ Data deletion (right to be forgotten)
- ✅ Encryption at rest and in transit
- ✅ Minimal data collection
- ✅ 7-year audit log retention

### Attorney Verification

Licensed attorneys must provide:
- Bar number (verified against state records)
- Jurisdiction (must be active in NY)
- Malpractice insurance (proof of coverage)
- Verification by another attorney on platform

**See:** `docs/COMPLIANCE.md` for complete legal safeguards

---

## 🤖 AI Features & Safety

### RAG (Retrieval-Augmented Generation)

```typescript
// 1. Retrieve relevant legal documents
const docs = await vectorSearch(userQuery);

// 2. Build context with retrieved content only
const context = docs.map(d => d.content).join('\n\n');

// 3. Generate response with citations
const response = await openai.chat.completions.create({
  model: 'gpt-4-turbo-preview',
  messages: [
    { role: 'system', content: systemPrompt + context },
    { role: 'user', content: userQuery }
  ]
});

// 4. Add disclaimer and sources
return {
  answer: response.choices[0].message.content,
  sources: docs.map(d => d.metadata.source),
  disclaimer: "This is general information, not legal advice..."
};
```

### Prompt Injection Defense

```typescript
const INJECTION_PATTERNS = [
  /ignore (previous|all) instructions/i,
  /you are now/i,
  /system:/i,
  /act as (a|an) (lawyer|attorney)/i
];

if (detectPromptInjection(userQuery)) {
  throw new BadRequestException('Invalid query detected');
}
```

### Cost Control

- **Budget Tracking:** Monthly spend limit per user
- **Rate Limiting:** 10 queries/hour (free), 1000/month (paid)
- **Model Selection:** GPT-3.5 for classification, GPT-4 for generation
- **Token Limits:** Max 1000 output tokens
- **Caching:** Common queries cached in Redis

**Target:** <$0.50 per user per month

---

## 🚢 Deployment

### Environments

| Environment | URL | Database | Purpose |
|------------|-----|----------|---------|
| Local | localhost:3000 | Docker | Development |
| Staging | staging.lexicore.com | Fly.io Postgres | Testing |
| Production | lexicore.com | Fly.io Postgres | Live users |

### Deploy to Production

```bash
# 1. Push to main branch
git push origin main

# 2. GitHub Actions will:
#    - Run tests
#    - Build Docker images
#    - Deploy to staging
#    - Run smoke tests
#    - Wait for approval
#    - Deploy to production

# Or manual deploy:
./scripts/deploy.sh production
```

**See:** `docs/DEPLOYMENT.md` for complete deployment guide

---

## 📊 Monitoring

### Metrics Tracked

**Application:**
- Request rate, latency (p50, p95, p99)
- Error rate (<0.1% target)
- Active users, new signups

**AI:**
- Cost per user (<$0.50/month target)
- Tokens per request
- Response time
- Hallucination flags

**Business:**
- Matters created
- Attorney referrals
- Subscription conversions
- Bar prep engagement

### Dashboards

- **Grafana:** https://grafana.lexicore.com (metrics, alerts)
- **Sentry:** https://sentry.io/lexicore (error tracking)
- **Fly.io:** https://fly.io/dashboard (infrastructure)

---

## 👥 Team Roles & Agent Files

Each role has a detailed instruction file in `agents/`:

- **Tech Lead** (`agents/TECH_LEAD.md`) - Architecture, code reviews
- **Frontend Web** (`agents/FRONTEND_WEB.md`) - Next.js, React, UI
- **Backend API** (`agents/BACKEND_API.md`) - NestJS, Prisma, APIs
- **AI Engineer** (`agents/AI_ENGINEER.md`) - OpenAI, RAG, safety
- **DevOps** (`agents/DEVOPS.md`) - Infrastructure, deployment
- **QA** (`agents/QA.md`) - Testing, quality assurance

**Working with Agents:**
```bash
# Point agent to their specific file
"You are the Backend API Engineer. Follow agents/BACKEND_API.md"
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, data flows, tech decisions |
| [DATABASE.md](docs/DATABASE.md) | Prisma schema, migrations, optimization |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Production deployment guide |
| [COMPLIANCE.md](docs/COMPLIANCE.md) | Legal safeguards, UPL prevention |
| [API.md](docs/API.md) | Complete API endpoint specifications |
| [CLAUDE.md](docs/CLAUDE.md) | Working with Claude on this project |

---

## 🛣️ Roadmap

### Phase 1: MVP (Months 1-3) ✅
- [x] User authentication (Clerk)
- [x] Matter CRUD
- [x] Basic AI chat with disclaimers
- [x] Learning tracks (legal literacy)
- [ ] Lawyer marketplace MVP

### Phase 2: Core Features (Months 4-6)
- [ ] Advanced AI (RAG with legal corpus)
- [ ] Document analyzer (lease, contract, ticket)
- [ ] Bar prep curriculum (NextGen 2028)
- [ ] Attorney verification workflow
- [ ] Subscription billing (Stripe)

### Phase 3: Scale (Months 7-9)
- [ ] Mobile app (React Native)
- [ ] Real-time features (WebSockets)
- [ ] Multi-state support (beyond NY)
- [ ] Collaborative matter editing
- [ ] Advanced analytics

### Phase 4: Enterprise (Months 10-12)
- [ ] Law school partnerships
- [ ] Law firm SaaS offering
- [ ] White-label solution
- [ ] API for third-party integrations

---

## 🤝 Contributing

This is a proprietary project. For internal team contributions:

1. **Create feature branch:** `git checkout -b feature/your-feature`
2. **Follow conventions:** ESLint, Prettier, commit message format
3. **Write tests:** Unit + integration for all new code
4. **Update docs:** Keep documentation in sync
5. **Open PR:** Use PR template, request reviews
6. **Pass CI:** All tests must pass before merge

**Code Review Checklist:**
- [ ] Tests pass
- [ ] Type-safe (no `any` types)
- [ ] Authorization checks present
- [ ] AI features have disclaimers
- [ ] Audit logging for sensitive operations
- [ ] Documentation updated

---

## 🐛 Troubleshooting

### Common Issues

**Database connection fails:**
```bash
# Check Docker containers
docker-compose ps

# Restart PostgreSQL
docker-compose restart postgres

# Check connection string
echo $DATABASE_URL
```

**Prisma client out of sync:**
```bash
# Regenerate client
npx prisma generate

# Reset database (WARNING: deletes data)
npx prisma migrate reset
```

**AI queries failing:**
```bash
# Check OpenAI API key
echo $OPENAI_API_KEY

# Test API key
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

**Build fails:**
```bash
# Clear cache
rm -rf node_modules .next dist
npm install
npm run build
```

---

## 📄 License

Proprietary - All Rights Reserved

Copyright © 2025 LexiCore Inc.

---

## 🆘 Support

- **Documentation:** [docs/](docs/)
- **Issues:** [GitHub Issues](https://github.com/wholegrain/lexicore/issues)
- **Team Chat:** Slack #lexicore
- **Email:** dev@lexicore.com

---

## ⚖️ Legal Disclaimer

LexiCore provides general legal information and educational content only. **We do not provide legal advice for your specific situation.** Use of this platform does not create an attorney-client relationship. For advice about your case, consult a licensed attorney in your jurisdiction.

All AI-generated content may contain errors. Users are responsible for verifying information with licensed legal professionals before taking action.

---

**Built with ❤️ in New York**

*Empowering legal literacy, one user at a time.*
