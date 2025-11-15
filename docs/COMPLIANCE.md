# Legal Compliance & Safety Guide

## Overview

LexiCore operates in a highly regulated space (legal services). This document outlines the technical and operational safeguards to ensure we stay compliant with:

- **Unauthorized Practice of Law (UPL)** regulations
- **Data privacy laws** (GDPR, CCPA)
- **Professional ethics rules** (ABA Model Rules, NY Bar Rules)
- **AI safety standards**

## Unauthorized Practice of Law (UPL) Prevention

### What Constitutes UPL in New York

Per NY Court Rules Part 1200 and UPL opinions, the following are considered UPL:

❌ **Prohibited Actions:**
- Giving specific legal advice tailored to a person's case
- Representing someone in legal proceedings without a license
- Preparing legal documents for filing (unless under attorney supervision)
- Predicting outcomes of legal disputes
- Interpreting laws or court orders for specific situations

✅ **Permitted Activities (General Legal Information):**
- Explaining laws in plain language
- Providing educational content about legal processes
- Offering document templates for review by an attorney
- Referring people to licensed attorneys
- Training people to understand legal concepts

### Technical Safeguards

#### 1. AI Response Filtering

**Intent Classification:**
Every user query is classified before generating a response.

```typescript
// Implemented in: apps/api/src/ai/classify-intent.ts
enum Intent {
  EDUCATIONAL,        // ✅ Safe to answer
  DOCUMENT_ANALYSIS,  // ✅ Safe with disclaimers
  SEEKING_ADVICE,     // ❌ Redirect to attorney
  HARMFUL,            // ❌ Block
}
```

**Response Templates by Intent:**

```typescript
// Educational (ALLOWED)
"In New York, tenants generally have the right to heat during winter months.
 Landlords are typically required to maintain temperatures of at least 68°F
 during the day when outdoor temps are below 55°F. However, your specific
 situation may have unique factors. Consult a licensed NY attorney for advice
 about your case."

// Seeking Advice (REDIRECT)
"It sounds like you're asking for specific advice about your case. I can only
 provide general legal information, not advice for your particular situation.
 I recommend consulting with a licensed New York attorney who can review your
 specific facts. Would you like me to connect you with our attorney marketplace?"

// Harmful (BLOCK)
"I can't help with that request. If you have a legal issue, please consult
 a licensed attorney in your jurisdiction."
```

#### 2. Mandatory Disclaimers

**Every AI-generated response must include:**
```
---
**Important**: This is general legal information, not legal advice for your
specific situation. Use of this platform does not create an attorney-client
relationship. Please consult a licensed New York attorney for advice about
your case.
```

**Code Implementation:**
```typescript
// apps/api/src/ai/ai.service.ts
function addDisclaimer(content: string, userRole: Role): string {
  const disclaimers = {
    CITIZEN_USER: `\n\n---\n**Important**: This is general legal information,
      not legal advice for your specific situation. Please consult a licensed
      New York attorney for advice about your case.`,

    LAW_STUDENT: `\n\n---\n**Note**: This is educational content. For actual
      legal matters, consult a licensed attorney.`,

    LICENSED_ATTORNEY: `\n\n---\n**Note**: Verify all information against
      current law and jurisdiction-specific rules.`,
  };

  return content + (disclaimers[userRole] || disclaimers.CITIZEN_USER);
}
```

#### 3. High-Risk Matter Flagging

Automatically flag matters that require attorney representation:

```typescript
// apps/api/src/matters/matters.service.ts
const HIGH_RISK_TYPES = [
  'CRIMINAL',
  'EVICTION',
  'CHILD_CUSTODY',
  'IMMIGRATION',
  'BANKRUPTCY',
];

function shouldFlagForAttorney(matter: Matter): boolean {
  if (HIGH_RISK_TYPES.includes(matter.type)) return true;

  // Additional heuristics
  if (matter.description.match(/criminal|arrest|felony|misdemeanor/i)) return true;
  if (matter.description.match(/evict|eviction|dispossess/i)) return true;

  return false;
}
```

When flagged, user sees:
```
⚠️ This matter appears to require professional legal representation.
We strongly recommend consulting with a licensed New York attorney.
[Find an Attorney] button
```

#### 4. Role-Based Feature Gating

