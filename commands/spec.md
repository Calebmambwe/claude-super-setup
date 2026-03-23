---
name: spec
description: Create a production-quality technical specification for a feature — from problem statement through acceptance criteria, ready for /build or /design-doc
---
Create a technical specification for: $ARGUMENTS

You are the **Architect Agent** (Opus, plan mode), executing the **Feature Spec** workflow.

## What This Does

Produces a complete, implementation-ready technical specification in `docs/specs/{feature-name}.md` — covering user stories, architecture diagrams, API contracts, database schema, frontend component tree, state management, error handling, test strategy, acceptance criteria, security, and performance considerations.

**When to use /spec:**
- New feature touching 3–15 files (more than a Quick Plan, less than a Full Pipeline)
- Unclear scope that needs a written contract before code starts
- Cross-cutting change (new API + DB schema + frontend components)
- Spec required for team review before implementation

**Not for:**
- Tiny changes (1–2 files) → code directly, then `/check`
- New product or major architecture → use `/plan → Full Pipeline` (BMAD)

---

## Step 0: Resource Audit (Non-Negotiable)

Complete ALL applicable checks before writing anything. Do NOT skip.

**1. Read project conventions:**
- Check for `CLAUDE.md` in the project root → read it for stack, naming, and patterns
- Check for `AGENTS.md` in the project root → read it for hard-won project-specific lessons
- If neither exists, note that and proceed with codebase inference

**2. Read existing planning docs (if present):**
- `docs/*/brief.md` → extract problem, goals, constraints
- `docs/*/prd.md` → extract functional requirements and epics
- `docs/*/architecture.md` → extract stack, components, data model

**3. Scan the codebase for existing patterns:**
- Read `package.json` / `pyproject.toml` for stack and dependencies
- Identify folder structure: `ls src/ app/ lib/ 2>/dev/null`
- Search for similar features or components already implemented:
  - `Grep pattern="similar-concept|RelatedComponent" glob="**/*.{ts,tsx,py}"`
- If a similar pattern exists: EXTEND or REUSE it — never create a parallel implementation
- Note the response envelope format used across the codebase (e.g. `{ success, data, error, meta }`)

**4. Check design system (if UI work is involved):**
- Read `~/.claude/skills/design-system/SKILL.md` before designing any component tree
- Identify design tokens in use (colors, spacing, radius)

**Gate:** Do NOT proceed to Step 1 until the audit is complete.

---

## Step 1: Research Gate

Check if library or API research is needed. Research IS needed if ANY of:
- Feature references a library not yet verified via Context7 this session
- Feature involves choosing between 2+ technical options
- Feature touches an external API (Stripe, Resend, Twilio, etc.)
- Feature is a version upgrade or migration
- User says "research", "compare", "evaluate", or "what should we use"

**If YES:** Invoke the researcher agent with Context7.
- Resolve the library via `mcp__context7__resolve-library-id`
- Fetch current, version-specific docs via `mcp__context7__query-docs`
- Produce a **Research Brief** with: library version, key APIs used, gotchas, alternatives considered
- Attach the brief to the spec under `## Appendix: Research Brief`

**If NO:** Proceed directly to Step 2.

Research adds ~5 minutes. It prevents 30+ minutes of wrong-API debugging.

---

## Step 2: Clarify (Ask Before Writing)

Before drafting the spec, confirm the following with the user if not already clear from $ARGUMENTS:

```
Clarification questions (ask ALL in one message):

1. What is the primary user problem this solves? (one sentence)
2. Who are the users? (role / persona)
3. Is there an existing feature this extends, or is this net-new?
4. Does this change the API surface? (new endpoints / modified contracts)
5. Does this change the database? (new tables / columns / migrations)
6. Is there a frontend component involved?
7. Any hard constraints? (deadline, must use X library, must not break Y)
8. What does "done" look like to you in one concrete sentence?
```

If the user provided enough context in $ARGUMENTS, skip questions that are already answered. Do NOT ask more than 8 questions.

---

## Step 3: Write the Spec

Use TodoWrite to track progress:
Resource Audit → Research Gate → Clarify → Problem Statement → Solution Overview → Architecture Diagram → API Contract → DB Schema → Frontend Component Tree → State Management → Error Handling Matrix → Test Strategy → Acceptance Criteria → Security → Performance → Out of Scope → Save → Update Registry

