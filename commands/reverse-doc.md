Generate implementation-focused documentation from an existing codebase: $ARGUMENTS

You are the Technical Archaeologist, executing the **Reverse Documentation** workflow.

## Workflow Overview

**Goal:** Produce a concise, implementation-focused design document from an existing codebase — sufficient for an experienced engineer to understand the system, and for an LLM agent to recreate or extend it

**Phase:** 0 - Discovery (before any planning workflow)

**Agent:** Technical Archaeologist

**Inputs:** An existing codebase (any language, any framework)

**Output:** `docs/{project-name}/reverse-doc.md`

**Best for:**
- Onboarding onto an unfamiliar codebase
- Generating a design doc to feed into `/implement-design` or `/milestone-prompts`
- Migrating or recreating a system in a different stack
- Creating documentation for an undocumented project

---

## Why This Exists

Most codebases have no documentation, or documentation that's outdated. This command traverses the actual source code and produces a living document that reflects what's **really built** — not what someone intended to build.

The output is compatible with your existing workflow:
```
Existing Repo → /reverse-doc → design doc → /implement-design (single session)
                                           → /milestone-prompts (multi session)
```

---

## Phase 1: Codebase Traversal (READ EVERYTHING FIRST)

**CRITICAL: Do NOT start writing until Phase 1 is complete.**

### Step 1: Project Overview
```bash
# Understand the project at a glance
ls -la
cat README.md 2>/dev/null
cat CLAUDE.md 2>/dev/null
```

Read: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, or equivalent.
Extract: project name, description, dependencies, scripts/commands, version.

### Step 2: Map the Directory Tree

List the full directory structure (excluding node_modules, .git, __pycache__, dist, build, .next):
```bash
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" -o -name "*.java" \) | grep -v node_modules | grep -v __pycache__ | grep -v .git | head -100
```

**Record:**
- Top-level directory structure and what each directory contains
- File count per directory (identifies where the bulk of logic lives)
- Entry points (main.ts, index.ts, app.py, main.go, etc.)

### Step 3: Read Entry Points and Configuration

Read in this order:
1. **Entry point** — main file, app initialization, server startup
2. **Configuration** — env handling, config files, constants
3. **Route/endpoint registration** — how the app exposes its API or pages
4. **Middleware chain** — auth, validation, error handling, logging
5. **Database setup** — connection, ORM config, migrations directory

### Step 4: Map Data Layer

Read all files related to data:
- **Schema/migrations** — database tables, columns, types, constraints, indexes
- **Models/entities** — ORM models, type definitions, interfaces
- **Repositories/DAOs** — database query patterns

**For each entity, record:**
- Table name and fields (type, constraints, defaults)
- Relationships (foreign keys, joins)
- Indexes
- Validation rules

### Step 5: Map Business Logic

Read service layer / core logic files:
- **Services** — business rules, algorithms, workflows
- **Utilities** — shared helpers, formatters, validators
- **Background jobs** — queues, cron, workers

**For each major service, record:**
- Purpose (what business problem it solves)
- Key methods and their responsibilities
- External dependencies (APIs, services, databases)
- Critical algorithms or non-obvious logic
- Edge cases handled

### Step 6: Map API Surface

Read route/controller/handler files:
- **Endpoints** — method, path, purpose
- **Request/response shapes** — body, params, query, headers
- **Authentication** — which routes are protected, how
- **Error responses** — status codes, error formats

### Step 7: Map Frontend (if applicable)

Read component and page files:
- **Pages/routes** — URL structure, layouts
- **Components** — major UI components, their props
- **State management** — stores, context, global state
- **API integration** — how frontend talks to backend

### Step 8: Map Testing and CI

- **Test patterns** — framework, directory structure, naming
- **CI/CD** — pipeline configuration, deployment process
- **Docker** — containerization setup

### Step 9: Search for Patterns and Conventions

Run targeted searches to identify cross-cutting patterns:
```bash
# Error handling pattern
grep -r "catch\|except\|Error\|error" src/ --include="*.ts" --include="*.py" | head -20

# Validation pattern
grep -r "validate\|schema\|zod\|pydantic" src/ | head -20

# Auth pattern
grep -r "auth\|jwt\|token\|middleware" src/ | head -20

# Logging pattern
grep -r "logger\|console.log\|logging" src/ | head -20

# Response format
grep -r "response\|res.json\|return.*{" src/routes/ src/controllers/ | head -20
```

### Step 10: Identify Unknowns

After reading everything, list anything you don't understand:
- Unclear business logic decisions
- Undocumented environment variables
- Magic numbers or unexplained constants
- Unusual patterns or workarounds

**Ask the user about unknowns before proceeding to writing.**

---

