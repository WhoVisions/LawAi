# Database Schema Documentation

## Overview

LexiCore uses **PostgreSQL 16** with the **pgvector** extension for storing both relational data and vector embeddings.

**ORM**: Prisma
**Migrations**: Prisma Migrate
**Extensions**: pgvector (for AI embeddings)

## Core Tables

### users
Stores user account information.

```prisma
model User {
  id                String            @id @default(uuid())
  email             String            @unique
  name              String?
  authProviderId    String?           @unique // Clerk/Auth0 ID
  primaryRole       Role              @default(CITIZEN_USER)
  jurisdiction      String?           // e.g., "NY"
  createdAt         DateTime          @default(now())
  updatedAt         DateTime          @updatedAt
  deletedAt         DateTime?

  // Relations
  roles             UserRole[]
  settings          UserSettings?
  notifications     NotificationSettings?
  matters           Matter[]          @relation("OwnedMatters")
  participations    MatterParticipant[]
  aiUsage           AIUsageLog[]
  auditLogs         AuditLog[]
  learningProgress  UserLearningProgress[]

  @@index([email])
  @@index([authProviderId])
}
```

### user_roles
Junction table for user roles (supports multiple roles per user).

```prisma
enum Role {
  GUEST
  CITIZEN_USER
  PRELAW
  LAW_STUDENT
  LICENSED_ATTORNEY
  ORG_ADMIN
  SYSTEM_ADMIN
}

model UserRole {
  id          String    @id @default(uuid())
  userId      String
  role        Role
  verifiedAt  DateTime?
  verifierId  String?   // User ID of who verified (for attorneys)
  metadata    Json?     // e.g., { barNumber: "NY12345", jurisdiction: "NY" }
  createdAt   DateTime  @default(now())

  user        User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  verifier    User?     @relation("RoleVerifier", fields: [verifierId], references: [id])

  @@unique([userId, role])
  @@index([userId])
}
```

### user_settings
User preferences and configuration.

```prisma
model UserSettings {
  userId                  String    @id
  theme                   String    @default("dark") // "light" | "dark"
  language                String    @default("en")
  timezone                String    @default("America/New_York")
  allowAiTrainingOptIn    Boolean   @default(false)
  dataRetentionDays       Int       @default(365)
  updatedAt               DateTime  @updatedAt

  user                    User      @relation(fields: [userId], references: [id], onDelete: Cascade)
}
```

### notification_settings
User notification preferences.

```prisma
model NotificationSettings {
  userId                      String    @id
  emailEnabled                Boolean   @default(true)
  pushEnabled                 Boolean   @default(false)
  legalRemindersEnabled       Boolean   @default(true)
  learningRemindersEnabled    Boolean   @default(true)
  marketingEnabled            Boolean   @default(false)
  updatedAt                   DateTime  @updatedAt

  user                        User      @relation(fields: [userId], references: [id], onDelete: Cascade)
}
```

## Matters Domain

### matters
Core legal matters/cases.

```prisma
enum MatterType {
  LANDLORD_TENANT
  EMPLOYMENT
  CONSUMER
  TRAFFIC
  SMALL_CLAIMS
  CRIMINAL
  EVICTION
  CHILD_CUSTODY
  IMMIGRATION
  BANKRUPTCY
  FAMILY
  OTHER
}

enum MatterStatus {
  DRAFT
  ACTIVE
  NEEDS_ATTORNEY
  ATTORNEY_REVIEW
  RESOLVED
  ARCHIVED
}

enum RiskLevel {
  LOW
  NORMAL
  HIGH
}

model Matter {
  id            String          @id @default(uuid())
  ownerId       String
  title         String
  type          MatterType
  status        MatterStatus    @default(DRAFT)
  riskLevel     RiskLevel       @default(NORMAL)
  jurisdiction  String          // e.g., "NY"
  description   String?
  createdAt     DateTime        @default(now())
  updatedAt     DateTime        @updatedAt
  deletedAt     DateTime?

  // Relations
  owner         User            @relation("OwnedMatters", fields: [ownerId], references: [id])
  participants  MatterParticipant[]
  documents     Document[]
  timeline      TimelineEvent[]
  aiSessions    AIChatHistory[]

  @@index([ownerId])
  @@index([status])
  @@index([type])
}
```

