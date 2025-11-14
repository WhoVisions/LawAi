# LexiCore Architecture

## System Overview

LexiCore is a legal technology platform built as a monorepo with three primary applications:
- **Web App** (Next.js): User-facing web interface
- **API** (NestJS): Backend services and business logic
- **Workers** (NestJS): Background job processing

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Client Layer                          │
│  ┌────────────────┐           ┌────────────────┐        │
│  │   Web Browser  │           │  Mobile Device │        │
│  │   (Next.js)    │           │  (Future: RN)  │        │
│  └────────┬───────┘           └────────┬───────┘        │
└───────────┼──────────────────────────────┼───────────────┘
            │                              │
            │ HTTPS                        │ HTTPS
            │                              │
┌───────────▼──────────────────────────────▼───────────────┐
│                  CDN & Security                          │
│              (Cloudflare / Vercel Edge)                  │
└───────────┬──────────────────────────────┬───────────────┘
            │                              │
┌───────────▼──────────────────┐  ┌────────▼───────────────┐
│    Application Layer         │  │  Application Layer     │
│  ┌────────────────────────┐  │  │  ┌──────────────────┐  │
│  │  Next.js App           │  │  │  │  NestJS API      │  │
│  │  - SSR/SSG             │  │  │  │  - REST API      │  │
│  │  - Client Components   │  │  │  │  - Business Logic│  │
│  │  - Auth UI             │  │  │  │  - Auth/AuthZ    │  │
│  └────────────────────────┘  │  │  └──────────────────┘  │
└──────────────────────────────┘  └───────────┬────────────┘
                                              │
                    ┌─────────────────────────┼────────────────────┐
                    │                         │                    │
        ┌───────────▼────────┐   ┌───────────▼────────┐  ┌────────▼──────────┐
        │  Data Layer        │   │  Cache Layer       │  │  Queue Layer      │
        │  ┌──────────────┐  │   │  ┌──────────────┐  │  │  ┌─────────────┐  │
        │  │ PostgreSQL   │  │   │  │    Redis     │  │  │  │   BullMQ    │  │
        │  │  + pgvector  │  │   │  │  - Sessions  │  │  │  │  - Email    │  │
        │  │  - User data │  │   │  │  - Rate limit│  │  │  │  - AI jobs  │  │
        │  │  - Matters   │  │   │  │  - Cache     │  │  │  │  - Reports  │  │
        │  │  - AI logs   │  │   │  └──────────────┘  │  │  └─────────────┘  │
        │  └──────────────┘  │   └────────────────────┘  └───────────────────┘
        └────────────────────┘                                      │
                                                                    │
                                                        ┌───────────▼────────┐
                                                        │  Background Workers │
                                                        │  ┌──────────────┐   │
                                                        │  │  NestJS      │   │
                                                        │  │  - Consume   │   │
                                                        │  │    queues    │   │
                                                        │  │  - Send email│   │
                                                        │  │  - AI batch  │   │
                                                        │  └──────────────┘   │
                                                        └────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                      External Services                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │   OpenAI     │  │    Clerk     │  │   Stripe     │              │
│  │     API      │  │    Auth      │  │   Payments   │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
└──────────────────────────────────────────────────────────────────────┘
```

## Module Architecture

### Web App (Next.js)

```
apps/web/src/
├── app/                    # Next.js 16 App Router
│   ├── (marketing)/        # Public pages (/, /about, /pricing)
│   ├── (auth)/             # Auth pages (/sign-in, /sign-up)
│   └── (dashboard)/        # Protected app pages
│       ├── layout.tsx      # Dashboard shell
│       ├── home/
│       ├── matters/
│       ├── learn/
│       ├── tools/
│       └── settings/
├── components/
│   ├── ui/                 # shadcn/ui primitives
│   ├── layout/             # Layout components
│   ├── matters/            # Domain-specific components
│   ├── learning/
│   └── shared/             # Shared utilities
├── lib/
│   ├── api/                # API client & hooks
│   ├── hooks/              # Custom React hooks
│   └── utils/              # Utilities (cn, formatters, etc)
└── styles/
    └── globals.css         # Tailwind + custom styles
