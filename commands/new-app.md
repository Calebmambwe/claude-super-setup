---
name: new-app
description: Scaffold a new app from a curated stack template with full automation
---

You are scaffolding a new app from a curated, constrained stack. This mirrors Lovable's approach: lock the stack to eliminate decision paralysis and reduce build errors.

If $ARGUMENTS specifies a stack name ("web", "api", "mobile"), use it directly. Otherwise, run Step 0 to detect intent from natural language before presenting the menu.

## Step 0: Smart Template Detection

Run this step when $ARGUMENTS contains a natural-language description rather than a known template name or stack keyword.

Scan $ARGUMENTS (case-insensitive) against the keyword map below. Pick the **first** row whose keywords match. If multiple rows match, pick the one with the most keyword hits.

| Keywords (any match triggers) | Template |
|-------------------------------|----------|
| saas, billing, subscription, payments, stripe | saas-complete |
| ai, chat, rag, embeddings, llm, gpt, claude | ai-rag-complete |
| landing, marketing, blog, content | web-shadcn-v4 |
| dashboard, admin, analytics | web-shadcn-v4 |
| mobile, ios, android, app | mobile-gluestack |
| api, backend, server, microservice | api-service |
| monorepo, mono, workspace, turborepo | monorepo |
| email, newsletter, transactional | email-templates |
| extension, chrome, browser | chrome-extension |
| cli, command line, tool | cli-tool |
| flutter, dart | mobile-flutter |
| astro, static, content | web-astro |
| svelte, sveltekit | web-sveltekit |
| remix | web-remix |
| t3, trpc, prisma | web-t3 |
| python, fastapi, django | api-fastapi |
| edge, cloudflare, workers | api-hono-edge |
| revenucat, iap, in-app purchase | mobile-expo-revenucat |

**If a match is found:** confirm with the user before proceeding:
```
Detected intent: "{matched keywords}" → template: {template}

Use {template}? (yes / no — or describe what you want differently)
```

**If no match is found:** show the full template menu grouped by category and let the user choose:

```
No template auto-detected. Pick one:

WEB
  1.  web-shadcn-v4        — Next.js 15 + shadcn/ui v4 + Tailwind + Supabase
  2.  web-t3               — T3 Stack: Next.js + tRPC + Prisma + Tailwind
  3.  web-astro            — Astro + Tailwind (static/content-first)
  4.  web-sveltekit        — SvelteKit + TypeScript + Tailwind
  5.  web-remix            — Remix + TypeScript + Tailwind

SAAS / AI
  6.  saas-complete        — Next.js + Stripe + Supabase + shadcn/ui (batteries-included SaaS)
  7.  ai-rag-complete      — Next.js + LangChain + Pinecone + OpenAI (RAG/chat apps)

API / BACKEND
  8.  api-service          — Hono + TypeScript + Drizzle + PostgreSQL
  9.  api-fastapi          — FastAPI + Python + SQLAlchemy + Alembic
  10. api-hono-edge        — Hono on Cloudflare Workers (edge-first)

MOBILE
  11. mobile-gluestack     — React Native + Expo + Gluestack UI + Supabase
  12. mobile-expo-revenucat — React Native + Expo + RevenueCat (IAP)
  13. mobile-nativewind    — React Native + Expo + NativeWind
  14. mobile-flutter       — Flutter + Dart + Supabase

TOOLING / OTHER
  15. monorepo             — Turborepo + pnpm workspaces + shared packages
  16. chrome-extension     — Chrome Extension + TypeScript + Vite
  17. cli-tool             — Node.js CLI + TypeScript + Commander
  18. email-templates      — React Email + Resend + TypeScript

Enter a number or template name:
```

Store the resolved template as `{{TEMPLATE}}` and the project name as `{{PROJECT_NAME}}`.

**Validate PROJECT_NAME** (if provided in $ARGUMENTS): Must match `^[a-zA-Z0-9_-]+$`. Reject anything else with an error message and prompt again.

## Step 1: Choose Stack

If `{{TEMPLATE}}` was already resolved in Step 0, skip this step entirely.

Otherwise present the user with these options (for backward compatibility with direct stack keywords):

```
Which stack?

1. web    — Next.js 15 + TypeScript + Tailwind + shadcn/ui + Supabase
             Best for: SaaS apps, dashboards, consumer web apps
             Includes: Supabase clients, database types stub, Vitest setup

2. api    — Hono + TypeScript + Drizzle ORM + PostgreSQL
             Best for: REST/GraphQL APIs, microservices, webhooks
             Includes: OpenAPI spec, Docker, health check, ESLint

3. mobile — React Native + Expo + TypeScript + Supabase
             Best for: iOS/Android apps, cross-platform mobile
             Includes: Expo Router navigation, EAS Build config, Supabase client
```