**Approach:** Precise, contract-driven, diagram-first. Every section below is required unless explicitly marked optional.

---

### Section 1: Header & Metadata

```markdown
# Spec: {Feature Name}

| Field | Value |
|-------|-------|
| Status | Draft |
| Author | {from git config} |
| Created | {today's date} |
| Feature branch | `feat/{feature-name}` |
| Related docs | {links to PRD / brief / architecture if they exist} |
| Spec path | `docs/specs/{feature-name}.md` |
```

---

### Section 2: Problem Statement

```markdown
## 2. Problem Statement

### 2.1 Context
{1–2 paragraphs: what is the current situation, and why is it a problem?}

### 2.2 User Stories
| As a... | I want to... | So that... |
|---------|-------------|------------|
| {role} | {action} | {outcome} |
| {role} | {action} | {outcome} |

### 2.3 Goals
- {Measurable goal 1}
- {Measurable goal 2}

### 2.4 Non-Goals (Out of Scope)
- {Excluded item 1 — and WHY it's excluded}
- {Excluded item 2}
```

---

### Section 3: Proposed Solution

```markdown
## 3. Proposed Solution

### 3.1 Summary
{2–4 sentences: the approach, the key technical decisions, why this design was chosen over alternatives.}

### 3.2 Key Design Decisions
| Decision | Choice | Rationale | Alternatives Rejected |
|----------|--------|-----------|----------------------|
| {e.g. Auth strategy} | {e.g. JWT} | {why} | {e.g. sessions — stateful} |
```

---

### Section 4: Architecture Diagram (REQUIRED)

Every spec MUST include at least one Mermaid diagram. Generate ALL that apply.

**4a. System / Component Overview** (always required)
```mermaid
graph TB
    Client[Browser / Mobile] --> Gateway[API Gateway]
    Gateway --> Service[Feature Service]
    Service --> DB[(PostgreSQL)]
    Service --> Cache[(Redis)]
    Service --> Queue[Job Queue]
```

**4b. Request / Data Flow** (required if new API endpoints)
```mermaid
sequenceDiagram
    participant C as Client
    participant A as API Gateway
    participant S as Service
    participant D as Database
    C->>A: POST /api/v1/{resource}
    A->>A: Validate JWT + Input
    A->>S: createResource(dto)
    S->>D: INSERT INTO resources
    D-->>S: record
    S-->>A: ResourceDTO
    A-->>C: 201 { success, data }
```

**4c. Entity Relationship Diagram** (required if DB schema changes)
```mermaid
erDiagram
    USER ||--o{ RESOURCE : owns
    RESOURCE ||--o{ TAG : has
```

**4d. State Diagram** (required if stateful workflow involved)
```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Submitted: submit()
    Submitted --> Approved: approve()
    Submitted --> Draft: reject()
    Approved --> [*]
```

**Rules for diagrams:**
- Use Mermaid syntax (renders in GitHub, VS Code with `bierner.markdown-mermaid`)
- Label every node and edge clearly
- Write one sentence below each diagram explaining what it shows
- Split complex systems into multiple focused diagrams

---

### Section 5: API Contract (OpenAPI 3.1)

**Required if:** feature adds or modifies any API endpoints.

For each new or modified endpoint, document the full contract:

```markdown
## 5. API Contract

### 5.1 `POST /api/v1/{resource}`

**Purpose:** {What this endpoint does}
**Auth:** Bearer JWT required — role: `{role}`

**Request Body** (`application/json`):
```json
{
  "field1": "string",
  "field2": 42
}
```

**OpenAPI 3.1 Schema:**
```yaml
requestBody:
  required: true
  content:
    application/json:
      schema:
        type: object
        required: [field1, field2]
        properties:
          field1:
            type: string
            minLength: 1
            maxLength: 255
            description: "..."
          field2:
            type: integer
            minimum: 0
            description: "..."
```

**Response `201 Created`:**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "field1": "value",
    "createdAt": "2026-01-01T00:00:00Z"
  }
}
```

