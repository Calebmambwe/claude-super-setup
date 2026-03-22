# Reverse Documentation Template

> **Portable prompt template.** Generates implementation-focused documentation from an existing codebase. For onboarding, migration, or feeding into `/design-doc`.
> **Claude Code command:** `/reverse-doc`
> **Pipeline:** `existing repo → /reverse-doc → /design-doc → /milestone-prompts`

---

## Instructions

Your task is to write documentation for an existing repository. The goal is an **implementation-focused, onboarding document** for an experienced engineer — concise, visual, and reference-grade.

---

## Phase 1: Traverse the Codebase First (MANDATORY)

**Do NOT start writing until Phase 1 is complete.**

### Step 1: Project Overview
Read: `README.md`, `CLAUDE.md`, `package.json` / `pyproject.toml` / `Cargo.toml`

Extract: project name, description, dependencies, scripts, version.

### Step 2: Map the Directory Tree

List all source files (exclude node_modules, __pycache__, dist, .git):
```bash
find . -type f \( -name "*.ts" -o -name "*.py" -o -name "*.go" \) | grep -v node_modules | head -100
```

Record: top-level structure, file count per directory, entry points.

### Step 3: Read Entry Points and Configuration
In order: entry point → config → routes/endpoints → middleware → database setup

### Step 4: Map Data Layer
Read schema/migrations, models, repositories. For each entity: table name, fields (type, constraints, defaults), relationships, indexes.

### Step 5: Map Business Logic
Read service layer. For each service: purpose, key methods, external dependencies, critical algorithms, edge cases.

### Step 6: Map API Surface
Read route/handler files. For each endpoint group: method, path, auth, request/response shapes, error responses.

### Step 7: Map Frontend (if applicable)
Pages/routes, major components, state management, API integration.

### Step 8: Search for Patterns
```bash
grep -r "catch\|except\|Error" src/ | head -20       # Error handling
grep -r "validate\|schema\|zod\|pydantic" src/ | head -20  # Validation
grep -r "auth\|jwt\|token\|middleware" src/ | head -20     # Auth
```

### Step 9: Identify Unknowns

List anything unclear before writing. **Ask the user about unknowns before proceeding.**

---

## Phase 2: Plan Document Structure

Output a proposed table of contents. **Ask for confirmation before writing.**

Default structure:
1. System Overview — purpose, stack, architecture diagram
2. Project Structure — directory layout, conventions
3. Data Model — entities, relationships, ER diagram
4. API Surface — endpoints, auth, request/response examples
5. Core Business Logic — services, algorithms, non-obvious decisions
6. Frontend Architecture — (if applicable)
7. Infrastructure — deployment, CI/CD, Docker
8. Conventions — naming, error handling, validation patterns
9. Development Guide — setup, commands, env vars

---

## Phase 3: Write Section by Section

**Write ONE section at a time. Ask for confirmation after each section.**

### Writing Rules

**Conciseness:**
- Target 400-800 lines total
- Use Mermaid diagrams where they replace 3+ paragraphs
- Use tables for structured data (entities, endpoints, env vars)
- Use code snippets for contracts and patterns — NOT full implementations

**What to include in code snippets:**
```
INCLUDE:
- Type definitions / interfaces (with placeholder bodies)
- API contracts (request/response shapes)
- Critical algorithms (pseudocode or simplified)
- Configuration patterns
- Error handling patterns

EXCLUDE:
- Full function implementations (use "// ... implementation" placeholder)
- Import statements
- Boilerplate CRUD
- CSS/styling
- Test implementations
```

**Always include file paths** when referencing code: `src/services/auth-service.ts`

### Section Template: Data Model

```markdown
## 3. Data Model

### ER Diagram
[mermaid erDiagram]

### 3.1 [Entity Name]
**Table:** `[table_name]` | **File:** `[path/to/model]`

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | UUID | PK | ... |

**Indexes:** [list]
**Relationships:** [list]
```

### Section Template: API Surface

```markdown
## 4. API Surface

### 4.1 [Resource Group]
| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | /api/v1/users | No | Create user |

**Request/Response Example:**
// POST /api/v1/users
// Request: { "email": "...", "name": "..." }
// Response (201): { "success": true, "data": { "id": "...", ... } }
// Error (400): { "success": false, "error": { "code": "...", "message": "..." } }
```

---

## Phase 4: Final Assembly

After all sections approved:
1. Assemble into single document with table of contents
2. Write to `docs/[project]/reverse-doc.md`
3. Validate: 400-800 lines, 2+ Mermaid diagrams, no full implementations, no secrets

---

## Hard Rules

- NEVER start writing before completing Phase 1
- ALWAYS ask about unknowns before writing
- ALWAYS write one section at a time with confirmation
- NEVER exceed 800 lines
- NEVER include secrets (API keys, passwords)
- NEVER fabricate information — if unclear from code, say so
- Output must be compatible with `/design-doc` and `/milestone-prompts` as input
