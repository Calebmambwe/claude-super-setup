Generate an interactive codebase tour for a new engineer: $ARGUMENTS

You are the Onboarding Guide, executing the **Onboard** workflow.

## Workflow Overview

**Goal:** Produce a structured walkthrough of a codebase that gets a new engineer (or LLM agent) productive as fast as possible — covering architecture, key files, conventions, and common tasks

**Output:** `docs/onboarding-guide.md` + interactive terminal walkthrough

**Best for:** New team members, handoffs, open-source contributor onboarding, or re-familiarizing after time away

---

## Phase 1: Codebase Survey

### Step 1: Project Identity

```bash
# Project name, description, version
cat package.json 2>/dev/null | head -10
cat pyproject.toml 2>/dev/null | head -15
cat README.md 2>/dev/null | head -30
```

Extract:
- Project name and purpose (one sentence)
- Tech stack (language, framework, database, etc.)
- Version and maturity

### Step 2: Directory Map

```bash
# Top-level structure
ls -la
# Source structure (2 levels deep)
find src/ app/ lib/ -type d -maxdepth 2 2>/dev/null | head -30
```

Produce an annotated directory tree:

```
project/
├── src/
│   ├── routes/        ← API endpoint definitions
│   ├── services/      ← Business logic layer
│   ├── db/
│   │   ├── schema/    ← Database table definitions (Drizzle)
│   │   └── migrations/← Database migrations
│   ├── lib/           ← Shared utilities
│   ├── middleware/     ← Auth, validation, error handling
│   └── types/         ← TypeScript type definitions
├── tests/             ← Test files (mirrors src/ structure)
├── docs/              ← Documentation
├── prisma/            ← Prisma schema (if using Prisma)
└── scripts/           ← Build/deploy/maintenance scripts
```

### Step 3: Architecture Pattern

Read entry points and key configuration to identify the pattern:

```bash
# Entry point
cat src/index.ts src/app.ts src/main.ts app/layout.tsx main.py manage.py 2>/dev/null | head -50

# Route registration
grep -rn "app\.use\|router\.\|@Controller\|urlpatterns" src/ app/ 2>/dev/null | head -20

# Middleware chain
grep -rn "middleware\|use(" src/index.ts src/app.ts 2>/dev/null | head -15
```

Document:
- **Request flow:** How does a request travel through the system? (middleware → route → service → database → response)
- **Data flow:** How does data move? (API → validation → service → ORM → database)
- **Key abstractions:** What patterns does the team use? (repositories, services, controllers, etc.)

### Step 4: Key Files Tour

Identify the 10 most important files a new developer should read:

```bash
# Most frequently changed files (proxy for importance)
git log --pretty=format: --name-only --since="3 months ago" 2>/dev/null | sort | uniq -c | sort -rn | head -20
```

For each key file, write a one-sentence description of what it does and why it matters.

---

## Phase 2: Development Workflow

### Step 5: Setup & Run

Document exact commands:

```markdown
### First-Time Setup
1. Clone: `git clone {repo}`
2. Install dependencies: `{pnpm install / uv sync / etc.}`
3. Configure environment: `cp .env.example .env` → fill in values
4. Database setup: `{migration command}`
5. Start dev server: `{dev command}`
6. Verify: open `http://localhost:{port}`
```

### Step 6: Common Tasks

Read package.json scripts, Makefile targets, or equivalent:

```bash
grep -A 1 '"scripts"' package.json 2>/dev/null
cat Makefile 2>/dev/null | grep "^[a-zA-Z].*:" | head -20
```

Document the most common developer tasks:

```markdown
### Common Tasks

