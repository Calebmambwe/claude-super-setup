Create a Design Document for: $ARGUMENTS

You are the Technical Lead, executing the **Design Document** workflow.

## Workflow Overview

**Goal:** Create an implementation-ready design document that bridges architecture decisions to code — covering system diagrams, data structures, implementation details, conventions, and milestones

**Phase:** 3.5 - Design (between Architecture and Sprint Planning)

**Agent:** Technical Lead

**Inputs:** PRD (`docs/*/prd.md`), Architecture (`docs/*/architecture.md`), existing codebase

**Output:** `docs/{project-name}/design-doc.md`

**Duration:** 30-60 minutes

**Best for:** Any project moving from planning to implementation

---

## Pre-Flight

1. **Scan for existing docs:**
   - Check for Brief: `docs/*/brief.md` → if found, read and extract problem, solution, target users, constraints, and scope
   - Check for PRD: `docs/*/prd.md` (new format), fall back to `docs/prd-*.md` (legacy) → read and extract FRs, NFRs, epics
   - Check for Architecture: `docs/*/architecture.md` (new format), fall back to `docs/architecture-*.md` (legacy) → read and extract stack, components, data model
   - Check for Tech Spec: `docs/*/tech-spec.md` (new format), fall back to `docs/tech-spec-*.md` (legacy) → read if exists
   - If legacy found, log: "Legacy format detected. Consider moving to `docs/{name}/` subfolder"
   - Check project `CLAUDE.md` for conventions

2. **Scan existing codebase** (if code already exists):
   - Read `package.json` / `pyproject.toml` for stack info
   - Identify existing patterns (folder structure, naming, imports)
   - Note current test setup

3. **If no PRD or Architecture exists:**
   - If a `brief.md` exists, use it as the primary input — extract problem, solution, constraints, and scope from it
   - If neither brief.md nor PRD/Architecture exists, ask: "No planning docs found. Should I gather requirements inline, or would you like to run /brainstorm first to create a feature brief?"

---

## Design Document Structure

Use TodoWrite to track: Pre-flight → Introduction (incl. Alternatives Considered) → Architecture Diagrams → Data Structures → Implementation → Conventions → Cross-Cutting Concerns → Milestones → Tooling → Generate → Validate

Approach: **Precise, implementation-focused, diagram-driven.**

---

### Part 1: Introduction

**Collect:**
- Project name and one-line description
- Problem statement (from PRD or ask user)
- Solution summary (from Architecture or ask user)
- Target users
- Key constraints and assumptions

**Format:**
```markdown
## 1. Introduction

### 1.1 Purpose
{One paragraph: what this document covers and who it's for}

### 1.2 Problem Statement
{What problem are we solving? From PRD.}

### 1.3 Solution Overview
{How we're solving it. From Architecture.}

### 1.4 Scope
**In scope:**
- {Feature/capability 1}
- {Feature/capability 2}

**Out of scope:**
- {Excluded item 1}
- {Excluded item 2}

### 1.5 Key Constraints
- {Technical constraint}
- {Business constraint}
- {Timeline constraint}

### 1.6 Alternatives Considered

{For each major design decision, document what options were evaluated and why the chosen approach won. This prevents revisiting settled decisions and helps onboard new team members.}

| Decision | Option A (Chosen) | Option B | Option C |
|----------|-------------------|----------|----------|
| {Database} | PostgreSQL — mature, strong ecosystem, team expertise | MongoDB — flexible schema, but poor relational support | SQLite — simple, but no concurrent writes at scale |
| {Auth strategy} | JWT + refresh tokens — stateless, scales horizontally | Session cookies — simpler, but requires sticky sessions | OAuth-only — limits to third-party providers |
| {Hosting} | Vercel — zero-config deploys, edge functions | AWS ECS — more control, but higher ops burden | Self-hosted — cheapest, but maintenance overhead |

**For each row, document:**
- **Why chosen:** 1-2 sentences on the winning argument
- **Why not others:** Key disqualifier for each rejected option
- **Revisit trigger:** Under what conditions should this decision be reconsidered (e.g., "If we exceed 10K concurrent users, revisit the session strategy")

```markdown
#### Decision: {Decision Name}
**Chosen:** {Option A}
**Why:** {Key reason this won — cost, team expertise, performance, timeline}
**Rejected:**
- {Option B}: {Why not — e.g., "schema migrations too painful at our data volume"}
- {Option C}: {Why not — e.g., "vendor lock-in, no self-host fallback"}
**Revisit if:** {Condition that would reopen this decision}
```
```