If $ARGUMENTS contains a recognized stack keyword (`web`, `api`, `mobile`), skip the prompt. If $ARGUMENTS contains a project name but no recognizable keyword, Step 0 should have caught it — if not, ask the user to clarify. Parse both `new-app web my-app` and `new-app my-app web`.

Store: `{{STACK}}` and `{{PROJECT_NAME}}`

**Validate PROJECT_NAME:** Must match `^[a-zA-Z0-9_-]+$` (alphanumeric, hyphens, underscores only). Reject anything else with an error message.

## Step 2: Read Stack Template

Read the stack template file from `~/.claude/config/stacks/`. The filename matches `{{TEMPLATE}}` or the legacy stack keyword:

- `web-app.yaml` — legacy "web" keyword
- `api-service.yaml` — legacy "api" keyword or `api-service` template
- `mobile-app.yaml` — legacy "mobile" keyword
- `{template-name}.yaml` — for all templates resolved in Step 0 (e.g., `saas-complete.yaml`, `ai-rag-complete.yaml`, `web-t3.yaml`, etc.)

If the template YAML file does not exist at the expected path, fall back to the closest matching template from the legacy set (`web-app.yaml`, `api-service.yaml`, `mobile-app.yaml`) and inform the user which fallback was used.

The template defines: dependencies, directory structure, config files, and starter AGENTS.md content.

## Step 3: Scaffold Project

### Create project directory
```bash
mkdir -p {{PROJECT_NAME}}
cd {{PROJECT_NAME}}
```

### Initialize based on stack template

Follow the `init_commands` from the template YAML. These are the exact shell commands to run.

**Important:** Do NOT deviate from the template's dependency list. The constrained stack is the point — adding extra dependencies defeats the purpose.

### Create directory structure
Create all directories listed in the template's `directories` section.

### Create starter files
Create all files listed in the template's `starter_files` section with their content.

### Runtime Pinning
- **web/api stacks:** Create `.nvmrc` with the Node version used (e.g., `22`)
- **mobile stack:** Create `.nvmrc` with the Node version used
- If `mise` or `asdf` is detected on the system, also create `.tool-versions`

## Step 4: Project Configuration

### Create .vscode/ Settings

Create `.vscode/settings.json`, `.vscode/launch.json`, and `.vscode/extensions.json` — same as `/new-project` Step 4B, selected by stack:
- **web stack:** TypeScript settings + Tailwind + Vitest debugger + Prisma
- **api stack:** TypeScript settings + Vitest debugger
- **mobile stack:** TypeScript settings + React Native debugger (Expo)

This wires up the VS Code debugger, GitLens, test explorer, Mermaid preview, and Dev Containers extension to work with the project out of the box.

### Create .devcontainer

Create `.devcontainer/devcontainer.json` for reproducible, sandboxed development.

**web/api stacks (Node/TypeScript):**
```json
{
  "name": "{{PROJECT_NAME}}",
  "image": "mcr.microsoft.com/devcontainers/typescript-node:22",
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "postCreateCommand": "corepack enable && pnpm install --frozen-lockfile",
  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "eamodio.gitlens",
        "usernamehw.errorlens",
        "GitHub.vscode-pull-request-github",
        "github.vscode-github-actions",
        "bierner.markdown-mermaid",
        "vitest.explorer",
        "ms-playwright.playwright",
        "bradlc.vscode-tailwindcss",
        "prisma.prisma",
        "humao.rest-client",
        "wix.vscode-import-cost",
        "Gruntfuggly.todo-tree",
        "mtxr.sqltools",
        "mtxr.sqltools-driver-pg"
      ],
      "settings": {
        "editor.formatOnSave": true,
        "typescript.tsdk": "node_modules/typescript/lib",
        "errorLens.delay": 300,
        "terminal.integrated.shellIntegration.enabled": true
      }
    }
  },
  "forwardPorts": [3000],
  "mounts": []
}
```

**mobile stack (React Native/Expo):**
```json
{
  "name": "{{PROJECT_NAME}}",
  "image": "mcr.microsoft.com/devcontainers/typescript-node:22",
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "postCreateCommand": "corepack enable && pnpm install --frozen-lockfile",
  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "eamodio.gitlens",
        "usernamehw.errorlens",
        "bierner.markdown-mermaid"
      ]
    }
  },
  "forwardPorts": [8081, 19000, 19001]
}
```

**If the stack template includes Postgres/Redis dependencies**, add `docker-compose.yml`:
```yaml
services:
  app:
    build:
      context: .
      dockerfile: .devcontainer/Dockerfile
    volumes: ["./:/workspace:cached"]
    env_file: .env
    depends_on:
      db: { condition: service_healthy }
  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: ${DB_NAME:-app_dev}
      POSTGRES_USER: ${DB_USER:-postgres}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-postgres}
    ports: ["5432:5432"]
    volumes: ["pgdata:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
volumes:
  pgdata:
```