**Error Responses:**
| Status | Code | Condition |
|--------|------|-----------|
| 400 | VALIDATION_ERROR | Missing required field or invalid format |
| 401 | UNAUTHORIZED | Missing or expired JWT |
| 403 | FORBIDDEN | Authenticated but lacks required role |
| 409 | CONFLICT | Duplicate resource |
| 422 | UNPROCESSABLE | Business rule violation |
| 500 | INTERNAL_ERROR | Unexpected server error |
```

Document ALL new or modified endpoints. Use the project's existing response envelope format — pull it from CLAUDE.md or codebase scan.

---

### Section 6: Database Schema Changes

**Required if:** feature adds tables, columns, indexes, or constraints.

```markdown
## 6. Database Schema

### 6.1 New Table: `{table_name}`

**Purpose:** {Why this table exists}

| Column | Type | Constraints | Default | Description |
|--------|------|-------------|---------|-------------|
| id | UUID | PK | gen_random_uuid() | Primary key |
| user_id | UUID | FK → users.id, NOT NULL | — | Owning user |
| name | VARCHAR(255) | NOT NULL | — | Display name |
| status | ENUM('draft','active','archived') | NOT NULL | 'draft' | Lifecycle state |
| metadata | JSONB | NULLABLE | NULL | Flexible attributes |
| created_at | TIMESTAMPTZ | NOT NULL | NOW() | Creation time |
| updated_at | TIMESTAMPTZ | NOT NULL | NOW() | Last modification |
| deleted_at | TIMESTAMPTZ | NULLABLE | NULL | Soft-delete marker |

**Indexes:**
- `idx_{table}_user_id` — on `user_id` (ownership lookups)
- `idx_{table}_status` — on `status` (filtered queries)
- `idx_{table}_created_at` — on `created_at DESC` (pagination)

**Validation Rules:**
- `name`: 1–255 chars, trimmed
- `status`: must be one of enum values

### 6.2 Migration Strategy

- Migration file: `{timestamp}_add_{table_name}.{sql|ts}`
- Approach: {additive-only / backward-compatible / requires downtime}
- Rollback plan: {DROP TABLE / ALTER TABLE revert steps}
- Data backfill required: {yes — describe / no}
- Estimated migration time: {<1s for new table / N minutes for backfill}

**Rule:** All schema changes MUST be additive or backward-compatible unless explicitly agreed otherwise.
```

---

### Section 7: Frontend Component Tree

**Required if:** feature adds or modifies UI components.

```markdown
## 7. Frontend Component Tree

### 7.1 Component Hierarchy

```
{FeatureRoot}                         # page/route entry point
├── {FeatureHeader}                   # title, breadcrumbs, actions
│   └── {ActionButton}               # primary CTA
├── {FeatureList}                     # list/table of items
│   ├── {FeatureListItem}            # single row/card
│   │   ├── {StatusBadge}           # reuse existing from design system
│   │   └── {ItemActions}           # edit/delete dropdown
│   └── {EmptyState}                # zero-state illustration + CTA
├── {FeatureForm}                     # create/edit form (modal or page)
│   ├── {FieldGroup}                 # form section wrapper
│   └── {FormActions}               # submit / cancel
└── {ConfirmDialog}                   # destructive action confirmation
```

### 7.2 Component Props

**{FeatureListItem}**
```typescript
interface FeatureListItemProps {
  item: FeatureItem;                  // data shape
  onEdit: (id: string) => void;       // edit callback
  onDelete: (id: string) => void;     // delete callback (triggers ConfirmDialog)
  isLoading?: boolean;                // skeleton state
}
```

**{FeatureForm}**
```typescript
interface FeatureFormProps {
  mode: 'create' | 'edit';
  initialValues?: Partial<FeatureItem>;
  onSubmit: (values: CreateFeatureDTO) => Promise<void>;
  onCancel: () => void;
}
```

### 7.3 Reused Components
List every existing component being reused (do NOT recreate):
- `StatusBadge` — from `components/ui/status-badge.tsx`
- `ConfirmDialog` — from `components/ui/confirm-dialog.tsx`
- `EmptyState` — from `components/ui/empty-state.tsx`

### 7.4 New Components Required
Only components that don't exist yet:
- `{FeatureList}` — new, owns list data fetching
- `{FeatureForm}` — new, owns form state and submission
```

---

### Section 8: State Management

```markdown
## 8. State Management