**Store as:** `{{introduction}}`

---

### Part 2: System Architecture Diagrams (REQUIRED)

**Every design doc MUST include Mermaid diagrams.** This is non-negotiable — diagrams communicate architecture faster than prose.

**Required diagrams (generate all that apply):**

**2a. System Overview Diagram**
High-level view of all components and their connections.

```mermaid
graph TB
    Client[Browser/Mobile] --> LB[Load Balancer]
    LB --> API[API Server]
    API --> DB[(PostgreSQL)]
    API --> Cache[(Redis)]
    API --> Queue[Message Queue]
    Queue --> Worker[Background Worker]
    Worker --> DB
```

**2b. Request Flow Diagram**
How a typical request moves through the system.

```mermaid
sequenceDiagram
    participant C as Client
    participant A as API Gateway
    participant S as Service
    participant D as Database
    C->>A: HTTP Request
    A->>A: Validate JWT
    A->>S: Forward Request
    S->>D: Query
    D-->>S: Result
    S-->>A: Response
    A-->>C: JSON Response
```

**2c. Data Flow Diagram** (for complex data pipelines)
```mermaid
flowchart LR
    Input[User Input] --> Validate[Validation]
    Validate --> Transform[Transform]
    Transform --> Store[Database]
    Store --> Cache[Cache]
    Cache --> Response[API Response]
```

**2d. Entity Relationship Diagram** (for data-heavy projects)
```mermaid
erDiagram
    USER ||--o{ POST : creates
    USER ||--o{ COMMENT : writes
    POST ||--o{ COMMENT : has
    POST }o--|| CATEGORY : belongs_to
```

**2e. State Diagram** (for stateful workflows)
```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Review: Submit
    Review --> Approved: Approve
    Review --> Draft: Reject
    Approved --> Published: Publish
    Published --> [*]
```

**Ask user:** "Which diagrams are most relevant? I'll generate: System Overview, Request Flow, and ER Diagram by default."

**Rules for diagrams:**
- Use Mermaid syntax (renders in GitHub, VS Code, most markdown viewers)
- Label every node and edge clearly
- Keep diagrams focused — split complex systems into multiple diagrams
- Include a brief paragraph explaining each diagram

**Store as:** `{{architecture_diagrams}}`

---

### Part 3: Data Structures

**Document every core data entity with field-level detail.** This section is the single source of truth for your data model.

**For each entity, document:**

```markdown
### 3.X {Entity Name}

**Purpose:** {Why this entity exists}

**Table:** `{table_name}`

| Field | Type | Constraints | Default | Description |
|-------|------|-------------|---------|-------------|
| id | UUID | PK | gen_random_uuid() | Unique identifier |
| email | VARCHAR(255) | UNIQUE, NOT NULL | — | User's email address |
| name | VARCHAR(100) | NOT NULL | — | Display name |
| role | ENUM('admin','user','viewer') | NOT NULL | 'user' | Access level |
| created_at | TIMESTAMPTZ | NOT NULL | NOW() | Creation timestamp |
| updated_at | TIMESTAMPTZ | NOT NULL | NOW() | Last update timestamp |
| deleted_at | TIMESTAMPTZ | NULLABLE | NULL | Soft delete marker |

**Indexes:**
- `idx_users_email` — UNIQUE on `email` (login lookups)
- `idx_users_created_at` — on `created_at` (sorting/pagination)

**Relationships:**
- Has many: `posts` (via `posts.user_id`)
- Has many: `comments` (via `comments.user_id`)

**Validation Rules:**
- `email`: valid email format, max 255 chars
- `name`: 2-100 chars, alphanumeric + spaces
- `role`: must be one of enum values
```

