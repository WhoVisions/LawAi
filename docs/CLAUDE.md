# Working with Claude on LexiCore

This guide helps you collaborate effectively with Claude (AI assistant) on the LexiCore project.

## Quick Reference

**Project Type:** Legal Tech SaaS (AI-powered legal education platform)
**Compliance Focus:** UPL prevention, GDPR/CCPA, attorney-client privilege
**Tech Stack:** Next.js 16, NestJS 10, PostgreSQL 16, OpenAI GPT-4

---

## Starting a Session

When starting work with Claude, provide this context:

```
You're working on LexiCore, a legal AI coaching platform. Key constraints:

1. UPL Compliance: Never generate code that gives specific legal advice
2. All AI features MUST include disclaimers
3. High-risk matters (criminal, eviction) must be auto-flagged
4. Users cannot create matters for others (prevents UPL)
5. All sensitive operations must be audit-logged

Tech stack: Next.js 16 + NestJS 10 + PostgreSQL 16 (pgvector) + OpenAI

Current task: [describe your task]

Relevant docs: [link to specific doc, e.g., docs/COMPLIANCE.md]
```

---

## Task-Specific Prompts

### For Backend Development
```
Task: Add a new endpoint for [feature]

Context:
- File: apps/api/src/modules/[module]/[file].ts
- Must include: auth guard, role check, audit logging
- Refer to agents/BACKEND_API.md for patterns
- See docs/API.md for endpoint conventions

Requirements:
- TypeScript strict mode
- Prisma for database access
- NestJS decorators for validation
- Return standardized response format (see docs/API.md)
```

### For Frontend Development
```
Task: Build [component/page]

Context:
- Location: apps/web/src/[path]
- Use: Next.js 16 App Router, React 19, TypeScript
- UI: shadcn/ui components + Tailwind v4
- Refer to agents/FRONTEND_WEB.md for patterns

Requirements:
- Server Components by default
- Client Components only when needed (use 'use client')
- TanStack Query for data fetching
- Responsive design (mobile-first)
- Legal disclaimers on AI features
```

### For AI Features
```
Task: Implement AI [feature]

Context:
- This is a legal tech app - UPL compliance is critical
- Refer to agents/AI_ENGINEER.md and docs/COMPLIANCE.md
- All AI responses must be classified by intent
- See docs/API.md POST /ai/chat for expected behavior

Requirements:
- Intent classification before response
- Mandatory disclaimers
- Prompt injection detection
- Rate limiting
- Cost tracking
- Audit logging
```

### For Database Changes
```
Task: Add/modify database schema for [feature]

Context:
- ORM: Prisma
- Database: PostgreSQL 16 with pgvector
- Location: packages/database/prisma/schema.prisma
- Refer to docs/DATABASE.md for conventions

Steps:
1. Update schema.prisma
2. Create migration: npx prisma migrate dev --name [name]
3. Update seed.ts if needed
4. Document in docs/DATABASE.md
```

---

## Code Quality Standards

When asking Claude to write code, expect:

✅ **TypeScript:**
- Strict mode enabled
- No `any` types without justification
- Proper type imports from shared packages

✅ **Error Handling:**
- Try-catch for async operations
- Proper HTTP status codes
- User-friendly error messages

✅ **Security:**
- Authorization checks on all endpoints
- Input validation (Zod for DTOs)
- SQL injection prevention (Prisma handles this)
- XSS prevention (React handles this)

✅ **Testing:**
- Unit tests for business logic
- Integration tests for API endpoints
- E2E tests for critical flows

✅ **Documentation:**
- JSDoc comments for complex functions
- README updates for new features
- API docs updates for new endpoints

---

## Common Patterns

### Creating a New API Endpoint

```typescript
// 1. Create DTO
export class CreateMatterDto {
  @IsString()
  @MaxLength(200)
  title: string;

  @IsEnum(MatterType)
  type: MatterType;
}

// 2. Create Controller
@Controller('matters')
@UseGuards(JwtAuthGuard, RolesGuard)
export class MattersController {
  @Post()
  @Roles(Role.CITIZEN_USER)
  async create(@Body() dto: CreateMatterDto, @CurrentUser() user: User) {
    // Validation, authorization, business logic
    return this.mattersService.create({ ...dto, ownerId: user.id });
  }
}

// 3. Create Service
@Injectable()
export class MattersService {
  async create(data: CreateMatterDto & { ownerId: string }) {
    // Database operation
    const matter = await this.prisma.matter.create({ data });

    // Audit log
    await this.audit.log({
      userId: data.ownerId,
      eventType: 'MATTER_CREATED',
      entityId: matter.id
    });

    return matter;
  }
}

// 4. Write Tests
describe('MattersController', () => {
  it('should create matter', async () => {
    // Test implementation
  });

  it('should reject unauthorized user', async () => {
    // Test implementation
  });
});
```

### Adding a React Component