```

**Key Principles:**
- Server Components by default
- Client Components only when needed (interactivity, hooks)
- Data fetching in Server Components or via TanStack Query
- No business logic in components
- All API calls through typed client

### API (NestJS)

```
apps/api/src/
├── main.ts                 # Application entry
├── app.module.ts           # Root module
├── common/                 # Shared utilities
│   ├── decorators/
│   ├── filters/            # Exception filters
│   ├── guards/             # Auth & role guards
│   ├── interceptors/       # Logging, transform
│   └── pipes/              # Validation pipes
├── config/                 # Configuration modules
├── modules/
│   ├── auth/               # Authentication
│   ├── users/              # User management
│   ├── matters/            # Core domain
│   ├── ai/                 # AI orchestration
│   ├── learning/           # Bar prep & tracks
│   ├── documents/          # Document storage
│   ├── audit/              # Audit logging
│   └── admin/              # Admin features
└── database/
    └── prisma/             # Prisma client & migrations
```

**Key Principles:**
- Each module is self-contained
- Controllers handle HTTP, Services handle business logic
- All database access through Prisma
- Authorization at controller level (guards)
- All sensitive operations logged to audit table

### Workers (Background Jobs)

```
apps/workers/src/
├── main.ts
├── processors/
│   ├── email.processor.ts      # Send transactional emails
│   ├── ai-batch.processor.ts   # Batch AI processing
│   ├── reports.processor.ts    # Generate reports
│   └── cleanup.processor.ts    # Data cleanup jobs
└── shared/
    └── queue.config.ts
```

**Job Types:**
- **Email**: Transactional emails (welcome, password reset, notifications)
- **AI Batch**: Batch document analysis, embeddings generation
- **Reports**: Weekly summaries, usage reports
- **Cleanup**: Archive old data, delete expired sessions

## Data Flow Patterns

### Pattern 1: CRUD Operations
```
User Action (UI)
    │
    ▼
API Client (React Query)
    │
    ▼
API Controller (NestJS)
    │
    ├─→ Auth Guard (verify JWT)
    ├─→ Role Guard (check permissions)
    └─→ Validation Pipe (validate DTO)
    │
    ▼
Service Layer (business logic)
    │
    ▼
Prisma ORM
    │
    ▼
PostgreSQL
    │
    ▼
Return Response
    │
    ├─→ Transform Interceptor (format)
    └─→ Logging Interceptor (audit)
    │
    ▼
Client (update cache)
```

### Pattern 2: AI Request Flow
```
User Query (UI)
    │
    ▼
AI Controller
    │
    ├─→ Rate Limit Check (Redis)
    ├─→ Auth + Role Check
    ├─→ Budget Check (monthly usage)
    └─→ Input Sanitization
    │
    ▼
AI Service
    │
    ├─→ Prompt Injection Detection
    ├─→ Intent Classification (OpenAI fast model)
    └─→ Context Building (RAG if needed)
    │
    ▼
OpenAI API (GPT-4)
    │
    ▼
Post-processing
    │
    ├─→ Add Disclaimers
    ├─→ Filter Output
    └─→ Log to Audit Table
    │
    ▼
Return Response
    │
    └─→ Update Usage Metrics
```

### Pattern 3: Background Job
```
User Action (e.g., upload document)
    │
    ▼
API Controller
    │
    ├─→ Store file metadata in DB
    └─→ Enqueue job to BullMQ
    │
    ▼
Return 202 Accepted
    │
(async)
    │
    ▼
Worker Picks Up Job
    │
    ├─→ Process document
    ├─→ Generate embeddings
    └─→ Update DB
    │
    ▼