**Also document:**
- **API request/response types** (TypeScript interfaces or Pydantic models)
- **Shared types** (enums, value objects, DTOs)
- **State shapes** (frontend store structure, if applicable)

**Example — TypeScript interface:**
```typescript
// types/user.ts
interface User {
  id: string;           // UUID
  email: string;        // unique, validated
  name: string;         // 2-100 chars
  role: 'admin' | 'user' | 'viewer';
  createdAt: string;    // ISO 8601
  updatedAt: string;    // ISO 8601
}

interface CreateUserRequest {
  email: string;
  name: string;
  password: string;     // min 8 chars, hashed server-side
  role?: 'user' | 'viewer'; // admin assigned manually
}

interface UserListResponse {
  success: true;
  data: User[];
  meta: { page: number; limit: number; total: number };
}
```

**Store as:** `{{data_structures}}`

---

### Part 4: Implementation Details

**This is the bridge from "what" to "how."** Document the key implementation decisions that developers need.

**4a. API Endpoints (detailed)**

For each major endpoint group, document:
```markdown
### 4.X.Y {Endpoint Group}

#### `POST /api/v1/auth/register`
**Purpose:** Register a new user account

**Request:**
```json
{
  "email": "user@example.com",
  "name": "Jane Doe",
  "password": "securePassword123"
}
```

**Response (201):**
```json
{
  "success": true,
  "data": {
    "id": "uuid-here",
    "email": "user@example.com",
    "name": "Jane Doe",
    "role": "user",
    "createdAt": "2026-02-28T12:00:00Z"
  }
}
```

**Error Responses:**
- `400` — Validation failed (missing fields, weak password)
- `409` — Email already registered

**Business Logic:**
1. Validate input (Zod/Pydantic schema)
2. Check email uniqueness
3. Hash password (bcrypt, 12 rounds)
4. Create user record
5. Send verification email (async via queue)
6. Return user (without password hash)
```

**4b. Business Logic / Service Layer**

For complex features, document the algorithm or workflow:
```markdown
### Feature: Order Processing

**Steps:**
1. Validate cart items (check stock, prices)
2. Calculate totals (subtotal, tax, shipping)
3. Create payment intent (Stripe)
4. Reserve inventory (optimistic lock)
5. Process payment
6. If payment succeeds: confirm order, send receipt
7. If payment fails: release inventory, return error

**Edge Cases:**
- Item goes out of stock between cart and checkout
- Payment succeeds but order creation fails (need compensation)
- Concurrent orders for last item in stock
```

**4c. Frontend Components** (if applicable)

For key UI components, document:
- Component name and purpose
- Props/inputs
- State management approach
- Key interactions

**Code Snippet Guidelines:**
- INCLUDE: type definitions, API contracts, complex algorithms, configuration
- INCLUDE: error handling patterns, validation schemas, middleware chains
- EXCLUDE: boilerplate (imports, basic CRUD, standard hooks)
- EXCLUDE: styling details (reference design system instead)
- EXCLUDE: test code (reference test strategy instead)

**Store as:** `{{implementation_details}}`

---

### Part 5: Conventions & Patterns

**Document project-specific patterns that every developer must follow.** Pull from CLAUDE.md, Architecture doc, and team standards.

```markdown
## 5. Conventions & Patterns

### 5.1 File/Folder Structure
```
src/
  routes/          # Express/FastAPI route handlers
  services/        # Business logic (one file per domain)
  repositories/    # Database queries (one file per entity)
  middleware/       # Auth, validation, error handling
  types/           # Shared TypeScript types
  utils/           # Pure utility functions
  config/          # Environment and app configuration
