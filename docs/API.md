# API Documentation

**Base URL:** `https://api.lexicore.com` (production) | `http://localhost:3001` (local)

**API Version:** v1
**Authentication:** JWT Bearer tokens
**Content-Type:** `application/json`

---

## Table of Contents

- [Authentication](#authentication)
- [Users & Roles](#users--roles)
- [Matters](#matters)
- [Documents](#documents)
- [AI Features](#ai-features)
- [Learning](#learning)
- [Admin](#admin)
- [Rate Limits](#rate-limits)
- [Error Handling](#error-handling)

---

## Authentication

### POST /auth/signup
Create a new user account.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "John Doe"
}
```

**Response:** `201 Created`
```json
{
  "data": {
    "user": {
      "id": "usr_abc123",
      "email": "user@example.com",
      "name": "John Doe",
      "primaryRole": "CITIZEN_USER",
      "createdAt": "2025-01-14T10:00:00Z"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  },
  "meta": {
    "timestamp": "2025-01-14T10:00:00Z",
    "requestId": "req_xyz789"
  }
}
```

**Errors:**
- `400` - Validation error (weak password, invalid email)
- `409` - Email already exists

---

### POST /auth/login
Authenticate existing user.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Response:** `200 OK`
```json
{
  "data": {
    "user": {
      "id": "usr_abc123",
      "email": "user@example.com",
      "name": "John Doe",
      "roles": ["CITIZEN_USER"]
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "ref_def456"
  }
}
```

**Errors:**
- `401` - Invalid credentials
- `404` - User not found

---

### POST /auth/refresh
Refresh access token.

**Request:**
```json
{
  "refreshToken": "ref_def456"
}
```

**Response:** `200 OK`
```json
{
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "ref_ghi789"
  }
}
```

---

### GET /auth/me
Get current user info.

**Headers:**
```
Authorization: Bearer <token>
```

**Response:** `200 OK`
```json
{
  "data": {
    "id": "usr_abc123",
    "email": "user@example.com",
    "name": "John Doe",
    "primaryRole": "CITIZEN_USER",
    "roles": ["CITIZEN_USER"],
    "jurisdiction": "NY",
    "createdAt": "2025-01-14T10:00:00Z"
  }
}
```

---

## Users & Roles

### GET /users/me
Get full user profile.

**Response:** `200 OK`
```json
{
  "data": {
    "id": "usr_abc123",
    "email": "user@example.com",
    "name": "John Doe",
    "primaryRole": "CITIZEN_USER",
    "jurisdiction": "NY",
    "settings": {
      "theme": "dark",
      "language": "en",
      "emailEnabled": true
    },
    "subscription": {
      "tier": "CITIZEN",
      "status": "ACTIVE",
      "currentPeriodEnd": "2025-02-14T00:00:00Z"
    }
  }
}
```

---

### PATCH /users/me
Update user profile.

**Request:**
```json
{
  "name": "John D. Doe",
  "jurisdiction": "NY"
}
```

**Response:** `200 OK`
```json
{
  "data": {
    "id": "usr_abc123",
    "email": "user@example.com",
    "name": "John D. Doe",
    "jurisdiction": "NY",
    "updatedAt": "2025-01-14T11:00:00Z"
  }
}
```

---

### GET /users/me/settings
Get user settings.

**Response:** `200 OK`
```json
{
  "data": {
    "theme": "dark",
    "language": "en",
    "timezone": "America/New_York",
    "emailEnabled": true,
    "pushEnabled": false,
    "legalRemindersEnabled": true
  }
}
```

---

### PATCH /users/me/settings
Update user settings.

**Request:**
```json
{
  "theme": "light",
  "emailEnabled": false
}
```

**Response:** `200 OK`

---

### GET /users/me/export
Export all user data (GDPR/CCPA compliance).

**Response:** `200 OK`
```json
{
  "data": {
    "user": { ...user info... },
    "matters": [ ...all matters... ],
    "documents": [ ...all documents... ],
    "aiUsage": {
      "totalQueries": 45,
      "totalCost": 2.35
    },
    "exportedAt": "2025-01-14T12:00:00Z"
  }
}
```

---

### DELETE /users/me
Delete user account (soft delete with 30-day grace period).

**Response:** `204 No Content`

---

## Matters

### GET /matters
List all matters for current user.

**Query Parameters:**
- `status` (optional): Filter by status (`DRAFT`, `ACTIVE`, `NEEDS_ATTORNEY`, etc.)
- `type` (optional): Filter by type (`LANDLORD_TENANT`, `CRIMINAL`, etc.)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 20, max: 100)

**Response:** `200 OK`
```json
{
  "data": [
    {
      "id": "mtr_123abc",
      "title": "Landlord Not Fixing Heat",
      "type": "LANDLORD_TENANT",
      "status": "ACTIVE",
      "riskLevel": "NORMAL",
      "jurisdiction": "NY",
      "createdAt": "2025-01-10T09:00:00Z",
      "updatedAt": "2025-01-14T10:30:00Z"
    }
  ],
  "meta": {
    "total": 5,
    "page": 1,
    "perPage": 20,
    "pages": 1
  }
}
```

---

### POST /matters
Create a new matter.

**Request:**
```json
{
  "title": "Landlord Not Fixing Heat",
  "type": "LANDLORD_TENANT",
  "jurisdiction": "NY",
  "description": "Heat has been out for 2 weeks, landlord not responding"
}
```

**Response:** `201 Created`
```json
{
  "data": {
    "id": "mtr_123abc",
    "ownerId": "usr_abc123",
    "title": "Landlord Not Fixing Heat",
    "type": "LANDLORD_TENANT",
    "status": "DRAFT",
    "riskLevel": "NORMAL",
    "jurisdiction": "NY",
    "description": "Heat has been out for 2 weeks...",
    "createdAt": "2025-01-14T10:00:00Z",
    "updatedAt": "2025-01-14T10:00:00Z"
  }
}
```

**Validation:**
- `title`: 5-200 characters
- `type`: Valid MatterType enum
- `jurisdiction`: 2 characters (e.g., "NY")
- `description`: Max 5000 characters

**High-Risk Auto-Flagging:**
If `type` is `CRIMINAL`, `EVICTION`, `CHILD_CUSTODY`, `IMMIGRATION`, or `BANKRUPTCY`, the matter is automatically set to `status: "NEEDS_ATTORNEY"` and `riskLevel: "HIGH"`.

**Errors:**
- `400` - Validation error
- `403` - Cannot create matter for another user
- `401` - Not authenticated

---

### GET /matters/:id
Get single matter details.

**Response:** `200 OK`
```json
{
  "data": {
    "id": "mtr_123abc",
    "ownerId": "usr_abc123",
    "title": "Landlord Not Fixing Heat",
    "type": "LANDLORD_TENANT",
    "status": "ACTIVE",
    "riskLevel": "NORMAL",
    "jurisdiction": "NY",
    "description": "Heat has been out for 2 weeks...",
    "owner": {
      "id": "usr_abc123",
      "name": "John Doe",
      "email": "user@example.com"
    },
    "participants": [],
    "documents": [
      {
        "id": "doc_456def",
        "fileName": "lease_agreement.pdf",
        "fileSize": 245678,
        "uploadedAt": "2025-01-12T14:00:00Z"
      }
    ],
    "timeline": [
      {
        "id": "evt_789ghi",
        "date": "2025-01-01T00:00:00Z",
        "title": "Heat stopped working",
        "description": "Noticed heat was not working"
      }
    ],
    "createdAt": "2025-01-10T09:00:00Z",
    "updatedAt": "2025-01-14T10:30:00Z"
  }
}
```

**Errors:**
- `404` - Matter not found
- `403` - Not authorized to view this matter

---

### PATCH /matters/:id
Update matter.

**Request:**
```json
{
  "title": "Landlord Refuses to Fix Heat",
  "status": "NEEDS_ATTORNEY"
}
```

**Response:** `200 OK`

**Errors:**
- `404` - Matter not found
- `403` - Not authorized

---

### DELETE /matters/:id
Delete matter (soft delete).

**Response:** `204 No Content`

---

## Documents

### POST /matters/:matterId/documents
Upload document to matter.

**Content-Type:** `multipart/form-data`

**Request:**
```
file: <binary>
documentType: "LEASE" | "CONTRACT" | "TICKET" | "NOTICE" | "LETTER" | "EVIDENCE" | "OTHER"
description: "My lease agreement"
```

**Response:** `201 Created`
```json
{
  "data": {
    "id": "doc_456def",
    "matterId": "mtr_123abc",
    "fileName": "lease_agreement.pdf",
    "fileSize": 245678,
    "mimeType": "application/pdf",
    "documentType": "LEASE",
    "description": "My lease agreement",
    "storageUrl": "https://storage.lexicore.com/...",
    "uploadedAt": "2025-01-14T11:00:00Z"
  }
}
```

**Validation:**
- Max file size: 10MB
- Allowed types: PDF, DOCX, TXT, JPG, PNG

---

### GET /matters/:matterId/documents
List documents for matter.

**Response:** `200 OK`

---

### DELETE /documents/:id
Delete document.

**Response:** `204 No Content`

---

## AI Features

### POST /ai/chat
Send message to AI legal coach.

**Request:**
```json
{
  "message": "What are my rights as a tenant in NY?",
  "matterId": "mtr_123abc",  // Optional
  "context": {}  // Optional additional context
}
```

**Response:** `200 OK`
```json
{
  "data": {
    "response": "In New York, tenants have several important rights...\n\n---\n**Important**: This is general legal information, not legal advice for your specific situation. Please consult a licensed New York attorney for advice about your case.",
    "intent": "EDUCATIONAL",
    "sources": [
      "NY Real Property Law § 235-b",
      "NYC Housing Maintenance Code"
    ],
    "usage": {
      "model": "gpt-4-turbo-preview",
      "promptTokens": 150,
      "completionTokens": 300,
      "costCents": 12
    }
  }
}
```

**Intent Classifications:**
- `EDUCATIONAL` - General legal information (allowed)
- `DOCUMENT_ANALYSIS` - Analyzing uploaded document (allowed with disclaimer)
- `SEEKING_ADVICE` - Specific case advice (redirected to attorney)
- `HARMFUL` - Illegal or unethical request (blocked)

**Rate Limits:**
- Free tier: 10 queries/hour
- Citizen tier: 100 queries/hour
- Bar Prep tier: Unlimited

**Errors:**
- `400` - Invalid query detected (prompt injection)
- `429` - Rate limit exceeded
- `402` - Budget limit exceeded

---

### POST /ai/analyze-document
Analyze uploaded document with AI.

**Request:**
```json
{
  "documentId": "doc_456def",
  "question": "What type of document is this?"  // Optional
}
```

**Response:** `200 OK`
```json
{
  "data": {
    "documentType": "LEASE",
    "keyFacts": {
      "parties": ["John Doe", "ABC Property Management"],
      "dates": ["2024-01-01 to 2025-01-01"],
      "amounts": ["$1,500/month rent"],
      "mainObligations": [
        "Tenant pays rent by 1st of month",
        "Landlord maintains heating system"
      ]
    },
    "potentialRedFlags": [
      "No clause about repairs timeline",
      "Security deposit is 2 months (NY law allows max 1 month for unfurnished)"
    ],
    "summary": "This appears to be a residential lease agreement...",
    "nextSteps": "Have a licensed attorney review this document before signing.",
    "disclaimer": "This analysis is for informational purposes only..."
  }
}
```

---

## Learning

### GET /learn/tracks
List available learning tracks.

**Query Parameters:**
- `type`: Filter by type (`LEGAL_LITERACY`, `PRELAW`, `BAR_PREP`)
- `jurisdiction`: Filter by jurisdiction (default: `NY`)

**Response:** `200 OK`
```json
{
  "data": [
    {
      "id": "trk_abc123",
      "title": "Know Your Rights: NY Tenant Law",
      "description": "Learn about tenant rights in New York...",
      "type": "LEGAL_LITERACY",
      "jurisdiction": "NY",
      "lessonCount": 8,
      "estimatedHours": 4,
      "published": true
    }
  ]
}
```

---

### GET /learn/tracks/:id
Get track details with lessons.

**Response:** `200 OK`
```json
{
  "data": {
    "id": "trk_abc123",
    "title": "Know Your Rights: NY Tenant Law",
    "description": "...",
    "type": "LEGAL_LITERACY",
    "lessons": [
      {
        "id": "lsn_def456",
        "title": "Introduction to Tenant Rights",
        "order": 1,
        "estimatedMinutes": 15,
        "completed": false
      }
    ],
    "progress": {
      "completedLessons": 0,
      "totalLessons": 8,
      "percentComplete": 0
    }
  }
}
```

---

### POST /learn/sessions
Start learning session.

**Request:**
```json
{
  "trackId": "trk_abc123",
  "lessonId": "lsn_def456"
}
```

**Response:** `201 Created`
```json
{
  "data": {
    "sessionId": "ses_ghi789",
    "lesson": {
      "id": "lsn_def456",
      "title": "Introduction to Tenant Rights",
      "content": "# Welcome\n\nThis lesson covers...",
      "estimatedMinutes": 15
    }
  }
}
```

---

### PATCH /learn/sessions/:id
Update session progress.

**Request:**
```json
{
  "completed": true,
  "score": 85,
  "timeSpentSeconds": 900
}
```

**Response:** `200 OK`

---

## Admin

*All admin endpoints require `SYSTEM_ADMIN` role.*

### GET /admin/users
List all users.

**Query Parameters:**
- `role`: Filter by role
- `search`: Search by name or email
- `page`, `limit`: Pagination

**Response:** `200 OK`

---

### PATCH /admin/users/:id
Update user (admin only).

**Request:**
```json
{
  "primaryRole": "LICENSED_ATTORNEY",
  "verified": true
}
```

**Response:** `200 OK`

---

### GET /admin/analytics
Get platform analytics.

**Response:** `200 OK`
```json
{
  "data": {
    "users": {
      "total": 1250,
      "active": 450,
      "newThisMonth": 75
    },
    "matters": {
      "total": 3500,
      "openTotal": 890,
      "needsAttorney": 45
    },
    "ai": {
      "queriesThisMonth": 12500,
      "averageCostPerUser": 0.35,
      "totalCostThisMonth": 437.50
    }
  }
}
```

---

## Rate Limits

| Tier | AI Queries | API Requests | Uploads |
|------|-----------|--------------|---------|
| Free | 10/hour | 100/hour | 5/day |
| Citizen | 100/hour | 500/hour | 50/day |
| Bar Prep | Unlimited | 1000/hour | 100/day |
| Attorney | Unlimited | 2000/hour | 200/day |

**Rate Limit Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1642176000
```

**429 Response:**
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Limit: 100/hour",
    "statusCode": 429,
    "retryAfter": 3600
  }
}
```

---

## Error Handling

### Standard Error Response
```json
{
  "error": {
    "code": "MATTER_NOT_FOUND",
    "message": "Matter with ID xyz not found",
    "statusCode": 404,
    "details": {}  // Optional additional context
  },
  "meta": {
    "timestamp": "2025-01-14T10:00:00Z",
    "requestId": "req_abc123"
  }
}
```

### Error Codes

| Code | Status | Description |
|------|--------|-------------|
| `VALIDATION_ERROR` | 400 | Request validation failed |
| `UNAUTHORIZED` | 401 | Not authenticated |
| `FORBIDDEN` | 403 | Not authorized for this resource |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Resource conflict (e.g., email exists) |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |
| `INTERNAL_SERVER_ERROR` | 500 | Server error |
| `AI_BUDGET_EXCEEDED` | 402 | Monthly AI budget exceeded |
| `INVALID_QUERY` | 400 | Prompt injection detected |

---

## Webhooks

*Coming in Phase 2*

Subscribe to events:
- `matter.created`
- `matter.updated`
- `matter.flagged_high_risk`
- `attorney.assigned`
- `subscription.updated`

---

## Pagination

List endpoints support pagination:

**Request:**
```
GET /matters?page=2&limit=20
```

**Response:**
```json
{
  "data": [ ...items... ],
  "meta": {
    "total": 45,
    "page": 2,
    "perPage": 20,
    "pages": 3,
    "hasNext": true,
    "hasPrev": true
  }
}
```

---

## Filtering & Sorting

**Filter examples:**
```
GET /matters?status=ACTIVE&type=LANDLORD_TENANT
GET /matters?createdAfter=2025-01-01&createdBefore=2025-01-31
```

**Sort examples:**
```
GET /matters?sortBy=createdAt&order=desc
GET /matters?sortBy=title&order=asc
```

---

## Versioning

API version is specified in the URL:
```
https://api.lexicore.com/v1/matters
```

**Current version:** v1
**Deprecation policy:** 6 months notice before removing endpoints

---

## Authentication Flow

```
1. POST /auth/signup or /auth/login
   → Returns access token (expires in 7 days) + refresh token

2. Include token in all requests:
   Authorization: Bearer <access_token>

3. When token expires (401 response):
   POST /auth/refresh with refresh token
   → Returns new access token

4. Refresh token expires after 30 days of inactivity
   → User must log in again
```

---

## CORS

Allowed origins:
- `https://lexicore.com`
- `https://www.lexicore.com`
- `https://staging.lexicore.com`
- `http://localhost:3000` (development only)

---

## SDK & Libraries

**Official TypeScript SDK:** (Coming soon)
```typescript
import { LexicoreClient } from '@lexicore/sdk';

const client = new LexicoreClient({ token: 'your_token' });

const matters = await client.matters.list();
const response = await client.ai.chat({
  message: 'What are my rights as a tenant?'
});
```

---

## Testing

**Test API Keys:**
- Use `sk_test_...` prefix for test API keys
- Test mode uses separate database
- No charges for AI usage in test mode

**Sandbox Environment:**
```
https://api-sandbox.lexicore.com/v1
```

---

## Support

- **API Status:** https://status.lexicore.com
- **Changelog:** https://docs.lexicore.com/changelog
- **Support:** api-support@lexicore.com
- **Rate Limit Increase:** Contact support with use case

---

**Last Updated:** 2025-01-14
**API Version:** 1.0.0