Also create `.devcontainer/.dockerignore`:
```
node_modules
.git
.env
dist
.next
__pycache__
```

### Configure Per-Project RAG

Create `.claude/mcp.json` in the project root:
```json
{
  "mcpServers": {
    "knowledge-rag": {
      "command": "npx",
      "args": ["-y", "knowledge-rag", "serve"],
      "env": {
        "KNOWLEDGE_RAG_DIR": "./docs",
        "KNOWLEDGE_RAG_EXTENSIONS": ".md,.mdx,.txt,.yaml,.yml"
      }
    }
  }
}
```

This indexes everything in `docs/` and makes it queryable via MCP tools during Claude sessions. If knowledge-rag is not installed, Claude Code gracefully skips it.

### Create CLAUDE.md
Use the template's `claude_md` section to generate a project-level CLAUDE.md with:
- Correct dev/test/build/lint/typecheck commands for this stack
- Architecture overview matching the template's directory structure
- Stack-specific conventions

### Create AGENTS.md
Use the template's `agents_md` section to create a starter AGENTS.md with:
- Stack identification
- Stack-specific known patterns (e.g., "Next.js App Router uses server components by default")
- Stack-specific gotchas (e.g., "Supabase client must be created per-request in server components")

### Create .gitignore
Use the template's `gitignore` section or generate one appropriate for the stack.

### Create .env.example
Use the template's `env_example` section. NEVER include real secrets.

## Step 5: Initialize tasks.json

Create a `tasks.json` with scaffold verification tasks:

```json
{
  "project": "{{PROJECT_NAME}}",
  "stack": "{{STACK}}",
  "tasks": [
    {
      "id": 1,
      "title": "Verify dev server starts",
      "status": "pending",
      "depends_on": [],
      "acceptance": ["dev server starts without errors", "page loads at localhost"],
      "files": [],
      "attempts": 0,
      "max_attempts": 3
    },
    {
      "id": 2,
      "title": "Verify test suite runs",
      "status": "pending",
      "depends_on": [1],
      "acceptance": ["test command exits 0", "at least 1 test passes"],
      "files": [],
      "attempts": 0,
      "max_attempts": 3
    },
    {
      "id": 3,
      "title": "Verify build succeeds",
      "status": "pending",
      "depends_on": [1],
      "acceptance": ["build command exits 0", "no TypeScript errors"],
      "files": [],
      "attempts": 0,
      "max_attempts": 3
    }
  ]
}
```

## Step 6: Git + GitHub

```bash
git init
# Verify .gitignore exists and covers sensitive files before staging
grep -q "\.env" .gitignore || echo -e ".env\n.env.*\n!.env.example" >> .gitignore
git add -A
git commit -m "feat: scaffold {{PROJECT_NAME}} with {{STACK}} stack

Generated with Claude Code /new-app command
Constrained stack: {{STACK_DESCRIPTION}}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

Then create GitHub repo (private by default):
```bash
gh repo create {{PROJECT_NAME}} --private --source . --push
```

## Step 7: Run CI Setup

Run `/ci-setup` to create the CI/CD pipeline:
- Creates `.github/workflows/ci.yml`
- Pins action versions
- Caches dependencies
- Adds CI badge to README

## Step 8: Summary

```
## New App Created: {{PROJECT_NAME}}

Stack: {{STACK_DESCRIPTION}}
Location: {{PATH}}

Files created:
  CLAUDE.md           — project AI guidance
  AGENTS.md           — learning memory (pre-seeded with stack patterns)
  tasks.json          — scaffold verification tasks
  .vscode/            — settings, debugger configs, recommended extensions
  .devcontainer/      — reproducible sandboxed dev environment
  .claude/mcp.json    — per-project RAG (knowledge-rag)
  .nvmrc              — runtime pinning
  .github/            — CI/CD pipeline
  .env.example        — environment template
  {{stack-specific files}}

Dev commands:
  Dev:       {{dev_command}}
  Test:      {{test_command}}
  Build:     {{build_command}}
  Lint:      {{lint_command}}

Next steps:
  1. Run /auto-build-all to verify scaffold tasks
  2. Run /init-tasks to add your feature tasks
  3. Run /auto-build-all to build the entire app
```

## Rules
- NEVER add dependencies not in the template — the constrained stack is intentional
- NEVER skip AGENTS.md creation — it's essential for the learning loop
- NEVER skip tasks.json — it enables /auto-build-all immediately
- ALWAYS create .env.example, NEVER .env with real values
- ALWAYS use the latest stable versions (check Context7 if unsure)
- ALWAYS set up CI/CD — every project ships with a pipeline
- If a template YAML is missing, fall back to the /new-project command's logic for that stack
- Use pnpm for Node projects, uv for Python projects