```

### 5.2 Naming Conventions
- Files: `kebab-case.ts` (e.g., `user-service.ts`)
- Classes: `PascalCase` (e.g., `UserService`)
- Functions: `camelCase` (e.g., `createUser`)
- Constants: `UPPER_SNAKE_CASE` (e.g., `MAX_RETRIES`)
- Database tables: `snake_case` plural (e.g., `user_sessions`)
- Database columns: `snake_case` (e.g., `created_at`)
- API routes: `kebab-case` plural (e.g., `/api/v1/user-sessions`)

### 5.3 Error Handling Pattern
{Document the standard error handling approach}

### 5.4 Validation Pattern
{Document where and how validation happens}

### 5.5 Authentication/Authorization Pattern
{Document the auth flow and middleware chain}

### 5.6 Logging Pattern
{Document structured logging approach}
```

**Store as:** `{{conventions}}`

---

### Part 5B: Cross-Cutting Concerns (REQUIRED)

**Document how these concerns are handled across the entire system.** Cross-cutting concerns span multiple layers and components — they can't be addressed in a single module.

```markdown
## 5B. Cross-Cutting Concerns

### 5B.1 Security
- **Authentication:** {How users prove identity — JWT, session, OAuth}
- **Authorization:** {How access is controlled — RBAC, ABAC, row-level security}
- **Data encryption:** {At rest: AES-256 via {provider}. In transit: TLS 1.3}
- **Secrets management:** {Environment variables, vault, sealed secrets}
- **Input sanitization:** {Where and how — Zod schemas at API boundary, parameterized queries}
- **OWASP mitigations:** {Rate limiting, CSRF tokens, CSP headers, etc.}

### 5B.2 Observability
- **Logging:** {Structured JSON logs, log levels, what to log at each level}
- **Metrics:** {Key business and system metrics, collection method (Prometheus, StatsD)}
- **Tracing:** {Distributed tracing approach — OpenTelemetry, correlation IDs}
- **Alerting:** {What triggers alerts, who gets paged, escalation path}
- **Dashboards:** {Key dashboards and what they monitor}

### 5B.3 Error Handling
- **Error taxonomy:** {Application errors, validation errors, system errors, third-party errors}
- **Error propagation:** {How errors flow from service → API → client}
- **Error response format:** {Standard envelope: `{ success: false, error: { code, message, details } }`}
- **Retry strategy:** {Which operations are retried, backoff policy, max attempts}
- **Circuit breaker:** {Which external dependencies have circuit breakers, thresholds}

### 5B.4 Testing Strategy
- **Unit tests:** {Coverage target, what to test, what to mock}
- **Integration tests:** {Database, API endpoints, external service contracts}
- **E2E tests:** {Critical user flows, browser automation framework}
- **Performance tests:** {Load testing tool, baseline targets, when to run}
- **Test data:** {Factories, fixtures, seed scripts, test database strategy}

### 5B.5 Deployment & Operations
- **CI/CD pipeline:** {Build → test → lint → typecheck → deploy stages}
- **Deployment strategy:** {Blue-green, canary, rolling update}
- **Feature flags:** {How new features are gated — flag system, percentage rollout}
- **Rollback procedure:** {How to revert a bad deploy — automated or manual}
- **Database migrations:** {Strategy: forward-only, backward-compatible, blue-green safe}

### 5B.6 Performance
- **Caching strategy:** {What is cached, where (Redis, CDN, browser), TTL policy}
- **Database optimization:** {Indexing strategy, query monitoring, connection pooling}
- **API pagination:** {Cursor-based vs offset, default/max page sizes}
- **Rate limiting:** {Per-endpoint limits, global limits, rate limit headers}
- **Bundle optimization:** {Code splitting, lazy loading, tree shaking — frontend only}
```

**Rules for Cross-Cutting Concerns:**
- Every section must have a concrete answer, not "TBD" — if undecided, flag it as an open question
- Reference specific tools/libraries by name (e.g., "Winston with JSON transport" not just "structured logging")
- Include configuration details where they affect architecture decisions
- This section is reviewed during the Solutioning Gate Check (`/bmad:solutioning-gate-check`)

**Store as:** `{{cross_cutting_concerns}}`

---

### Part 6: Development Milestones

