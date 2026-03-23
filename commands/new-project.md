Scaffold a new project with full automation: $ARGUMENTS

This command runs the COMPLETE project setup pipeline in one shot:
**Scaffold → Init (CLAUDE.md) → CI/CD → BMAD Init → GitHub Repo → Branch Protection → Reflect → First Commit**

## Step 1: Parse Arguments

Extract from the arguments:
- **Project name** (required)
- **Stack** (e.g., "next", "vite-react", "express", "fastapi", "python") — ask if unclear
- **Description** (optional)

## Step 2: Create Project Directory

```bash
mkdir -p <project-name>
cd <project-name>
```

## Step 3: Initialize Based on Stack

### Next.js (TypeScript)
```bash
pnpm create next-app . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
```

### Vite + React (TypeScript)
```bash
pnpm create vite . --template react-ts
pnpm install
pnpm add -D tailwindcss @tailwindcss/vite
```

### Express API (TypeScript)
```bash
pnpm init
pnpm add express cors helmet dotenv
pnpm add -D typescript @types/express @types/node @types/cors tsx vitest
```
Create: tsconfig.json, src/index.ts, src/routes/, src/services/, src/middleware/

### FastAPI (Python)
```bash
uv init
uv add fastapi uvicorn pydantic python-dotenv
uv add --dev pytest ruff mypy httpx
```
Create: src/main.py, src/routes/, src/services/, src/models/

## Step 4: Common Setup (All Stacks)

### Git
```bash
git init
```
Create `.gitignore` appropriate for the stack.

### README.md
Create a minimal README with:
- Project name
- One-line description
- Quick start instructions

### Environment
Create `.env.example` with placeholder values (never actual secrets).

### Runtime Pinning
- Node projects: create `.nvmrc` with the Node version used (e.g., `22`)
- Python projects: create `.python-version` with the Python version used (e.g., `3.12`)
- Both: create `.tool-versions` if `mise` or `asdf` is detected on the system (`command -v mise` or `command -v asdf`)

## Step 4B: AUTO — Create .vscode/ Settings (All Projects)

Create `.vscode/settings.json` with stack-appropriate settings that wire up VS Code extensions:

### All projects:
```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "files.exclude": {
    "node_modules": true,
    ".next": true,
    "dist": true,
    "__pycache__": true
  },
  "search.exclude": {
    "node_modules": true,
    "dist": true,
    ".next": true,
    "pnpm-lock.yaml": true
  },
  "terminal.integrated.shellIntegration.enabled": true,
  "terminal.integrated.stickyScroll.enabled": true,
  "errorLens.delay": 300
}
```

### Node/TypeScript projects — add:
```json
{
  "typescript.tsdk": "node_modules/typescript/lib",
  "typescript.enablePromptUseWorkspaceTsdk": true,
  "[typescript]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[typescriptreact]": { "editor.defaultFormatter": "esbenp.prettier-vscode" }
}
```

### Python projects — add:
```json
{
  "python.defaultInterpreterPath": ".venv/bin/python",
  "[python]": { "editor.defaultFormatter": "charliermarsh.ruff" },
  "python.testing.pytestEnabled": true,
  "python.testing.pytestArgs": ["--tb=short"]
}
```

### Create `.vscode/launch.json` (debugger configurations):

**Node/TypeScript:**
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Dev Server",
      "type": "node",
      "request": "launch",
      "runtimeExecutable": "pnpm",
      "runtimeArgs": ["dev"],
      "console": "integratedTerminal",
      "skipFiles": ["<node_internals>/**", "node_modules/**"]
    },
    {
      "name": "Debug Current Test",
      "type": "node",
      "request": "launch",
      "runtimeExecutable": "pnpm",
      "runtimeArgs": ["test", "--", "--run", "${relativeFile}"],
      "console": "integratedTerminal",
      "skipFiles": ["<node_internals>/**"]
    },
    {
      "name": "Attach to Process",
      "type": "node",
      "request": "attach",
      "port": 9229,
      "skipFiles": ["<node_internals>/**"]
    }
  ]
}
```

**Python (FastAPI):**
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug FastAPI",
      "type": "debugpy",
      "request": "launch",
      "module": "uvicorn",
      "args": ["src.main:app", "--reload", "--port", "8000"],
      "console": "integratedTerminal"
    },
    {
      "name": "Debug Current Test",
      "type": "debugpy",
      "request": "launch",
      "module": "pytest",
      "args": ["${relativeFile}", "-v", "--tb=short"],
      "console": "integratedTerminal"
    }
  ]
}
```