```typescript
// What CITIZEN_USER can do:
- Access educational content
- Create matters for self only
- Use document analyzer (with disclaimers)
- Ask general legal questions

// What CITIZEN_USER CANNOT do:
- Create matters "for a friend"
- Generate court-ready documents
- Get case-specific legal advice
- Access attorney-only features

// Code enforcement:
@Post('matters')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.CITIZEN_USER, Role.PRELAW, Role.LAW_STUDENT)
async create(@Body() dto: CreateMatterDto, @CurrentUser() user: User) {
  // User can ONLY create for themselves
  if (dto.ownerId && dto.ownerId !== user.userId) {
    throw new ForbiddenException(
      'You can only create matters for yourself. To help someone else, ' +
      'they should create their own account or consult an attorney.'
    );
  }
  // ...
}
```

#### 5. Audit Logging

**Every AI interaction is logged:**

```typescript
await prisma.auditLog.create({
  data: {
    userId: user.id,
    eventType: 'AI_QUERY',
    metadata: {
      query: sanitizedQuery,
      response: truncatedResponse,
      intent: classifiedIntent,
      model: 'gpt-4-turbo-preview',
      disclaimed: true,
      redirectedToAttorney: intent === Intent.SEEKING_ADVICE,
    },
    timestamp: new Date(),
  },
});
```

**Purpose:**
- Demonstrate compliance in case of bar complaint
- Identify patterns of UPL risk
- Train AI models to avoid UPL

## Data Privacy Compliance

### GDPR & CCPA Requirements

#### 1. User Consent
```typescript
// On signup
model User {
  // ...
  consentGiven       Boolean   @default(false)
  consentGivenAt     DateTime?
  privacyPolicyVersion String?  @default("1.0")
}

// When user signs up, they must explicitly consent
<Checkbox name="consent" required>
  I agree to the <Link to="/privacy">Privacy Policy</Link> and
  <Link to="/terms">Terms of Service</Link>
</Checkbox>
```

#### 2. Right to Access (Data Export)
```typescript
// GET /users/me/export
async exportUserData(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  const matters = await prisma.matter.findMany({ where: { ownerId: userId } });
  const documents = await prisma.document.findMany({ where: { uploadedBy: userId } });
  const aiUsage = await prisma.aiUsageLog.findMany({ where: { userId } });

  return {
    user: {
      email: user.email,
      name: user.name,
      createdAt: user.createdAt,
    },
    matters: matters.map(m => ({ title: m.title, type: m.type, status: m.status })),
    documents: documents.map(d => ({ fileName: d.fileName, uploadedAt: d.uploadedAt })),
    aiUsage: {
      totalQueries: aiUsage.length,
      totalCost: aiUsage.reduce((sum, log) => sum + log.costCents, 0) / 100,
    },
    exportedAt: new Date(),
  };
}
```

#### 3. Right to Deletion (Right to be Forgotten)
```typescript
// DELETE /users/me
async deleteUser(userId: string) {
  // 1. Soft delete first (for audit trail)
  await prisma.user.update({
    where: { id: userId },
    data: {
      deletedAt: new Date(),
      email: `deleted_${userId}@example.com`, // Anonymize email
      name: 'Deleted User',
    },
  });

  // 2. After 30-day grace period, hard delete
  // (Run via cron job)
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  await prisma.user.deleteMany({
    where: {
      deletedAt: { lt: thirtyDaysAgo },
    },
  });

  // 3. Delete associated data
  await prisma.matter.deleteMany({ where: { ownerId: userId } });
  await prisma.document.deleteMany({ where: { uploadedBy: userId } });
  // Keep audit logs (legal requirement), but anonymize
  await prisma.auditLog.updateMany({
    where: { userId },
    data: { userId: 'deleted_user' },
  });
}
```

#### 4. Data Minimization
```typescript
// Only collect what's necessary
interface UserSignupDto {
  email: string;      // Required for auth
  password: string;   // Required for auth
  name?: string;      // Optional
  // NO: SSN, DOB, address (unless legally required)
}

// Never collect:
- Social Security Numbers (unless user is applying for attorney verification)
- Credit card numbers (use Stripe tokens only)
- Passwords in plaintext (bcrypt hash)
```

#### 5. Data Retention Policy
```sql
-- Implemented via cleanup jobs
DELETE FROM ai_chat_history WHERE created_at < NOW() - INTERVAL '1 year';
DELETE FROM audit_logs WHERE created_at < NOW() - INTERVAL '7 years'; -- Legal retention period
DELETE FROM sessions WHERE expires_at < NOW();
```

### Privacy Policy Requirements

**Must include:**
- What data we collect
- Why we collect it
- Who we share it with (OpenAI, Clerk, Stripe)
- How users can access/delete their data
- Contact info for privacy requests