**Define concrete, executable milestones — NOT time estimates.** Each milestone produces a verifiable deliverable.

```markdown
## 6. Development Milestones

### Milestone 1: Foundation
**Deliverable:** Project scaffolded, CI green, dev environment working

**Definition of Done:**
- [ ] Project initialized with stack (Next.js/Express/FastAPI)
- [ ] CLAUDE.md created with project conventions
- [ ] CI pipeline running (lint, typecheck, test, build)
- [ ] Database schema created and migrations working
- [ ] Health check endpoint returning 200
- [ ] Dev environment documented in README

**Depends on:** Nothing (start here)

---

### Milestone 2: Core Data Layer
**Deliverable:** All entities, migrations, and repository layer complete

**Definition of Done:**
- [ ] All database tables created via migrations
- [ ] Repository layer with CRUD for each entity
- [ ] Seed data script for development
- [ ] Unit tests for repository layer (80%+ coverage)

**Depends on:** Milestone 1

---

### Milestone 3: Authentication & Authorization
**Deliverable:** Users can register, login, and access protected routes

**Definition of Done:**
- [ ] Registration endpoint with email validation
- [ ] Login endpoint returning JWT
- [ ] Auth middleware protecting routes
- [ ] Role-based access control working
- [ ] Integration tests for auth flow

**Depends on:** Milestone 2

---

### Milestone 4: Core Features (per Epic)
**Deliverable:** {Epic name} fully functional

**Definition of Done:**
- [ ] All endpoints for {epic} implemented
- [ ] Business logic tested (unit + integration)
- [ ] Frontend components connected (if applicable)
- [ ] Error handling for edge cases

**Depends on:** Milestone 3

---

### Milestone 5: Polish & Deploy
**Deliverable:** Production-ready release

**Definition of Done:**
- [ ] All Must-Have FRs implemented and tested
- [ ] NFR targets met (performance, security)
- [ ] Error pages and empty states handled
- [ ] Monitoring and alerting configured
- [ ] Production deployment successful
- [ ] Smoke tests passing in production

**Depends on:** All previous milestones
```

**Guidelines:**
- Each milestone = 1 sprint or less of focused work
- Every milestone has a verifiable "Definition of Done" checklist
- Milestones are ordered by dependency, not by calendar date
- Map PRD Epics to milestones where possible
- Include a dependency chain so the critical path is visible

**Ask user:** "How many milestones should we plan? Typical: 4-6 for Level 2, 6-10 for Level 3."

**Store as:** `{{milestones}}`

---

### Part 7: Project Setup & Tooling

**Document everything a developer needs to go from `git clone` to running the app.**

```markdown
## 7. Project Setup & Tooling

### 7.1 Prerequisites
- Node.js >= 22 / Python >= 3.12
- pnpm >= 9 / uv >= 0.4
- PostgreSQL >= 16
- Redis >= 7 (if applicable)
- Docker & Docker Compose (optional)

### 7.2 Quick Start
```bash
git clone <repo-url>
cd <project-name>
cp .env.example .env          # Fill in local values
pnpm install                   # Install dependencies
pnpm db:migrate                # Run migrations
pnpm db:seed                   # Seed development data
pnpm dev                       # Start dev server → http://localhost:3000
```

### 7.3 Environment Variables
| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| DATABASE_URL | Yes | PostgreSQL connection | postgresql://user:pass@localhost:5432/dbname |
| JWT_SECRET | Yes | Token signing key | (generate with openssl rand -hex 32) |
| REDIS_URL | No | Redis connection | redis://localhost:6379 |

### 7.4 Available Scripts
| Command | Description |
|---------|-------------|
| `pnpm dev` | Start development server with hot reload |
| `pnpm build` | Production build |
| `pnpm test` | Run all tests |
| `pnpm test:watch` | Run tests in watch mode |
| `pnpm lint` | Lint with ESLint |
| `pnpm typecheck` | TypeScript type checking |
| `pnpm db:migrate` | Run database migrations |
| `pnpm db:seed` | Seed development data |
| `pnpm db:studio` | Open database GUI |

### 7.5 Key Dependencies
| Package | Purpose | Why This One |
|---------|---------|-------------|
| {package} | {what it does} | {why chosen over alternatives} |

### 7.6 Docker Development (Optional)
```bash
docker compose up -d           # Start all services
docker compose logs -f api     # Follow API logs
docker compose down            # Stop all services
```
```