### matter_participants
Who has access to a matter (e.g., assigned attorney).

```prisma
enum ParticipantRole {
  OWNER
  ATTORNEY
  COLLABORATOR
}

model MatterParticipant {
  id          String            @id @default(uuid())
  matterId    String
  userId      String
  role        ParticipantRole
  addedAt     DateTime          @default(now())

  matter      Matter            @relation(fields: [matterId], references: [id], onDelete: Cascade)
  user        User              @relation(fields: [userId], references: [id])

  @@unique([matterId, userId])
  @@index([userId])
}
```

### documents
Files uploaded to matters.

```prisma
enum DocumentType {
  LEASE
  CONTRACT
  TICKET
  NOTICE
  LETTER
  EVIDENCE
  OTHER
}

model Document {
  id            String        @id @default(uuid())
  matterId      String
  uploadedBy    String
  fileName      String
  fileSize      Int           // bytes
  mimeType      String
  storageUrl    String        // S3/Cloudflare R2 URL
  documentType  DocumentType  @default(OTHER)
  description   String?
  uploadedAt    DateTime      @default(now())

  matter        Matter        @relation(fields: [matterId], references: [id], onDelete: Cascade)

  @@index([matterId])
}
```

### timeline_events
Chronological events for a matter.

```prisma
model TimelineEvent {
  id            String    @id @default(uuid())
  matterId      String
  date          DateTime
  title         String
  description   String?
  createdBy     String
  createdAt     DateTime  @default(now())

  matter        Matter    @relation(fields: [matterId], references: [id], onDelete: Cascade)

  @@index([matterId, date])
}
```

## AI & Learning

### ai_usage_logs
Track AI usage for billing and compliance.

```prisma
model AIUsageLog {
  id                String    @id @default(uuid())
  userId            String
  model             String    // e.g., "gpt-4-turbo-preview"
  promptTokens      Int
  completionTokens  Int
  costCents         Int       // Cost in cents
  metadata          Json?     // { feature: "chat", matterId: "..." }
  createdAt         DateTime  @default(now())

  user              User      @relation(fields: [userId], references: [id])

  @@index([userId, createdAt])
  @@index([createdAt])
}
```

### ai_chat_history
Store AI chat messages for audit and context.

```prisma
model AIChatHistory {
  id            String    @id @default(uuid())
  matterId      String?
  userId        String
  role          String    // "user" | "assistant" | "system"
  content       String
  metadata      Json?     // { model: "gpt-4", tokens: 123 }
  createdAt     DateTime  @default(now())

  matter        Matter?   @relation(fields: [matterId], references: [id], onDelete: Cascade)

  @@index([matterId, createdAt])
  @@index([userId, createdAt])
}
```

### legal_documents (Vector Store)
Store legal content with embeddings for RAG.

```prisma
model LegalDocument {
  id            String    @id @default(uuid())
  content       String    // The actual text
  embedding     Unsupported("vector(1536)") // pgvector field
  metadata      Json      // { source: "NY statute 123", jurisdiction: "NY", type: "statute" }
  createdAt     DateTime  @default(now())

  @@index([metadata(ops: JsonbOps)])
}
```

**Note**: In actual Prisma schema, use raw SQL for vector type:
```sql
CREATE TABLE legal_documents (
  id UUID PRIMARY KEY,
  content TEXT NOT NULL,
  embedding vector(1536),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON legal_documents USING ivfflat (embedding vector_cosine_ops);
```

### learning_tracks
Structured learning paths.