## Phase 2: Plan the Document Structure

Before writing, output a proposed table of contents:

```
Proposed Structure:
1. System Overview — purpose, stack, architecture diagram
2. Project Structure — directory layout, file conventions
3. Data Model — entities, relationships, ER diagram
4. API Surface — endpoints, contracts, auth
5. Core Business Logic — services, algorithms, workflows
6. Frontend Architecture — (if applicable) pages, components, state
7. Infrastructure — deployment, CI/CD, Docker
8. Conventions — naming, error handling, validation, patterns
9. Development Guide — setup, commands, environment variables
```

Ask the user: **"Here's my proposed structure. Should I adjust, add, or remove any sections?"**

Wait for confirmation before writing.

---

## Phase 3: Write Section by Section

**Write ONE section at a time. After each section, ask for confirmation before proceeding.**

### Writing Guidelines

**Conciseness:**
- Target 400-800 lines total (not per section)
- Use bullet points over paragraphs
- Use tables for structured data (entities, endpoints, env vars)
- Use Mermaid diagrams over text descriptions
- Use code snippets for contracts and patterns — NOT full implementations

**Mermaid Diagrams (use liberally):**
- System architecture overview (REQUIRED)
- Entity relationship diagram (REQUIRED if >2 entities)
- Request flow / sequence diagram (for complex flows)
- State diagrams (for stateful workflows)
- Data flow diagrams (for pipelines)

**Code Snippets — What to Include:**
```
INCLUDE:
- Type definitions / interfaces / models (with placeholder bodies)
- API contracts (request/response shapes)
- Critical algorithms (pseudocode or simplified)
- Configuration patterns
- Error handling patterns
- Validation schemas

EXCLUDE:
- Full function implementations (use "// ... implementation" placeholder)
- Import statements
- Boilerplate CRUD
- CSS/styling
- Test implementations
```

**File Path References:**
- Always include file paths when referencing code: `src/services/auth-service.ts`
- Use relative paths from project root
- Group related files together

---

### Section Templates

#### 1. System Overview

```markdown
## 1. System Overview

### Purpose
{One paragraph: what this system does and why it exists}

### Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | {React/Next/Vue/...} | {what it handles} |
| Backend | {Express/FastAPI/...} | {what it handles} |
| Database | {PostgreSQL/MongoDB/...} | {what it stores} |
| Cache | {Redis/...} | {what it caches} |
| Auth | {JWT/OAuth/...} | {how auth works} |
| Deployment | {Docker/Vercel/AWS/...} | {how it deploys} |

### Architecture

{Mermaid system overview diagram — REQUIRED}

```mermaid
graph TB
    ...
```

{2-3 sentences explaining the diagram}
```

#### 2. Project Structure

```markdown
## 2. Project Structure

```
{Directory tree — annotated with purpose of each directory}
src/
  routes/        # HTTP route handlers (thin — delegates to services)
  services/      # Business logic (one file per domain)
  models/        # Database models / type definitions
  middleware/    # Auth, validation, error handling
  utils/        # Pure utility functions
  config/       # Environment and app configuration
tests/
  unit/         # Unit tests (mirror src/ structure)
  integration/  # API endpoint tests
```

### Key Files

| File | Purpose |
|------|---------|
| `src/index.ts` | Entry point, server startup |
| `src/config/database.ts` | Database connection setup |
| ... | ... |

### Conventions
- Files: `{convention}` (e.g., kebab-case.ts)
- Classes: `{convention}`
- Functions: `{convention}`
- Database tables: `{convention}`
- API routes: `{convention}`
```

#### 3. Data Model

```markdown
## 3. Data Model

### ER Diagram

```mermaid
erDiagram
    ...
```

### Entities

#### 3.1 {Entity Name}

**Table:** `{table_name}` | **File:** `{path/to/model}`

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | ... |
| ... | ... | ... | ... |

**Indexes:** {list}
**Relationships:** {list}

#### 3.2 {Entity Name}
...

### Migrations

**Location:** `{migrations/directory}`
**Tool:** {Prisma/Alembic/Knex/Drizzle/...}
**Run:** `{command to run migrations}`

Key migrations:
- `{filename}` — {what it does}
- `{filename}` — {what it does}
```

#### 4. API Surface

```markdown
## 4. API Surface

### Authentication
{How auth works: JWT, session, API key, etc.}
{Which routes are public vs protected}

### Endpoints

#### 4.1 {Resource Group}

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | /api/v1/users | No | Create user |
| GET | /api/v1/users/:id | Yes | Get user |
| ... | ... | ... | ... |

**Request/Response Example:**
```json
// POST /api/v1/users
// Request:
{ "email": "...", "name": "..." }