### Create `.vscode/extensions.json` (recommended extensions):

**Node/TypeScript:**
```json
{
  "recommendations": [
    "anthropic.claude-code",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "eamodio.gitlens",
    "usernamehw.errorlens",
    "ms-vscode-remote.remote-containers",
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
  ]
}
```

**Python:**
```json
{
  "recommendations": [
    "anthropic.claude-code",
    "charliermarsh.ruff",
    "ms-python.python",
    "ms-python.debugpy",
    "eamodio.gitlens",
    "usernamehw.errorlens",
    "ms-vscode-remote.remote-containers",
    "GitHub.vscode-pull-request-github",
    "github.vscode-github-actions",
    "bierner.markdown-mermaid",
    "humao.rest-client",
    "Gruntfuggly.todo-tree"
  ]
}
```

### Create `.vscode/tasks.json` (VS Code task runner):

**Node/TypeScript:**
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "dev",
      "type": "shell",
      "command": "pnpm dev",
      "group": { "kind": "build", "isDefault": true },
      "presentation": { "panel": "dedicated", "reveal": "always" },
      "problemMatcher": []
    },
    {
      "label": "test",
      "type": "shell",
      "command": "pnpm test",
      "group": "test",
      "presentation": { "panel": "dedicated" }
    },
    {
      "label": "check (lint + typecheck + test)",
      "type": "shell",
      "command": "pnpm test && pnpm lint && pnpm typecheck",
      "group": "test",
      "presentation": { "panel": "dedicated" },
      "problemMatcher": "$tsc"
    },
    {
      "label": "build",
      "type": "shell",
      "command": "pnpm build",
      "group": "build",
      "problemMatcher": "$tsc"
    }
  ]
}
```

**Python:**
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "dev",
      "type": "shell",
      "command": "uv run uvicorn src.main:app --reload",
      "group": { "kind": "build", "isDefault": true },
      "presentation": { "panel": "dedicated", "reveal": "always" }
    },
    {
      "label": "test",
      "type": "shell",
      "command": "uv run pytest",
      "group": "test"
    },
    {
      "label": "check (lint + typecheck + test)",
      "type": "shell",
      "command": "uv run pytest && uv run ruff check . && uv run mypy .",
      "group": "test"
    }
  ]
}
```

If the project uses **Inngest** (detected from dependencies), add a compound task:
```json
{
  "label": "dev:full (app + inngest)",
  "dependsOn": ["dev", "inngest:dev"],
  "dependsOrder": "parallel"
},
{
  "label": "inngest:dev",
  "type": "shell",
  "command": "pnpm dlx inngest-cli@latest dev",
  "presentation": { "panel": "dedicated" }
}
```

### Create `requests/` directory for API testing (Node/TypeScript API projects):

Create `requests/example.http` as a starter:
```http
### Health Check
GET http://localhost:3000/api/health

### Example POST
POST http://localhost:3000/api/example
Content-Type: application/json

{
  "key": "value"
}
```

These `.http` files work with the REST Client extension and serve as living API documentation.

## Step 4C: AUTO — Create .cursor/ Settings (All Projects)

If the Cursor template exists at `~/.claude/config/cursor-template/`, scaffold `.cursor/` alongside `.vscode/`:

1. Create `.cursor/mcp.json` — Copy from the cursor template. If a project `.mcp.json` exists, convert it (replace `$HOME` with `${userHome}`).

2. Create `.cursor/rules/` — Copy all `.mdc` files from the cursor template directory:
   - `design-system.mdc` (UI projects only)
   - `backend-architecture.mdc`
   - `docker.mdc`
   - `git-workflow.mdc`
   - `consistency.mdc`
   - `typescript.mdc` (TS projects) or `python.mdc` (Python projects)
   - `security.mdc`
   - `testing.mdc`
   - `api.mdc`

3. If `CLAUDE.md` exists, generate `.cursor/rules/project-conventions.mdc` from it with `alwaysApply: true`.

This ensures Cursor IDE users get the same rules and MCP access as VS Code + Claude Code users.

## Step 5: Design System (Frontend Projects Only)

If this is a frontend project:
1. Create `reference-designs/` directory
2. Add a note to check the global design-system skill
3. Set up Tailwind CSS config with the global color palette tokens