```prisma
enum TrackType {
  LEGAL_LITERACY
  PRELAW
  BAR_PREP
}

model LearningTrack {
  id            String              @id @default(uuid())
  title         String
  description   String?
  type          TrackType
  jurisdiction  String              @default("NY")
  order         Int                 @default(0)
  published     Boolean             @default(false)
  createdAt     DateTime            @default(now())

  lessons       Lesson[]
  userProgress  UserLearningProgress[]
}

model Lesson {
  id          String        @id @default(uuid())
  trackId     String
  title       String
  content     String        // Markdown or HTML
  order       Int           @default(0)
  estimatedMinutes Int       @default(15)

  track       LearningTrack @relation(fields: [trackId], references: [id], onDelete: Cascade)

  @@index([trackId, order])
}

model UserLearningProgress {
  id            String        @id @default(uuid())
  userId        String
  trackId       String
  lessonId      String?
  completed     Boolean       @default(false)
  score         Int?          // 0-100
  timeSpentSec  Int           @default(0)
  lastAccessedAt DateTime     @default(now())

  user          User          @relation(fields: [userId], references: [id])
  track         LearningTrack @relation(fields: [trackId], references: [id])

  @@unique([userId, trackId, lessonId])
  @@index([userId])
}
```

## Audit & Compliance

### audit_logs
Immutable log of all sensitive actions.

```prisma
model AuditLog {
  id          String    @id @default(uuid())
  userId      String?
  eventType   String    // e.g., "MATTER_CREATED", "AI_QUERY", "ROLE_CHANGED"
  entityType  String?   // e.g., "MATTER", "USER"
  entityId    String?
  metadata    Json?     // Full context of the event
  ipAddress   String?
  userAgent   String?
  timestamp   DateTime  @default(now())

  user        User?     @relation(fields: [userId], references: [id])

  @@index([userId, timestamp])
  @@index([eventType, timestamp])
  @@index([entityType, entityId])
}
```

## Subscriptions & Billing

### subscriptions
User subscription plans.

```prisma
enum SubscriptionTier {
  FREE
  CITIZEN
  PRELAW
  BAR_PREP
  LAWYER_PRO
}

enum SubscriptionStatus {
  ACTIVE
  CANCELED
  PAST_DUE
  PAUSED
}

model Subscription {
  id                String              @id @default(uuid())
  userId            String              @unique
  tier              SubscriptionTier    @default(FREE)
  status            SubscriptionStatus  @default(ACTIVE)
  stripeCustomerId  String?
  stripeSubscriptionId String?
  currentPeriodStart DateTime
  currentPeriodEnd   DateTime
  cancelAt          DateTime?
  createdAt         DateTime            @default(now())
  updatedAt         DateTime            @updatedAt

  @@index([userId])
  @@index([status])
}
```

## Indexes Strategy

### Performance Indexes
```sql
-- Fast user lookup
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_auth_provider ON users(auth_provider_id);

-- Matter queries
CREATE INDEX idx_matters_owner ON matters(owner_id);
CREATE INDEX idx_matters_status ON matters(status);
CREATE INDEX idx_matters_type ON matters(type);
CREATE INDEX idx_matters_updated ON matters(updated_at DESC);

-- AI usage tracking
CREATE INDEX idx_ai_usage_user_date ON ai_usage_logs(user_id, created_at DESC);
CREATE INDEX idx_ai_usage_date ON ai_usage_logs(created_at DESC);

-- Audit queries
CREATE INDEX idx_audit_user_time ON audit_logs(user_id, timestamp DESC);
CREATE INDEX idx_audit_event_time ON audit_logs(event_type, timestamp DESC);

-- Vector search (pgvector)
CREATE INDEX ON legal_documents USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100); -- Tune based on data size
```

### Partial Indexes (for common queries)
```sql
-- Active matters only
CREATE INDEX idx_active_matters ON matters(owner_id, updated_at DESC)
  WHERE deleted_at IS NULL AND status != 'ARCHIVED';

-- Recent AI logs (last 30 days)
CREATE INDEX idx_recent_ai_usage ON ai_usage_logs(user_id, cost_cents)
  WHERE created_at > NOW() - INTERVAL '30 days';
```

## Migration Strategy

### Initial Migration
```bash
npx prisma migrate dev --name init
```

### Adding New Fields
```bash
# 1. Update schema.prisma
# 2. Create migration
npx prisma migrate dev --name add_matter_risk_level

# 3. Review generated SQL
# 4. Apply to production
npx prisma migrate deploy
```

### Data Migrations
For complex data transformations, create a separate migration script:

```typescript
// prisma/migrations/20250114_backfill_risk_levels.ts
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const highRiskTypes = ['CRIMINAL', 'EVICTION', 'CHILD_CUSTODY'];

  await prisma.matter.updateMany({
    where: {
      type: { in: highRiskTypes },
      riskLevel: 'NORMAL', // Only update if not already set
    },
    data: {
      riskLevel: 'HIGH',
    },
  });

  console.log('Risk levels backfilled');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
```

Run with: `tsx prisma/migrations/20250114_backfill_risk_levels.ts`

## Backup & Recovery

### Automated Backups
```bash
#!/bin/bash
# Daily backup at 2 AM
0 2 * * * /usr/local/bin/backup-db.sh

# backup-db.sh
pg_dump $DATABASE_URL > backup_$(date +\%Y\%m\%d).sql
gzip backup_$(date +\%Y\%m\%d).sql
aws s3 cp backup_$(date +\%Y\%m\%d).sql.gz s3://lexicore-backups/
```

### Point-in-Time Recovery
Fly.io Postgres and most managed databases support PITR:
```bash
# Restore to specific timestamp
fly postgres connect -a lexicore-db
SELECT pg_create_restore_point('before_bad_migration');
```

## Seed Data

### Development Seed
```typescript
// prisma/seed.ts
import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  // Create test users
  const citizen = await prisma.user.create({
    data: {
      email: 'citizen@example.com',
      name: 'Test Citizen',
      roles: {
        create: { role: Role.CITIZEN_USER },
      },
    },
  });

  const attorney = await prisma.user.create({
    data: {
      email: 'attorney@example.com',
      name: 'Test Attorney',
      roles: {
        create: [
          { role: Role.CITIZEN_USER },
          { role: Role.LICENSED_ATTORNEY, metadata: { barNumber: 'NY12345' } },
        ],
      },
    },
  });

  // Create sample matters
  await prisma.matter.create({
    data: {
      ownerId: citizen.id,
      title: 'Landlord Not Fixing Heat',
      type: 'LANDLORD_TENANT',
      jurisdiction: 'NY',
      description: 'Heat has been out for 2 weeks',
      status: 'ACTIVE',
    },
  });

  // Create learning tracks
  await prisma.learningTrack.create({
    data: {
      title: 'Know Your Rights: NY Tenant Law',
      type: 'LEGAL_LITERACY',
      jurisdiction: 'NY',
      published: true,
      lessons: {
        create: [
          {
            title: 'Introduction to Tenant Rights',
            content: '# Welcome\n\nThis track covers...',
            order: 1,
            estimatedMinutes: 15,
          },
          {
            title: 'Heat and Hot Water Requirements',
            content: '# Heat Requirements\n\nIn New York...',
            order: 2,
            estimatedMinutes: 20,
          },
        ],
      },
    },
  });

  console.log('Seed data created');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
```

Run with: `npx prisma db seed`

## Query Optimization Tips

### Use `select` to limit fields
```typescript
// BAD - fetches all fields
const user = await prisma.user.findUnique({ where: { id } });

// GOOD - only fetch what you need
const user = await prisma.user.findUnique({
  where: { id },
  select: { id: true, email: true, name: true },
});
```

### Avoid N+1 queries with `include`
```typescript
// BAD - N+1 query
const matters = await prisma.matter.findMany();
for (const matter of matters) {
  matter.owner = await prisma.user.findUnique({ where: { id: matter.ownerId } });
}

// GOOD - single query
const matters = await prisma.matter.findMany({
  include: { owner: true },
});
```

### Use cursors for pagination
```typescript
// For large datasets, cursor-based pagination is more efficient
const matters = await prisma.matter.findMany({
  take: 20,
  cursor: lastMatterId ? { id: lastMatterId } : undefined,
  orderBy: { createdAt: 'desc' },
});
```

## Schema Evolution Guidelines

1. **Never drop columns without migration plan** - Use soft deletes first
2. **Add new columns as nullable** - Backfill data in separate step
3. **Test migrations on staging first** - Always
4. **Keep migrations small** - One logical change per migration
5. **Document breaking changes** - In migration file comments

---

**Database Health Metrics to Monitor:**
- Connection pool usage (should stay <80%)
- Slow query log (queries >1s need optimization)
- Index hit rate (should be >99%)
- Table bloat (vacuum regularly)
- Replication lag (if using replicas)