### 8.1 Approach
{Server state only (React Query / SWR) / Client state (Zustand / Redux) / Mixed — and why}

### 8.2 Server State (data fetching)

| Query Key | Endpoint | Stale Time | Cache Time | Notes |
|-----------|----------|------------|------------|-------|
| `['features']` | `GET /api/v1/features` | 30s | 5min | invalidated on create/update/delete |
| `['features', id]` | `GET /api/v1/features/:id` | 60s | 10min | prefetch on list hover |

**Mutations:**
- `createFeature` → optimistic insert into `['features']` cache → rollback on error
- `updateFeature` → optimistic update in `['features', id]` cache
- `deleteFeature` → optimistic remove from `['features']` cache

### 8.3 Client State (UI-only)
{Describe local state that never hits the server: modal open/close, form draft, selected rows}

Example (Zustand slice):
```typescript
interface FeatureUIState {
  selectedId: string | null;
  isFormOpen: boolean;
  setSelectedId: (id: string | null) => void;
  openForm: () => void;
  closeForm: () => void;
}
```
```

---

### Section 9: Error Handling Matrix

```markdown
## 9. Error Handling Matrix

| Layer | Error Type | Detection | User-Facing Message | Recovery |
|-------|-----------|-----------|---------------------|----------|
| Frontend | Network timeout | fetch throws | "Connection lost. Try again." | Retry button |
| Frontend | 400 Validation | API response | Field-level inline errors | Fix and resubmit |
| Frontend | 401 Unauthorized | API response | "Session expired. Please log in." | Redirect to /login |
| Frontend | 403 Forbidden | API response | "You don't have permission for this." | Show contact support |
| Frontend | 409 Conflict | API response | "{Resource} already exists." | Show existing item |
| Frontend | 500 Server Error | API response | "Something went wrong. We've been notified." | Retry / contact support |
| API | Input validation | Zod/Pydantic parse | 400 + field errors array | Client fixes input |
| API | DB constraint | pg error 23505 | 409 + descriptive message | Client deduplicates |
| API | Unexpected | catch-all handler | 500 + error ID for tracing | Sentry capture |
| Background Job | Failure | Queue dead-letter | Admin alert | Manual retry or compensate |

**Rules:**
- NEVER expose stack traces or internal error messages to clients
- ALWAYS return a correlation ID on 5xx errors for support tracing
- ALWAYS use the project's standard error envelope: `{ success: false, error: { code, message, details? } }`
```

---

### Section 10: Test Strategy

```markdown
## 10. Test Strategy

### 10.1 Coverage Targets
| Layer | Target | Tool |
|-------|--------|------|
| Unit (service/business logic) | ≥ 90% | Vitest / Jest / pytest |
| Integration (API endpoints) | ≥ 80% | Supertest / httpx |
| Component (UI) | ≥ 70% | React Testing Library |
| E2E (critical paths) | 3–5 flows | Playwright |

### 10.2 Unit Tests

**What to test:**
- Service layer: every public method, including error branches
- Validation schemas: valid input, each invalid case, edge cases
- Utility functions: all branches

**Example cases:**
```typescript
describe('FeatureService.create', () => {
  it('creates feature with valid input')
  it('throws ConflictError when name is duplicate')
  it('throws ValidationError when name is empty')
  it('sets status to draft by default')
})
```

### 10.3 Integration Tests

**What to test:**
- Happy path for each new endpoint (201/200)
- Auth failure (401) and forbidden (403) cases
- Validation failure (400) with specific field errors
- Conflict cases (409)

**Test data strategy:** use factories/fixtures, never hardcoded UUIDs

### 10.4 Component Tests

**What to test:**
- Renders correctly with valid props
- Shows loading/skeleton state
- Shows empty state when list is empty
- Calls `onEdit` and `onDelete` callbacks
- Form validation errors display correctly

### 10.5 E2E Tests (Playwright)

Critical user flows to automate:
1. {User can create a feature from start to success message}
2. {User sees validation error and can correct and resubmit}
3. {User can edit an existing feature}
4. {User deletes a feature after confirmation dialog}
5. {Unauthenticated user is redirected to login}
```

---

### Section 11: Acceptance Criteria

```markdown
## 11. Acceptance Criteria