**Store as:** `{{tooling}}`

---

## Generate Document

1. **Assemble all sections** into a single markdown document
2. **Output path:** `docs/{project-name}/design-doc.md`
3. **Write document** using Write tool
4. **Display summary:**
   ```
   Design Document Created!

   Location: docs/{project-name}/design-doc.md

   Contents:
   - Introduction & Scope (incl. Alternatives Considered)
   - Architecture Diagrams: {count} Mermaid diagrams
   - Data Structures: {entity_count} entities documented
   - Implementation: {endpoint_count} endpoints, {feature_count} features
   - Conventions: {section_count} pattern sections
   - Cross-Cutting Concerns: 6 areas covered
   - Alternatives Considered: {decision_count} decisions documented
   - Milestones: {milestone_count} milestones with DoD checklists
   - Tooling: Setup guide with {var_count} env variables

   Diagrams included:
   {list of diagram types generated}
   ```

---

## Validation

```
Checklist:
- [ ] At least 2 Mermaid diagrams included (system overview + one other)
- [ ] Every data entity has field-level documentation (type, constraints, default)
- [ ] API endpoints include request/response examples with JSON
- [ ] Error responses documented for each endpoint
- [ ] Alternatives Considered section documents at least 2 major design decisions with trade-offs
- [ ] Each alternative has a "Revisit if" trigger condition
- [ ] Cross-Cutting Concerns section covers all 6 areas (security, observability, error handling, testing, deployment, performance)
- [ ] No cross-cutting concern is left as "TBD" — flag as open question if undecided
- [ ] Conventions cover: naming, file structure, error handling, validation
- [ ] Every milestone has a Definition of Done checklist
- [ ] Milestones have explicit dependencies
- [ ] Setup guide works from git clone to running app
- [ ] Environment variables documented with examples
- [ ] Code snippet guidelines followed (no boilerplate, no styling details)
- [ ] Data structures include both DB schema AND TypeScript/Python types
- [ ] Response envelope format matches project standard ({ success, data, error, meta })
```

**Ask user:** "Please review the design document. Is anything missing or unclear?"

If changes needed → Edit and re-validate
If approved → Continue

---

## Recommend Next Steps

```
Design Document complete!

Next: Sprint Planning (Phase 4)
Run /sprint-planning to:
- Break milestones into detailed stories
- Estimate story complexity
- Plan sprint iterations
- Begin implementation

You now have the complete planning chain:
  Product Brief → PRD → Architecture → Design Doc

Developers can start building from Milestone 1 immediately.
```

**Offer:** "Would you like to begin sprint planning, or start implementing Milestone 1 directly?"

---

## Rules

- ALWAYS include at least 2 Mermaid diagrams — architecture overview is mandatory
- ALWAYS document data structures at field level (type, constraints, defaults)
- ALWAYS include request/response JSON examples for API endpoints
- ALWAYS define milestones by deliverables, NEVER by time estimates
- ALWAYS include a Definition of Done checklist for each milestone
- ALWAYS include Alternatives Considered for at least 2 major design decisions
- ALWAYS include Cross-Cutting Concerns covering all 6 areas — no "TBD" allowed
- ALWAYS include a "Revisit if" trigger for each rejected alternative
- ALWAYS document the setup from git clone to running app
- NEVER include boilerplate code (basic CRUD, standard imports)
- NEVER include styling/CSS details — reference the design system skill instead
- NEVER include test implementations — reference the test strategy instead
- NEVER skip error response documentation for endpoints
- Use the project's response envelope format for all API response examples
- Pull conventions from existing CLAUDE.md and Architecture doc — don't invent new ones
- Keep code snippets focused on contracts and complex logic, not implementation details