## Step 5B: AUTO — Create .devcontainer (All Projects)

Create `.devcontainer/devcontainer.json` for reproducible, sandboxed development:

### Node/TypeScript projects:
```json
{
  "name": "${project-name}",
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

### Python projects:
```json
{
  "name": "${project-name}",
  "image": "mcr.microsoft.com/devcontainers/python:3.12",
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "postCreateCommand": "pip install uv && uv sync",
  "forwardPorts": [8000]
}
```

### If project uses Postgres/Redis (detected from dependencies):
Add `docker-compose.yml` alongside:
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

Update `devcontainer.json` to reference the compose file:
```json
{ "dockerComposeFile": "docker-compose.yml", "service": "app", "workspaceFolder": "/workspace" }
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

## Step 6: AUTO — Project CLAUDE.md (/init)

Analyze the scaffolded codebase and create a project-level `CLAUDE.md`:

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project
- Name: <project-name>
- Stack: <stack>
- Description: <description>

## Commands
- Dev: `pnpm dev` / `uv run uvicorn src.main:app --reload`
- Test: `pnpm test` / `uv run pytest`
- Build: `pnpm build` / N/A
- Lint: `pnpm lint` / `uv run ruff check .`
- Typecheck: `pnpm typecheck` / `uv run mypy .`
- Single test: `pnpm test -- <file>` / `uv run pytest <file> -v`

## Architecture
<Document the structure based on the stack — routes, services, components, etc.>

## Knowledge Base
Per-project RAG is configured via `.claude/mcp.json`. Drop design docs into `docs/` to make them queryable.
MCP tools: `mcp__knowledge-rag__search`, `mcp__knowledge-rag__index`

## Skills
- Design system: ~/.claude/skills/design-system/SKILL.md (frontend)
- Backend architecture: ~/.claude/skills/backend-architecture/SKILL.md (backend)
- Docker: ~/.claude/skills/docker/SKILL.md
```

Tailor the CLAUDE.md to the actual scaffolded structure — don't use generic placeholders.

## Step 6B: AUTO — Create AGENTS.md (/init-agents-md)

Create a project-level `AGENTS.md` for stack-specific learnings:

```markdown
# AGENTS.md — Project Learning Memory

## Stack
- Framework: {detected framework}
- Language: {TypeScript/Python}
- Package manager: {pnpm/uv}

## Patterns Discovered
{Empty — Claude populates this as it learns during sessions}

## Gotchas
{Empty — populated by the Stop hook when non-trivial errors are resolved}