Criteria are concrete and testable. Each maps to at least one test case.

### Must Have (blocks release)
- [ ] AC-01: {Given} a logged-in user with role `{role}`, {when} they submit a valid create form, {then} the resource appears in the list within 1 second, without a page reload
- [ ] AC-02: {Given} a duplicate name, {when} the form is submitted, {then} a 409 error is shown inline on the name field
- [ ] AC-03: {Given} an unauthenticated request to `POST /api/v1/{resource}`, {then} the API returns 401 with no resource created
- [ ] AC-04: All new API endpoints return responses within 200ms at p99 under normal load
- [ ] AC-05: All new code passes `pnpm lint && pnpm typecheck && pnpm test` with no failures

### Should Have (target for this release)
- [ ] AC-06: {Optimistic update — list updates immediately on create, rolls back on failure}
- [ ] AC-07: {Empty state shows correct illustration and CTA when no items exist}

### Nice to Have (defer if pressed for time)
- [ ] AC-08: {Keyboard shortcut to open create form}
```

---

### Section 12: Security Considerations

```markdown
## 12. Security Considerations

| Concern | Risk | Mitigation |
|---------|------|------------|
| Input injection | High | Validate all inputs with Zod/Pydantic at API boundary |
| Unauthorized access | High | JWT auth middleware on all endpoints; role check per endpoint |
| IDOR (insecure direct object reference) | Medium | Scope all DB queries to `WHERE user_id = currentUser.id` |
| Sensitive data in logs | Medium | Never log request body; scrub PII from error reports |
| CORS | Low | Allow only known origins in `CORS_ORIGINS` env var |
| Rate limiting | Medium | Apply rate limiter to mutation endpoints (POST/PUT/DELETE) |

**Checklist:**
- [ ] No user-supplied data rendered as raw HTML (XSS)
- [ ] No sensitive fields (password, token) returned in API responses
- [ ] Migration does not grant excessive DB privileges
- [ ] New env vars documented in `.env.example` with non-sensitive placeholders
```

---

### Section 13: Performance Considerations

```markdown
## 13. Performance Considerations

| Concern | Target | Approach |
|---------|--------|----------|
| List query response time | < 100ms p99 | Index on `user_id` + `created_at`; pagination (cursor or offset) |
| Write response time | < 200ms p99 | No synchronous external calls in the happy path |
| Frontend bundle size | < 20KB added | Code-split new route; lazy-load heavy components |
| N+1 queries | Zero | Use JOIN or `include` on ORM queries; never query inside a loop |
| Cache strategy | — | Cache list queries client-side (React Query stale-while-revalidate) |

**Load assumptions:**
- Concurrent users: {X}
- Records per user: {Y}
- Expected QPS on new endpoints: {Z}

If load assumptions are unknown, note that and flag for load testing before production.
```

---

### Section 14: Out of Scope

```markdown
## 14. Out of Scope

The following are explicitly excluded from this spec. They may be addressed in future specs.

| Item | Reason Excluded |
|------|----------------|
| {Feature X} | Out of MVP scope; will be tracked as a separate issue |
| {Feature Y} | Requires architecture decision not made yet |
| {Feature Z} | Dependency on {other team/service} not ready |
```

---

## Step 4: Save the Spec

1. **Determine feature name** from $ARGUMENTS (kebab-case)
2. **Ensure directory exists:** `docs/specs/`
3. **Write file:** `docs/specs/{feature-name}.md`
4. **Display confirmation:**

```
Spec saved: docs/specs/{feature-name}.md

Sections written:
  - Problem Statement + User Stories
  - Proposed Solution + Architecture Diagrams ({N} Mermaid diagrams)
  - API Contract ({N} endpoints in OpenAPI 3.1)
  - Database Schema ({N} tables / {N} migrations)
  - Frontend Component Tree ({N} components)
  - State Management
  - Error Handling Matrix
  - Test Strategy (unit / integration / component / E2E)
  - Acceptance Criteria ({N} must-have, {N} should-have)
  - Security Considerations
  - Performance Considerations
  - Out of Scope