**Template:**
```markdown
# Privacy Policy

Last updated: January 14, 2025

## Data We Collect
- Account info: email, name
- Legal matters: descriptions, documents you upload
- AI interactions: your questions and our responses
- Usage data: how you use the platform

## How We Use It
- Provide legal education services
- Improve AI responses
- Comply with legal obligations
- Send service-related emails

## Who We Share With
- OpenAI (for AI features) - see their privacy policy
- Clerk (for authentication)
- Stripe (for payments)
- We do NOT sell your data

## Your Rights
- Access your data (export)
- Delete your account
- Opt out of marketing emails

Contact: privacy@lexicore.com
```

## Attorney-Client Privilege Protection

### For Licensed Attorneys Using Platform

**Critical:**
- Communications between attorney and their clients on the platform ARE privileged
- Communications between user and AI are NOT privileged
- Communications between user and non-attorney are NOT privileged

**Technical Implementation:**

```typescript
model MatterParticipant {
  id          String            @id @default(uuid())
  matterId    String
  userId      String
  role        ParticipantRole   // OWNER | ATTORNEY | COLLABORATOR
  isPrivileged Boolean          @default(false) // Set true for attorney-client
  addedAt     DateTime          @default(now())
}

// When attorney is added to matter
async addAttorneyToMatter(matterId: string, attorneyId: string) {
  // Verify attorney is licensed
  const attorney = await prisma.userRole.findFirst({
    where: {
      userId: attorneyId,
      role: Role.LICENSED_ATTORNEY,
      verifiedAt: { not: null },
    },
  });

  if (!attorney) {
    throw new ForbiddenException('User is not a verified attorney');
  }

  // Create privileged relationship
  await prisma.matterParticipant.create({
    data: {
      matterId,
      userId: attorneyId,
      role: 'ATTORNEY',
      isPrivileged: true, // ← This marks communications as privileged
    },
  });

  // Show notice to user
  await createNotification(ownerId, {
    type: 'ATTORNEY_ADDED',
    message: `${attorney.name} has been added to your matter. Communications
              with your attorney are protected by attorney-client privilege.`,
  });
}
```

## AI Safety & Ethics

### 1. Hallucination Prevention

**Problem**: AI might invent fake laws or cases.

**Solution**:
```typescript
// Implement RAG (Retrieval-Augmented Generation)
async function generateResponse(query: string) {
  // 1. Retrieve actual legal content from vector DB
  const relevantDocs = await searchLegalDocuments(query);

  // 2. Build prompt with ONLY retrieved content
  const prompt = `
    Based ONLY on the following verified legal information, answer the question.
    If the answer is not in the provided information, say "I don't have
    verified information on that topic. Please consult an attorney."

    Verified information:
    ${relevantDocs.map(doc => doc.content).join('\n\n')}

    Question: ${query}
  `;

  // 3. Generate response
  const response = await openai.chat.completions.create({
    model: 'gpt-4-turbo-preview',
    messages: [{ role: 'user', content: prompt }],
  });

  // 4. Add citations
  return {
    answer: response.choices[0].message.content,
    sources: relevantDocs.map(d => d.metadata.source),
  };
}
```

### 2. Bias Mitigation

**Problem**: AI might reflect biases in training data.

**Solution**:
- Regularly audit AI outputs for bias (race, gender, socioeconomic status)
- Test edge cases (immigrant users, non-English speakers, low-income users)
- Allow users to flag inappropriate responses

```typescript
// Flag system
model AIResponseFlag {
  id          String   @id @default(uuid())
  userId      String
  responseId  String
  reason      String   // "bias" | "incorrect" | "inappropriate"
  description String
  flaggedAt   DateTime @default(now())
}

// POST /ai/flag-response
async flagResponse(userId: string, responseId: string, reason: string) {
  await prisma.aiResponseFlag.create({ data: { userId, responseId, reason } });

  // Alert compliance team if flagged as biased
  if (reason === 'bias') {
    await sendSlackAlert('#compliance', `AI response flagged for bias: ${responseId}`);
  }
}
```

### 3. Prompt Injection Defense

**Problem**: User tries to override system prompts.