## Key Files
{List the 5-10 most important files in the scaffold}
```

This enables the Stop hook's AGENTS.md update loop from session one.

## Step 6C: AUTO — Create tasks.json

Create scaffold verification tasks:

```json
{
  "project": "<project-name>",
  "stack": "<stack>",
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

This enables `/auto-build-all` immediately after scaffold.

## Step 6D: AUTO — Configure Per-Project RAG (knowledge-rag MCP)

Create `.claude/mcp.json` in the project root to enable per-project knowledge retrieval:

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

This indexes everything in the `docs/` directory (design docs, specs, PRDs, architecture docs, research briefs) and makes it queryable via MCP tools during Claude sessions.

**What gets indexed automatically:**
- docs/{feature}/prd.md (from /bmad:prd)
- docs/{feature}/architecture.md (from /bmad:architecture)
- docs/{feature}/research.md (from researcher agent)
- CLAUDE.md, AGENTS.md

**The user can add more docs at any time** — just drop .md files into docs/ and they're indexed on next session start.

**Fallback:** If knowledge-rag is not installed globally, the MCP server won't start — Claude Code handles this gracefully by skipping unavailable MCP servers. No harm done.

## Step 7: AUTO — CI/CD Pipeline (/ci-setup)

Run the full CI/CD setup pipeline:

1. Detect the project stack from package.json / pyproject.toml
2. Create `.github/workflows/ci.yml` — lint, typecheck, test, build
3. Create `.github/workflows/deploy.yml` — deployment workflow
4. Create `.github/workflows/release.yml` — tag-based releases
5. Create `.github/dependabot.yml` — auto dependency updates
6. Create `.github/pull_request_template.md` — PR template
7. Add CI badge to README.md

Follow all rules from the ci-setup command:
- Pin action versions (actions/checkout@v4)
- Set concurrency groups
- Cache dependencies
- Use ${{ secrets.* }} for sensitive values

## Step 8: AUTO — Initialize BMAD (/bmad:workflow-init)

Initialize the BMAD Method in the project so all `/bmad:*` commands are project-aware:

1. Create `docs/bmad/` directory for BMAD artifacts
2. Create `docs/bmad/.bmad-status.json` to track workflow state:
```json
{
  "project": "<project-name>",
  "initialized": true,
  "phase": "setup",
  "completedSteps": ["scaffold", "ci-setup"],
  "createdAt": "<ISO timestamp>"
}
```
3. Add a note in CLAUDE.md under Architecture referencing BMAD docs location

This enables the full BMAD lifecycle: `/bmad:product-brief` → `/bmad:prd` → `/bmad:architecture` → `/bmad:sprint-planning` → `/bmad:dev-story`

## Step 9: AUTO — Create GitHub Repo & Push

### Pre-check: GitHub Authentication
Before creating the repo, verify `gh` is authenticated:
```bash
gh auth status
```
If not authenticated, prompt the user to run `gh auth login` and wait. Do NOT skip this step — Steps 9, 10, and the GitHub Actions/PR extensions all depend on it.

### Create repo and push:

```bash
gh repo create <project-name> --private --source . --push
```

- Default to **private** — the user can change visibility later
- Uses the `gh` CLI (already authenticated via PAT)
- Sets up remote tracking automatically with `--push`

## Step 10: AUTO — Set Branch Protection

After pushing, configure basic branch protection on `main`:

```bash
gh api repos/{owner}/{repo}/branches/main/protection -X PUT \
  -H "Accept: application/vnd.github+json" \
  --input - <<'EOF'
{
  "required_status_checks": { "strict": true, "contexts": ["CI"] },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null
}
EOF
```

This enforces CI must pass before merging to `main`.

## Step 11: AUTO — Enable Reflect

Enable the reflect skill for automatic learning:

```bash
# Enable auto-reflection on session end
bash ~/.claude/skills/reflect/scripts/toggle-on.sh
```

This makes Claude learn from corrections in every session for this project.

## Step 12: First Commit

```bash
git add -A
git commit -m "feat: initial project scaffold with CI/CD

Stack: <stack>
Includes: project structure, CLAUDE.md, AGENTS.md, tasks.json, .devcontainer, CI/CD pipeline, BMAD init, RAG config, reflect enabled
Generated with Claude Code /new-project command

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

## Step 13: AUTO — Post-Scaffold Verification

Run automated checks to confirm everything is wired up correctly:

```bash
# 1. Verify scaffold structure exists
echo "Checking scaffold..."
test -f CLAUDE.md && echo "  CLAUDE.md" || echo "  MISSING: CLAUDE.md"
test -f AGENTS.md && echo "  AGENTS.md" || echo "  MISSING: AGENTS.md"
test -f tasks.json && echo "  tasks.json" || echo "  MISSING: tasks.json"
test -f .vscode/settings.json && echo "  .vscode/settings.json" || echo "  MISSING: .vscode/settings.json"
test -f .vscode/launch.json && echo "  .vscode/launch.json" || echo "  MISSING: .vscode/launch.json"
test -f .vscode/extensions.json && echo "  .vscode/extensions.json" || echo "  MISSING: .vscode/extensions.json"
test -f .vscode/tasks.json && echo "  .vscode/tasks.json" || echo "  MISSING: .vscode/tasks.json"
test -d .cursor/rules && echo "  .cursor/rules/ ($(ls .cursor/rules/*.mdc 2>/dev/null | wc -l | tr -d ' ') rules)" || echo "  MISSING: .cursor/rules/"
test -f .cursor/mcp.json && echo "  .cursor/mcp.json" || echo "  MISSING: .cursor/mcp.json"
test -f .devcontainer/devcontainer.json && echo "  .devcontainer/" || echo "  MISSING: .devcontainer/"
test -f .claude/mcp.json && echo "  .claude/mcp.json" || echo "  MISSING: .claude/mcp.json"
test -f .github/workflows/ci.yml && echo "  .github/workflows/ci.yml" || echo "  MISSING: CI workflow"

# 2. Verify GitHub auth and repo
echo "Checking GitHub..."
gh auth status 2>&1 | head -1
gh repo view --json name -q '.name' 2>/dev/null && echo "  Repo linked" || echo "  WARNING: Repo not linked"

# 3. Verify runtime pinning
echo "Checking runtime..."
test -f .nvmrc && echo "  .nvmrc: $(cat .nvmrc)" || test -f .python-version && echo "  .python-version: $(cat .python-version)" || echo "  WARNING: No runtime pin file"

# 4. Check VS Code extensions availability
echo "Checking VS Code..."
command -v code &>/dev/null && echo "  VS Code CLI available" || echo "  NOTE: 'code' CLI not found — open VS Code and run 'Install code command in PATH'"
```

If any checks fail, report them in the summary and suggest fixes.

### Install recommended extensions automatically:
If the `code` CLI is available, offer to install all recommended extensions:
```bash
code --install-extension anthropic.claude-code --force
code --install-extension usernamehw.errorlens --force
code --install-extension GitHub.vscode-pull-request-github --force
code --install-extension github.vscode-github-actions --force
code --install-extension eamodio.gitlens --force
code --install-extension ms-vscode-remote.remote-containers --force
code --install-extension bierner.markdown-mermaid --force
# ... plus stack-specific extensions from extensions.json
```

Ask the user: **"Install all recommended VS Code extensions now? (y/n)"** — respect the choice.

### Prompt to sign into GitHub in VS Code:
After extensions install, tell the user:
```
To see GitHub PRs, Issues, and Workflow runs in VS Code sidebar:
  1. Click the GitHub icon in the Activity Bar (left sidebar)
  2. Sign in when prompted — this authorizes the GitHub extensions
  3. You'll see: PRs, Issues, and Actions workflow runs in the sidebar tree
```

## Step 14: Summary

Print a clear summary:

```
Project Setup Complete!

  Location:    /path/to/<project-name>
  Stack:       <stack>

  Commands:
    Dev:       pnpm dev           (or Ctrl+Shift+B in VS Code)
    Test:      pnpm test          (or Terminal > Run Task > test)
    Check:     pnpm test && lint  (or Terminal > Run Task > check)
    Build:     pnpm build
    Debug:     F5 in VS Code      (launch.json pre-configured)

  Auto-configured:
    CLAUDE.md          — project-level AI guidance
    AGENTS.md          — stack-aware learning memory
    tasks.json         — scaffold verification tasks
    .vscode/           — settings, debugger, tasks, recommended extensions
    .cursor/           — Cursor IDE rules (.mdc) and MCP config
    .devcontainer/     — reproducible sandboxed dev environment
    .claude/mcp.json   — per-project RAG (knowledge-rag)
    .nvmrc/.python-version — runtime pinning
    CI/CD              — GitHub Actions (ci + deploy + release)
    BMAD               — workflow initialized, ready for /bmad:* commands
    GitHub Repo        — private repo created and pushed
    Branch Protection  — CI required on main
    Reflect            — auto-learning enabled
    .gitignore         — stack-appropriate
    .env.example       — placeholder environment vars

  VS Code sidebar (after signing in):
    GitHub PRs         — create, review, merge PRs from sidebar
    GitHub Actions     — see CI/CD workflow runs live
    GitLens            — inline blame, file history, branch compare
    Testing            — Vitest + Playwright test trees
    Todo Tree          — TODOs/FIXMEs across codebase
    Error Lens         — inline TypeScript/ESLint errors
    Dev Containers     — "Reopen in Container" for sandboxed dev

  Next steps:
    1. Open project in VS Code: code <project-name>
    2. Install recommended extensions (VS Code will prompt)
    3. Sign into GitHub in VS Code sidebar
    4. Run /auto-build-all to verify scaffold tasks
    5. Run /bmad:product-brief to start the product lifecycle
    6. Start coding!
```

## Rules
- NEVER include real secrets in any generated file
- ALWAYS use the latest stable versions of dependencies
- ALWAYS include TypeScript for JS projects (never plain JS)
- ALWAYS set up linting and formatting from the start
- Use pnpm for Node projects, uv for Python projects
- ALWAYS run all auto-steps (init, ci-setup, bmad-init, github-repo, branch-protection, reflect) — never skip them
- If the user's stack matches a /new-app template (web, api, mobile), suggest /new-app instead — it produces higher-quality output with pre-seeded AGENTS.md and YAML-driven scaffolding
- The goal is: ONE command → fully production-ready project