```

---

## Step 5: Update FEATURES.md Registry

Check if `docs/FEATURES.md` exists. If yes, add a row for this feature:

```markdown
| [{Feature Name}](specs/{feature-name}.md) | Spec | — | [spec]({feature-name}.md) | {one-line description} |
```

If the feature already has a row (e.g. from a brief), update the Spec column to link to the new file.

If `docs/FEATURES.md` does not exist, create it with the standard header:

```markdown
# Feature Registry

| Feature | Status | Brief | Spec | Design Doc | Notes |
|---------|--------|-------|------|------------|-------|
| [{Feature Name}](specs/{feature-name}.md) | Spec | — | [spec](specs/{feature-name}.md) | — | {one-line description} |
```

---

## Step 6: Review Gate

```
Spec complete! Please review docs/specs/{feature-name}.md.

Key decisions to verify:
  1. API contract — do the request/response shapes match your expectations?
  2. DB schema — are the column types and indexes correct?
  3. Acceptance criteria — do these match your definition of "done"?
  4. Out of scope — is anything incorrectly excluded?

Reply with any corrections, or approve to proceed.
```

**Wait for user review and approval before suggesting implementation.**

---

## Step 7: Recommend Next Steps

After the user approves:

```
Spec approved.

Scope assessment:
```

**If the feature involves significant UI (3+ new components) AND a backend:**
```
Recommended path: /design-doc
  The spec covers WHAT to build. /design-doc produces the
  implementation-ready HOW — component hierarchy, data structures,
  development milestones, and setup guide.

  Run: /design-doc {feature-name}
```

**If the feature is backend-only or straightforward (≤ 3 files of new UI):**
```
Recommended path: /build
  Scope is contained. The spec is sufficient to begin implementation.

  Run: /build docs/specs/{feature-name}.md
  Or for autonomous execution: /auto-dev {feature-name}
```

**Always append:**
```
Branch to create: feat/{feature-name}
Conventional commit prefix: feat:
Tests to write alongside implementation: see Section 10
Verification gate: pnpm test && pnpm lint && pnpm typecheck
```

---

## Validation Checklist

Before declaring the spec complete, verify ALL of the following:

```
- [ ] Resource Audit completed (CLAUDE.md, AGENTS.md, codebase scan)
- [ ] Research Gate evaluated (Context7 used if libraries involved)
- [ ] Clarification questions answered before writing
- [ ] At least 1 Mermaid diagram included (system/component overview is mandatory)
- [ ] User stories written in "As a / I want / So that" format
- [ ] API contract includes OpenAPI 3.1 schema, request + response JSON, and all error codes
- [ ] DB schema has column types, constraints, defaults, and indexes
- [ ] Migration strategy documented (approach + rollback plan)
- [ ] Frontend component tree uses props interfaces with TypeScript types
- [ ] Reused components identified (no duplicates created)
- [ ] Error handling matrix covers all layers (frontend → API → DB → jobs)
- [ ] Test strategy includes coverage targets and example test cases
- [ ] Acceptance criteria are concrete and testable (Given/When/Then)
- [ ] Security concerns addressed per the checklist
- [ ] Performance targets defined with approaches
- [ ] Out of scope is explicit and reasoned
- [ ] Spec saved to docs/specs/{feature-name}.md
- [ ] FEATURES.md registry updated
- [ ] Review gate passed before next step recommendation
```

---

## Rules

- ALWAYS complete the Resource Audit before writing a single line of the spec
- ALWAYS run the Research Gate — use Context7 for any library question
- ALWAYS ask clarification questions in ONE message before starting, not mid-spec
- ALWAYS include at least one Mermaid diagram — system overview is non-negotiable
- ALWAYS use OpenAPI 3.1 format for API contracts, not informal prose
- ALWAYS write acceptance criteria as Given/When/Then — never vague ("works correctly")
- ALWAYS use the project's existing response envelope format for API examples
- ALWAYS scope DB queries to the authenticated user (prevent IDOR)
- NEVER expose stack traces or internal error details in API error examples
- NEVER create duplicate components — search the project first, reuse what exists
- NEVER hardcode colors, spacing, or fonts — reference design system tokens
- NEVER use `any` in TypeScript interfaces — use `unknown` + type guard
- NEVER declare the spec complete without running the validation checklist
- NEVER proceed to implementation without user review and approval of the spec
- If the researcher flags Confidence: Low on any finding, pause and ask the user before writing that section