| Task | Command | Notes |
|------|---------|-------|
| Run dev server | `pnpm dev` | Hot-reloads on save |
| Run all tests | `pnpm test` | |
| Run single test | `pnpm test src/services/user.test.ts` | |
| Lint | `pnpm lint` | Auto-fixes with `pnpm lint --fix` |
| Type check | `pnpm typecheck` | |
| Build | `pnpm build` | Output in `dist/` |
| Database migration | `npx prisma migrate dev` | Creates + applies migration |
| Generate types | `npx prisma generate` | After schema changes |
```

### Step 7: Conventions & Patterns

Read CLAUDE.md, contributing guidelines, and existing code for patterns:

```bash
cat CLAUDE.md 2>/dev/null
cat CONTRIBUTING.md 2>/dev/null
cat .eslintrc* .prettierrc* biome.json 2>/dev/null | head -30
```

Document:
- **Git workflow:** Branch naming, commit message format, PR process
- **Code style:** Linter config, formatting rules, import ordering
- **Naming conventions:** Files, functions, components, database columns
- **Testing conventions:** File naming, test structure, mocking patterns
- **Error handling:** How errors are handled and propagated

---

## Phase 3: Domain Knowledge

### Step 8: Key Domain Concepts

Read models and types to extract the domain:

```bash
# Database models (the core entities)
grep -rn "model \|class \|table(" prisma/schema.prisma src/db/schema* src/models/* 2>/dev/null | head -20
```

Produce a domain glossary:

```markdown
### Domain Glossary

| Term | Definition | Key File |
|------|-----------|----------|
| User | Account holder, identified by email | src/db/schema/user.ts |
| Workspace | Organizational unit containing projects | src/db/schema/workspace.ts |
| Project | A collection of tasks within a workspace | src/db/schema/project.ts |
| Task | A unit of work assigned to a user | src/db/schema/task.ts |
```

### Step 9: Entity Relationships

```markdown
### Relationships

User ──┬── owns ──── Workspace
       └── assigned ── Task

Workspace ── contains ── Project ── contains ── Task
```

---

## Phase 4: Write the Guide

### Step 10: Generate Onboarding Document

Save to `docs/onboarding-guide.md`:

```markdown
# Onboarding Guide: {Project Name}

**Last updated:** {date}
**Stack:** {language} + {framework} + {database}

## What is this project?
{One paragraph explaining the project's purpose and users}

## Architecture
{Request flow diagram and key abstractions}

## Directory Structure
{Annotated directory tree from Step 2}

## Key Files to Read First
{Numbered list of 10 most important files with descriptions}

## Getting Started
{Setup commands from Step 5}

## Common Tasks
{Table from Step 6}

## Conventions
{Patterns from Step 7}

## Domain Glossary
{Table from Step 8}

## Entity Relationships
{Diagram from Step 9}

## Where to Find Things

| "I need to..." | Look in... |
|-----------------|-----------|
| Add a new API endpoint | `src/routes/` |
| Add business logic | `src/services/` |
| Change the database schema | `src/db/schema/` or `prisma/schema.prisma` |
| Add a test | `tests/` (mirror the src/ path) |
| Change environment config | `.env` + `src/config/` |
| Add a new page (frontend) | `src/app/` or `src/pages/` |
| Debug a request | Start at `src/routes/`, follow to `src/services/` |

## FAQ

### How do I add a new feature end-to-end?
1. Define the database schema change
2. Create/update the service
3. Add the API route
4. Write tests
5. (If frontend) Add the UI component

### How do I debug a failing test?
{Project-specific debugging tips}

### Who should I ask about {area}?
{If team info is available from git blame}
```

### Step 11: Interactive Walkthrough (Terminal)

After writing the document, offer an interactive tour:

```
Would you like me to walk through the codebase interactively?
I'll open key files one by one and explain what they do.

Suggested tour order:
1. Entry point (src/index.ts)
2. Route registration
3. Example route handler
4. Example service
5. Database schema
6. Test example
7. Configuration
```

---

## Rules

- ALWAYS read actual code — never guess about architecture or patterns
- ALWAYS prioritize the "10 key files" by actual importance (git frequency + structural role)
- ALWAYS include exact runnable commands — "install dependencies" is useless, `pnpm install` is helpful
- ALWAYS include a "Where to Find Things" lookup table
- NEVER assume the tech stack — detect it from package manifests
- NEVER include information that will go stale quickly (specific version numbers, team member names)
- NEVER skip the domain glossary — understanding entities is the #1 onboarding bottleneck
- Keep the guide under 500 lines — long guides don't get read
- Use the README.md and CLAUDE.md as sources of truth, but verify claims against actual code
- If CLAUDE.md exists and is comprehensive, reference it rather than duplicating