```typescript
// 1. Create Component
'use client';  // Only if needs interactivity

import { Card } from '@/components/ui/card';
import type { Matter } from '@/types';

interface MatterCardProps {
  matter: Matter;
}

export function MatterCard({ matter }: MatterCardProps) {
  return (
    <Card>
      <h3>{matter.title}</h3>
      <p>{matter.type}</p>
    </Card>
  );
}

// 2. Use in Page
import { MatterCard } from '@/components/matters/MatterCard';

export default async function MattersPage() {
  const matters = await getMatters();  // Server-side fetch

  return (
    <div>
      {matters.map(matter => (
        <MatterCard key={matter.id} matter={matter} />
      ))}
    </div>
  );
}
```

---

## Debugging with Claude

When you encounter an error:

```
I'm getting this error:

[paste error message]

File: [file path]
Context: [what you were trying to do]

Here's the relevant code:
[paste code snippet]

What am I missing?
```

Claude will:
- Analyze the error
- Check for common mistakes
- Suggest fixes
- Provide corrected code

---

## Legal Compliance Checklist

Before implementing any AI feature, ask Claude to verify:

- [ ] Intent classification implemented?
- [ ] Disclaimers added to all responses?
- [ ] High-risk cases auto-flagged?
- [ ] Audit logging in place?
- [ ] Rate limiting configured?
- [ ] Cost tracking enabled?
- [ ] Prompt injection detection active?

---

## Documentation Updates

When adding features, ask Claude to update:

1. **API docs** (`docs/API.md`) - If adding endpoints
2. **README** (`README.md`) - If changing setup/deployment
3. **Architecture** (`docs/ARCHITECTURE.md`) - If changing system design
4. **Database** (`docs/DATABASE.md`) - If changing schema

---

## Advanced: Multi-Step Tasks

For complex features, break into steps:

```
I need to implement the lawyer marketplace feature.

Step 1: Design the database schema
- Review docs/DATABASE.md for conventions
- Add lawyer_profiles, matter_referrals tables
- Show me the Prisma schema changes

[Wait for response, review, approve]

Step 2: Create the API endpoints
- POST /lawyers/profile (attorney creates profile)
- POST /matters/:id/refer (refer to attorney)
- GET /lawyers/matches (find matching attorneys)
- Follow patterns in agents/BACKEND_API.md

[Continue step by step]
```

---

## Testing with Claude

```
Write tests for [feature]

Requirements:
- Unit tests for [specific functions]
- Integration tests for [API endpoints]
- E2E tests for [user flows]

Use:
- Vitest for unit/integration
- Playwright for E2E
- Follow patterns in agents/QA.md
```

---

## Performance Optimization

```
This query is slow: [paste query]

Context:
- Database: PostgreSQL with [X] rows
- Current indexes: [list indexes]
- Expected load: [describe usage pattern]

Optimize for:
- Query time < 100ms
- Support for pagination
- Filter by [specific fields]
```

---

## Deployment Assistance

```
Help me deploy [feature] to production

Current state:
- Feature works in local dev
- Tests pass
- Ready to deploy

Steps needed:
1. Update environment variables?
2. Run database migrations?
3. Deploy order (API first? Web first?)
4. Rollback plan if issues?

See docs/DEPLOYMENT.md for our process.
```

---

## Common Pitfalls

**❌ Don't:**
- Ask Claude to "build the entire app"
- Provide no context about project structure
- Ignore the compliance requirements
- Skip tests "for speed"

**✅ Do:**
- Give specific, scoped tasks
- Reference relevant documentation
- Ask for tests alongside code
- Request explanation of design decisions

---

## Example Full Session

```
Session Goal: Add document analysis feature

Me: I need to add document analysis to the AI module.

Context:
- Users can upload documents to matters
- We want AI to analyze and extract key info
- See agents/AI_ENGINEER.md for AI patterns
- See docs/COMPLIANCE.md for legal requirements

Requirements:
1. POST /ai/analyze-document endpoint
2. Extract: document type, key facts, red flags
3. Return JSON with disclaimer
4. Log to audit table
5. Rate limit: 5/hour for free tier

Can you start with the NestJS service layer?

Claude: [Provides service code]

Me: Great! Now add the controller with proper guards and validation.

Claude: [Provides controller]

Me: Perfect. Now write integration tests.

Claude: [Provides tests]

Me: Excellent. Update docs/API.md with the new endpoint.

Claude: [Updates API docs]
```

---

## Resources

- **Agent Files:** `agents/` - Role-specific instructions
- **Architecture:** `docs/ARCHITECTURE.md` - System design
- **API Docs:** `docs/API.md` - Endpoint specifications
- **Database:** `docs/DATABASE.md` - Schema & migrations
- **Compliance:** `docs/COMPLIANCE.md` - Legal requirements

---

**Pro Tip:** Claude works best with clear, specific tasks and relevant context. When in doubt, reference the appropriate doc or agent file.