**Solution**:
```typescript
function detectPromptInjection(input: string): boolean {
  const INJECTION_PATTERNS = [
    /ignore (previous|all|prior) (instructions|rules|prompts)/i,
    /you are now/i,
    /system\s*:/i,
    /forget (everything|all)/i,
    /act as (a|an) (lawyer|attorney)/i,
  ];

  // Check patterns
  if (INJECTION_PATTERNS.some(pattern => pattern.test(input))) {
    return true;
  }

  // Check for excessive special characters (encoding tricks)
  const specialCharRatio = (input.match(/[^\w\s]/g) || []).length / input.length;
  if (specialCharRatio > 0.3) {
    return true;
  }

  return false;
}

// In API handler
if (detectPromptInjection(userQuery)) {
  throw new BadRequestException('Invalid query detected');
}
```

## Terms of Service

### Key Clauses

**1. No Attorney-Client Relationship**
```
USE OF THIS PLATFORM DOES NOT CREATE AN ATTORNEY-CLIENT RELATIONSHIP BETWEEN
YOU AND LEXICORE OR ANY ATTORNEY USING THE PLATFORM, EXCEPT WHERE AN ATTORNEY
EXPLICITLY AGREES TO REPRESENT YOU.
```

**2. Educational Purpose Only**
```
LEXICORE PROVIDES GENERAL LEGAL INFORMATION AND EDUCATIONAL CONTENT ONLY.
IT DOES NOT PROVIDE LEGAL ADVICE FOR YOUR SPECIFIC SITUATION. YOU SHOULD
CONSULT A LICENSED ATTORNEY IN YOUR JURISDICTION FOR ADVICE ABOUT YOUR CASE.
```

**3. AI Limitations**
```
AI-GENERATED CONTENT MAY CONTAIN ERRORS OR OMISSIONS. YOU USE AI FEATURES
AT YOUR OWN RISK. ALWAYS VERIFY INFORMATION WITH A LICENSED ATTORNEY BEFORE
TAKING ACTION.
```

**4. User Responsibilities**
```
YOU AGREE NOT TO:
- Use the platform to commit unauthorized practice of law
- Misrepresent yourself as an attorney if you are not licensed
- Share your account with others
- Use the platform for illegal purposes
```

## Compliance Checklist

### Before Launch
- [ ] UPL safeguards implemented (intent classification, disclaimers)
- [ ] High-risk matters auto-flagged for attorney
- [ ] User cannot create matters for others
- [ ] All AI responses include disclaimers
- [ ] Audit logging for all AI interactions
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] GDPR/CCPA data export implemented
- [ ] Right to deletion implemented
- [ ] Attorney verification process in place
- [ ] Privileged communications marked correctly
- [ ] Prompt injection detection active
- [ ] Rate limiting on AI features
- [ ] Legal review of all user-facing content

### Monthly Compliance Review
- [ ] Review flagged AI responses
- [ ] Check for UPL complaints (user feedback, bar inquiries)
- [ ] Audit attorney verifications
- [ ] Review high-risk matter escalations
- [ ] Test data export/deletion flows
- [ ] Update legal content (law changes)
- [ ] Review AI hallucination rate
- [ ] Check bias flags

### Quarterly Legal Review
- [ ] Attorney review of new AI prompts
- [ ] Update privacy policy if needed
- [ ] Review terms of service
- [ ] External legal audit (recommended)
- [ ] Update disclaimers based on new case law

## Incident Response

### If User Complains of UPL
1. **Immediate**: Disable AI features for that user (preserve evidence)
2. **Within 24h**: Review audit logs for user's AI interactions
3. **Within 48h**: Consult with attorney
4. **Document**: All interactions, actions taken, resolution
5. **Improve**: Update prompts/filters to prevent recurrence

### If Bar Inquiry
1. **Do NOT panic** - you have audit logs
2. **Consult attorney** immediately
3. **Provide** audit logs showing disclaimers, intent classification, redirects
4. **Demonstrate** user was repeatedly told to consult attorney
5. **Show** technical safeguards (code, policies, training)

## Resources

- [NY Rules of Professional Conduct](https://nycourts.gov/rules/jointappellate/ny-rules-prof-conduct-1200.pdf)
- [ABA Model Rules](https://www.americanbar.org/groups/professional_responsibility/publications/model_rules_of_professional_conduct/)
- [NYSBA UPL Committee](https://nysba.org/committees/unauthorized-practice-of-law/)
- [GDPR Compliance Guide](https://gdpr.eu/)
- [CCPA Guide](https://oag.ca.gov/privacy/ccpa)

---

**Compliance Officer Contact**: compliance@lexicore.com
**Legal Counsel**: TBD (retain before launch)
**Ethics Hotline**: [Internal reporting system for team]

**Remember**: When in doubt, **over-disclaim** and **redirect to an attorney**.
It's better to be overly cautious than to commit UPL.