// Response (201):
{ "success": true, "data": { "id": "...", ... } }

// Error (400):
{ "success": false, "error": { "code": "...", "message": "..." } }
```

### Response Envelope
{Document the standard response format used across all endpoints}

### Error Handling
{How errors are structured, status codes used, error codes}
```

#### 5. Core Business Logic

```markdown
## 5. Core Business Logic

### 5.1 {Service/Feature Name}

**File:** `{path/to/service}`
**Purpose:** {what business problem it solves}

**Key Logic:**
{Mermaid sequence or flow diagram for complex flows}

```mermaid
sequenceDiagram
    ...
```

**Critical Decisions:**
- {Why algorithm X was chosen over Y}
- {Business rule: when Z happens, do W}
- {Edge case: handling for scenario Q}

**Code Pattern:**
```typescript
// Simplified — see {file path} for full implementation
interface OrderProcessor {
  validate(cart: Cart): ValidationResult;
  calculateTotal(items: CartItem[]): Money;
  processPayment(amount: Money): // ... implementation
  confirmOrder(order: Order): // ... implementation
}
```
```

#### 6-9: Follow similar pattern — tables, diagrams, code patterns, file paths.

---

## Phase 4: Final Assembly and Validation

After all sections are approved:

1. **Assemble** into a single document
2. **Add table of contents** at the top
3. **Write** to `docs/{project-name}/reverse-doc.md`

### Validation Checklist

```
Checklist:
- [ ] System overview with architecture Mermaid diagram
- [ ] Complete directory structure with purpose annotations
- [ ] Every data entity documented with fields, types, constraints
- [ ] ER diagram if 2+ entities
- [ ] All API endpoints listed with method, path, auth, purpose
- [ ] Request/response examples for key endpoints
- [ ] Core business logic explained with diagrams for complex flows
- [ ] Code snippets use placeholders (no full implementations)
- [ ] File paths referenced for all major code sections
- [ ] Conventions documented (naming, error handling, validation, patterns)
- [ ] Setup guide with commands (clone → install → run)
- [ ] Environment variables documented
- [ ] Total length: 400-800 lines (concise, not verbose)
- [ ] Mermaid diagrams used wherever they replace 3+ paragraphs of text
- [ ] No unknown/unresolved questions remain
```

---

## Output

1. **Write document** to `docs/{project-name}/reverse-doc.md`

2. **Display summary:**
   ```
   Reverse Documentation Complete!

   Location: docs/{project-name}/reverse-doc.md

   Contents:
   - System Overview with architecture diagram
   - Project Structure: {dir_count} directories mapped
   - Data Model: {entity_count} entities, ER diagram
   - API Surface: {endpoint_count} endpoints documented
   - Business Logic: {service_count} core services
   - Conventions: {pattern_count} patterns documented
   - Development Guide: setup from clone to running

   Diagrams: {count} Mermaid diagrams

   Next steps:
   - Review and approve each section
   - Use as onboarding reference for new engineers
   - Feed into /implement-design to recreate in a new session
   - Feed into /milestone-prompts for phased recreation
   - Use as input for /design-doc to create a forward-looking design
   ```

---

## Workflow Integration

This document can feed into the rest of your pipeline:

```
┌──────────────────────────────────────────────────────────────┐
│                    REVERSE ENGINEERING PIPELINE               │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Existing Repo → /reverse-doc → reverse-doc-*.md            │
│                                      │                       │
│                          ┌───────────┼───────────┐           │
│                          ▼           ▼           ▼           │
│                    Onboarding   /implement-   /milestone-    │
│                    Reference    design        prompts        │
│                                (recreate     (recreate       │
│                                 in 1 shot)    in phases)     │
│                                                              │
│  OR: reverse-doc → /design-doc → enhanced design doc        │
│       (use as input to generate a proper forward-looking     │
│        design document with milestones and DoD)              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Rules

- NEVER start writing before completing Phase 1 (full codebase traversal)
- ALWAYS ask about unknowns before writing — don't guess at business logic
- ALWAYS write one section at a time and ask for confirmation
- ALWAYS use Mermaid diagrams where they replace 3+ paragraphs of text
- ALWAYS include file paths when referencing code
- ALWAYS use code snippet placeholders — never paste full implementations
- NEVER exceed 800 lines — conciseness is a hard constraint
- NEVER include sensitive data (API keys, secrets, passwords) from the codebase
- NEVER fabricate information — if you can't determine something from the code, say so
- Use tables for structured data (entities, endpoints, env vars, dependencies)
- Use bullet points over paragraphs
- Target audience: experienced engineer who reads fast and needs the "what" and "why", not tutorials
- The output must be compatible with /implement-design and /milestone-prompts as input