Notify User (via WebSocket or email)
```

## Security Architecture

### Authentication Flow
```
User Sign-in
    │
    ▼
Clerk Auth (or Auth0)
    │
    ├─→ Verify credentials
    └─→ Issue JWT
    │
    ▼
Store JWT in HTTP-only cookie
    │
    ▼
Every API request includes JWT
    │
    ├─→ JWT Strategy validates token
    ├─→ Extract user ID + roles
    └─→ Attach to request.user
```

### Authorization Layers

**Layer 1: Route-Level (Guards)**
```typescript
@Controller('matters')
@UseGuards(JwtAuthGuard, RolesGuard)
export class MattersController {
  @Get()
  @Roles('CITIZEN_USER', 'LICENSED_ATTORNEY')
  findAll() { ... }
}
```

**Layer 2: Resource-Level (Service)**
```typescript
async findOne(id: string, userId: string) {
  const matter = await this.prisma.matter.findUnique({ where: { id } });

  // Check ownership or participation
  if (matter.ownerId !== userId && !this.isParticipant(userId, matter)) {
    throw new ForbiddenException();
  }

  return matter;
}
```

**Layer 3: Field-Level (Serialization)**
```typescript
// Only attorneys see internal notes
@Exclude()
internalNotes: string;

@Expose({ groups: ['attorney'] })
get notes() {
  return this.internalNotes;
}
```

## Database Design Principles

### Schema Organization
- **Core tables**: `users`, `user_roles`, `user_settings`
- **Domain tables**: `matters`, `matter_participants`, `documents`, `timeline_events`
- **Learning**: `learning_tracks`, `user_progress`, `quiz_results`
- **AI**: `ai_usage_logs`, `ai_chat_history`, `legal_documents` (vector store)
- **Audit**: `audit_logs`, `events`

### Key Relationships
```
users (1) ──── (many) matters
users (many) ──── (many) matters  [via matter_participants]
matters (1) ──── (many) documents
matters (1) ──── (many) timeline_events
users (1) ──── (many) ai_usage_logs
```

### Data Isolation
- **Row-Level Security**: Enforce user access at DB level (future)
- **Soft Deletes**: `deletedAt` column instead of hard deletes
- **Audit Trail**: Immutable `audit_logs` table for compliance

## AI/ML Architecture

### RAG (Retrieval-Augmented Generation)
```
User Query
    │
    ▼
Generate Embedding (OpenAI text-embedding-3-small)
    │
    ▼
Vector Search in pgvector
    │
    ├─→ Find top 5 similar documents
    └─→ Filter by jurisdiction + type
    │
    ▼
Build Context (query + retrieved docs)
    │
    ▼
Generate Response (OpenAI GPT-4 + system prompt)
    │
    ▼
Return with Citations
```

### Prompt Engineering Strategy
- **System Prompts**: Stored in code, versioned
- **User Prompts**: Sanitized and validated
- **Context Window Management**: Limit to 4K tokens input
- **Temperature**: 0.7 for educational, 0.3 for document analysis

### Cost Control
- **Model Selection**: GPT-3.5 for classification, GPT-4 for generation
- **Token Limits**: Max 1000 output tokens per request
- **Caching**: Cache common queries (FAQs) in Redis
- **Budget Enforcement**: Track monthly spend per user, reject over budget

## Scalability Considerations

### Horizontal Scaling
- **Web**: Stateless, can run N instances
- **API**: Stateless, can run N instances
- **Workers**: Can run N consumers per queue

### Vertical Scaling
- **Database**: Increase instance size, add read replicas
- **Redis**: Cluster mode for high throughput

### Bottlenecks to Monitor
1. **OpenAI API rate limits** (tier dependent)
2. **Database connections** (use pooling, e.g., PgBouncer)
3. **Redis memory** (evict old cache, scale up)

## Monitoring & Observability

### Metrics to Track
- **Application**: Request rate, latency (p50, p95, p99), error rate
- **AI**: Cost per user, tokens per request, response time
- **Database**: Query time, connection pool usage, slow queries
- **Business**: Active users, matters created, AI queries, conversions

### Logging Strategy
- **Structured JSON logs**: Include `requestId`, `userId`, `timestamp`, `level`, `message`, `context`
- **Log Levels**:
  - ERROR: Exceptions, failures
  - WARN: Recoverable errors, rate limits hit
  - INFO: Key user actions (login, matter created)
  - DEBUG: Verbose (disabled in production)

### Alerting
- **Critical**: API down, database unreachable, error rate >1%
- **Warning**: High AI costs, slow queries, disk space >80%

## Deployment Architecture

### Environments
1. **Local**: Docker Compose
2. **Development**: Fly.io (single region, minimal resources)
3. **Staging**: Fly.io (prod-like config)
4. **Production**: Fly.io (multi-region, auto-scaling)

### Infrastructure as Code
- Fly.io configs in `fly.toml` files
- Database migrations in `prisma/migrations/`
- Secrets managed via Fly.io secrets (not in code)

### CI/CD Pipeline
```
Push to branch
    │
    ▼
GitHub Actions
    │
    ├─→ Lint & Type Check
    ├─→ Unit Tests
    ├─→ Build Docker Images
    └─→ Integration Tests
    │
    ▼
Merge to main
    │
    ▼
Deploy to Staging
    │
    ├─→ Run E2E Tests
    └─→ Smoke Tests
    │
    ▼
Manual Approval
    │
    ▼
Deploy to Production
    │
    ├─→ Rolling Update
    ├─→ Health Checks
    └─→ Rollback on Failure
```

## Technology Decisions

### Why Next.js 16?
- **App Router**: Better data fetching, streaming SSR
- **Server Components**: Reduce client JS bundle
- **Built-in optimization**: Images, fonts, analytics
- **Vercel ecosystem**: Easy deployment, edge functions

### Why NestJS?
- **TypeScript-first**: Type safety end-to-end
- **Modular architecture**: Clean separation of concerns
- **Dependency injection**: Testable code
- **Built-in patterns**: Guards, interceptors, pipes
- **OpenAPI support**: Auto-generate API docs

### Why PostgreSQL + pgvector?
- **Relational + Vector**: Single database for all data
- **ACID compliance**: Critical for legal data
- **Mature ecosystem**: Great tooling, monitoring
- **Cost-effective**: No separate vector DB required

### Why Redis?
- **Speed**: Sub-millisecond latency for sessions and cache
- **Versatility**: Sessions, rate limiting, queues, cache
- **Reliability**: Persistence options (RDB, AOF)

### Why OpenAI?
- **Best-in-class models**: GPT-4 for quality, GPT-3.5 for speed
- **Embedding API**: High-quality vectors for RAG
- **Reliability**: 99.9% uptime SLA
- **Safety**: Moderation API for content filtering

## Future Architecture Considerations

### Phase 2: Mobile App
- React Native with Expo
- Shared API, separate UI
- Offline-first for certain features (notes, checklist)

### Phase 3: Real-time Features
- WebSockets for live notifications
- Collaborative editing (multiple users on same matter)
- Live chat with attorneys

### Phase 4: Multi-tenancy
- Organizations/firms as tenants
- Separate data isolation per org
- Admin dashboards per org

### Phase 5: Advanced AI
- Fine-tuned models on legal corpus
- Custom embeddings for legal concepts
- Agentic workflows (AI that can take multi-step actions)

---

**Architecture Principles**
1. **Separation of Concerns**: UI, API, Data clearly separated
2. **Security First**: Auth/AuthZ at every layer
3. **Audit Everything**: Log all sensitive operations
4. **Fail Fast**: Validate early, return errors clearly
5. **Scale Gradually**: Start simple, add complexity as needed
