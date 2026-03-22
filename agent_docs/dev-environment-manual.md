# Dev Environment Manual

A complete guide to your Claude Code + VS Code development workflow.

---

## Table of Contents

1. [First-Time Setup](#1-first-time-setup)
2. [Starting a New Project](#2-starting-a-new-project)
3. [The Daily Workflow: /plan → /build → /check → /ship](#3-the-daily-workflow)
4. [VS Code Integration Map](#4-vs-code-integration-map)
5. [RAG — Per-Project Knowledge Base](#5-rag--per-project-knowledge-base)
6. [Devcontainers — Sandboxed Development](#6-devcontainers--sandboxed-development)
7. [GitHub in VS Code — PRs, Issues, Actions](#7-github-in-vs-code)
8. [Debugging Workflow](#8-debugging-workflow)
9. [Testing Workflow](#9-testing-workflow)
10. [Building Custom Agent Tools](#10-building-custom-agent-tools)
11. [Session Lifecycle](#11-session-lifecycle)
12. [Quick Reference Card](#12-quick-reference-card)

---

## 1. First-Time Setup

### Prerequisites

Install these before using the system:

```bash
# Required
brew install node              # Node.js 22+
corepack enable                # Enables pnpm
brew install gh                # GitHub CLI
brew install --cask docker     # Docker Desktop

# Verify
node -v                        # Should be 22+
pnpm -v                        # Should be 9+
gh auth status                 # Should show "Logged in"
docker --version               # Should show 27+
```

### VS Code Setup

1. Install the **VS Code CLI**: Open VS Code → Command Palette → "Shell Command: Install 'code' command in PATH"
2. Install the core extension: `code --install-extension anthropic.claude-code`
3. VS Code will prompt to install remaining recommended extensions when you open any scaffolded project

### GitHub Authentication

Two separate auth steps — both are needed:

```bash
# 1. CLI auth (for /ship, /new-project, branch protection)
gh auth login

# 2. VS Code auth (for sidebar PRs, Issues, Actions)
# Click the GitHub icon in VS Code's Activity Bar → Sign In
```

### Session Start Checks

Every Claude Code session automatically runs `session-start.sh`, which verifies:

| Check | Level | What It Means |
|-------|-------|--------------|
| git in PATH | WARNING | Git operations will fail |
| node in PATH | WARNING | Can't run dev server or tests |
| pnpm available | NOTE | Install with `npm i -g pnpm` |
| uv available (if Python project) | WARNING | Install from astral.sh |
| docker available | NOTE | Devcontainer workflows unavailable |
| gh CLI + auth | WARNING | GitHub operations will fail |
| code CLI in PATH | NOTE | Can't auto-install extensions |
| .nvmrc version match | WARNING | Node major version mismatch |
| Disk space <1GB | WARNING | May run out during builds |
| Consolidation >7 days | NOTE | Run `/consolidate` |

If you see warnings, fix them before starting work.

---

## 2. Starting a New Project

You have three scaffold commands. Each produces a fully configured project with zero manual setup.

### Choosing the Right Command

```
Do you want a curated, locked stack (web/api/mobile)?
  YES → /new-app web myapp      (highest quality, YAML-driven)
  NO  → /new-project myapp next (flexible, any stack)

Are you building a custom Claude Agent SDK tool?
  YES → /new-agent-app my-tool ts
```

### What Gets Created

Every scaffold produces:

```
myapp/
├── .vscode/
│   ├── settings.json        ← format-on-save, Error Lens delay, TS SDK
│   ├── launch.json          ← F5 debugger configs (dev server, current test, attach)
│   ├── extensions.json      ← 16+ recommended extensions
│   └── tasks.json           ← Ctrl+Shift+B tasks (dev, test, check, build)
├── .devcontainer/
│   ├── devcontainer.json    ← Docker image, extensions, port forwarding
│   └── docker-compose.yml   ← Postgres + Redis (if detected)
├── .claude/
│   └── mcp.json             ← RAG config (indexes docs/)
├── .github/
│   └── workflows/ci.yml     ← Lint + typecheck + test + build
├── CLAUDE.md                ← AI guidance for this project
├── AGENTS.md                ← Learning memory (grows over sessions)
├── tasks.json               ← Scaffold verification tasks
├── .nvmrc                   ← Runtime pinning (Node 22)
├── .env.example             ← Placeholder env vars (never real secrets)
└── ... (stack-specific files)
```

### Post-Scaffold Checklist

After `/new-project` or `/new-app` completes:

1. **Open in VS Code**: `code myapp`
2. **Install extensions**: VS Code prompts automatically (click "Install All")
3. **Sign into GitHub**: Click the GitHub icon in the Activity Bar → Sign In
4. **Verify scaffold**: Run `/auto-build-all` to execute the 3 verification tasks
5. **Optional — Reopen in Container**: Command Palette → "Reopen in Container" for sandboxed dev

---

## 3. The Daily Workflow

### The One Command

```
/dev <feature>
```

This chains `/plan → /build → /check → /ship` with human gates between phases. Use it for most work.

### Or Run Each Phase Manually

```
/plan   → Research + plan the approach
/build  → Implement the code
/check  → Quality gate (code review + security + tests)
/ship   → Commit + push + create PR
/reflect → Capture learnings
```

For tiny changes (1-2 files): skip `/plan`, code directly → `/check` → `/ship`.

### Phase 1: /plan

**What it does:** Routes to the right planning depth based on scope.

| Scope | Route | Time | Output |
|-------|-------|------|--------|
| Code task (3-10 files) | Quick Plan | ~5 min | Implementation plan |
| New feature (unclear scope) | Feature Spec | ~15 min | Spec + plan + tasks |
| Major feature / new product | Full Pipeline | ~45 min | PRD + arch + spec + tasks |

**Research Gate:** Before routing, checks if any library/API needs Context7 verification. Research adds ~5 minutes but prevents 30+ minutes of wrong-API debugging.

**VS Code features active during /plan:**
- **RAG**: Automatically queries your `docs/` folder via MCP — no manual context pasting. If you wrote a PRD at `docs/auth/prd.md`, the planner finds it.
- **Mermaid diagrams**: Architecture/data flow diagrams render inline in VS Code. Use the preview pane (Cmd+Shift+V) to see them.
- **Plan review**: In the Claude Code VS Code extension, plans open as editable markdown. Annotate before `/build`.
- **Call Hierarchy**: Use `Shift+F12` on any function to verify dependency assumptions in the plan.

**Tips:**
- If you say "plan the architecture for..." → routes to Full Pipeline
- If you say "plan the changes for..." → routes to Quick Plan
- Drop design docs in `docs/` BEFORE running `/plan` — RAG indexes them automatically

### Phase 2: /build

**What it does:** Implements code based on the plan, routing by size.

| Size | Files | Approach |
|------|-------|----------|
| Tiny | 1-2 | Direct implementation |
| Small | 3-5 | Architect agent → implement |
| Medium | 6-15 | Task list → sequential |
| Large | 15+ | Task list → parallel worktrees (max 5 agents) |

**VS Code features active during /build:**
- **Error Lens**: TypeScript/ESLint errors appear inline on every line as code is written. Claude reads these via `mcp__ide__getDiagnostics` and fixes them in the same turn.
- **F5 Debugger**: If a test fails, open the test file → set breakpoint → F5. Pre-configured "Debug Current Test" in `launch.json`.
- **Ctrl+Shift+B**: Runs dev server via VS Code Tasks. For Inngest projects, compound task starts both Next.js + Inngest dev.
- **Import Cost**: Shows gzip size of every import inline. Catches heavy dependencies immediately.
- **REST Client**: Claude generates `.http` files in `requests/` for new API routes. Click "Send Request" to test.
- **Checkpoints**: Claude Code VS Code extension creates save points. Rewind if the build goes sideways — no `git stash` needed.
- **Timeline**: Bottom of File Explorer shows every save progression per file.

**Tips:**
- If `tasks.json` exists, `/build` follows it — don't improvise
- After `/build`, check Error Lens for remaining inline errors before moving to `/check`
- Use Timeline view to see how each file evolved during the build

### Phase 3: /check

**What it does:** Runs three quality agents in parallel, produces a unified PASS/FAIL report.

```
Agent 1: Code Quality (Opus)     — correctness, patterns, coverage
Agent 2: Security (Opus)         — OWASP top 10, secrets, dependencies
Agent 3: Test Verification       — pnpm test && lint && typecheck
```

**VS Code features active during /check:**
- **Error Lens + Problems Panel**: All findings appear inline. Press `Ctrl+Shift+M` for the full Problems list.
- **Playwright Test Explorer**: E2E failures show in the Testing sidebar. Click to re-run, right-click for trace viewer.
- **GitLens Branch Compare**: Visual diff of your branch vs main. Use to spot unintended changes.
- **Todo Tree**: New TODO/FIXME tags in your code appear in the sidebar. Reported as non-blocking warnings.

**Verdict:**
- **PASS** (no CRITICAL findings) → "Ready for PR. Run /ship."
- **FAIL** (CRITICAL findings or test failures) → list of what to fix

**Tips:**
- CRITICAL = must fix before merge
- WARNING = should fix, not blocking
- If you fix issues after `/check`, run `/check` again to verify

### Phase 4: /ship

**What it does:** Stages, commits, pushes, and creates a PR.

```
1. Check state (nothing on main, changes exist)
2. Stage + commit (conventional commits, no .env)
3. Push + create PR via gh
4. Report with PR URL
```

**VS Code features active after /ship:**
- **GitHub PRs sidebar**: Your PR appears under `Created By Me`. Add reviewers, respond to comments, merge — all without leaving VS Code.
- **GitHub Actions sidebar**: Watch CI run live. Re-run failed jobs with one click.
- **GitLens**: Final branch diff in Source Control sidebar for a sanity check.

**Tips:**
- If `/check` wasn't run, `/ship` warns you
- PR title is kept under 70 characters; details go in the body
- Check the Actions sidebar after shipping — CI should start within seconds

### Phase 5: /reflect

**What it does:** Extracts learnings from the session and saves them for future sessions.

Run at the end of every session. Captures corrections, successful patterns, and gotchas. Updates AGENTS.md with project-specific learnings.

---

## 4. VS Code Integration Map

### Extensions by Workflow Phase

```
ALWAYS ON (background)
├── anthropic.claude-code        → Claude Code in VS Code (inline diffs, checkpoints, plan review)
├── usernamehw.errorlens         → Inline errors on every line
├── eamodio.gitlens              → Inline blame, file history, branch compare
├── Gruntfuggly.todo-tree        → TODO/FIXME tree in sidebar
└── wix.vscode-import-cost       → Bundle size per import

PLANNING (/plan)
├── bierner.markdown-mermaid     → Render architecture diagrams inline
└── GitHub.vscode-pull-request-github → Reference GitHub issues

BUILDING (/build)
├── vitest.explorer              → Test tree in sidebar (unit tests)
├── ms-playwright.playwright     → E2E test tree + trace viewer
├── humao.rest-client            → Test API routes with .http files
├── bradlc.vscode-tailwindcss    → Tailwind class autocomplete
└── prisma.prisma                → Schema syntax + Studio

CHECKING (/check)
├── (Error Lens, Playwright, Todo Tree — already active)
└── GitLens branch compare

SHIPPING (/ship)
├── GitHub.vscode-pull-request-github → PRs in sidebar
└── github.vscode-github-actions     → CI runs in sidebar

DATABASE
├── mtxr.sqltools                → SQL query runner
└── mtxr.sqltools-driver-pg      → PostgreSQL driver

INFRASTRUCTURE
└── ms-vscode-remote.remote-containers → Devcontainer support
```

### Keyboard Shortcuts to Know

| Shortcut | What It Does | When to Use |
|----------|-------------|-------------|
| `F5` | Debug with launch.json | Failing test or dev server |
| `Ctrl+Shift+B` | Run default build task (dev server) | Start coding |
| `Ctrl+Shift+M` | Toggle Problems panel | After `/check` findings |
| `Shift+F12` | Peek Call Hierarchy | During `/plan` to trace dependencies |
| `Cmd+Shift+V` | Preview Markdown (Mermaid renders) | Reviewing plan diagrams |
| `Cmd+Up/Down` (terminal) | Jump between commands | Navigating Claude's output |

### Built-in VS Code Features (No Extension Needed)

| Feature | How to Access | Use Case |
|---------|--------------|----------|
| Timeline | File Explorer → TIMELINE (bottom) | See save-by-save history after `/build` |
| Call Hierarchy | Right-click → Peek Call Hierarchy | Verify dependencies during `/plan` |
| Outline | Explorer → OUTLINE | Navigate large service files |
| Port Forwarding | Remote Explorer → Ports | Manage forwarded ports in devcontainers |
| Terminal Shell Integration | Auto-enabled in settings | Pass/fail glyphs, sticky scroll |
| Profiles | File → Preferences → Profiles | Switch between fullstack/minimal configs |

---

## 5. RAG — Per-Project Knowledge Base

### How It Works

Every project gets `.claude/mcp.json` pointing to a `knowledge-rag` MCP server:

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

### What Gets Indexed

Everything in `docs/`:
- PRDs from `/bmad:prd`
- Architecture docs from `/bmad:architecture`
- Research briefs from the researcher agent
- Design docs from `/design-doc`
- Any `.md` file you drop in

Plus: CLAUDE.md and AGENTS.md.

### How to Use It

You don't call it directly — it works automatically:

1. **During `/plan`**: The researcher agent queries RAG alongside Context7. It finds relevant design decisions and requirements.
2. **During `/build`**: Claude searches RAG when it needs context about why something was designed a certain way.
3. **Ad hoc**: Ask Claude "what does the PRD say about authentication?" — it queries RAG.

### Adding More Context

```bash
# Just drop files into docs/
cp my-research-notes.md docs/
cp competitor-analysis.md docs/research/

# They're indexed on next Claude session start
```

### If knowledge-rag Isn't Installed

The MCP server won't start — Claude Code skips unavailable MCP servers gracefully. The workflow still works, just without semantic search over docs. To install:

```bash
npm install -g knowledge-rag
```

---

## 6. Devcontainers — Sandboxed Development

### What You Get

A Docker-based isolated development environment that mirrors production:

```
.devcontainer/
├── devcontainer.json      ← Docker image, VS Code extensions, ports
├── docker-compose.yml     ← App + Postgres + Redis (if detected)
└── .dockerignore          ← node_modules, .git, .env excluded
```

### When to Use Devcontainers

| Scenario | Use Devcontainer? |
|----------|-------------------|
| Running Claude with `--dangerously-skip-permissions` | Yes — container is the sandbox |
| Ensuring consistent env across machines | Yes |
| Quick prototyping on your local machine | No — overhead not worth it |
| CI/CD (GitHub Actions) | No — use the CI workflow instead |
| Team onboarding | Yes — one command to get started |

### How to Start

1. Open project in VS Code
2. Command Palette → "Dev Containers: Reopen in Container"
3. VS Code rebuilds in the container with all extensions pre-installed
4. Terminal is now inside the container — `pnpm dev` runs there

### Running Claude Safely in Containers

```bash
# Inside the container, this is safe:
claude --dangerously-skip-permissions

# The container IS the blast radius — Claude can't touch your host
```

### Docker Compose Services

If your project uses Postgres/Redis (detected from dependencies):

| Service | Port | Healthcheck |
|---------|------|-------------|
| app | 3000 | N/A |
| db (postgres:17-alpine) | 5432 | `pg_isready` every 5s |
| redis (redis:7-alpine) | 6379 | N/A |

Connect from your app: `DATABASE_URL=postgresql://postgres:postgres@db:5432/app_dev`

---

## 7. GitHub in VS Code — PRs, Issues, Actions

### Setup (One-Time)

1. Install: `code --install-extension GitHub.vscode-pull-request-github`
2. Install: `code --install-extension github.vscode-github-actions`
3. Click the GitHub icon in the Activity Bar → Sign In

### What You See in the Sidebar

```
GITHUB
├── Pull Requests
│   ├── Created By Me
│   │   └── feat: add rate limiting (#42) ✓ CI passed
│   ├── Waiting for Review
│   │   └── fix: handle null avatar (#38) ⏳ Review pending
│   └── All Open
├── Issues
│   ├── My Issues
│   └── Milestones
└── Actions (separate panel)
    ├── CI ✓ completed 2m ago
    ├── Deploy ✓ completed 1h ago
    └── Release ⏳ running...
```

### PR Workflow (Without Leaving VS Code)

```
/ship creates PR
    │
    ▼
PR appears in sidebar → add reviewers
    │
    ▼
Reviewer comments appear inline in editor
    │
    ▼
Fix issues → /check → /ship (amend or new commit)
    │
    ▼
CI passes (visible in Actions sidebar)
    │
    ▼
Merge from sidebar → done
```

### Actions Workflow

After `/ship` pushes, the CI workflow starts automatically. In the Actions sidebar:
- Green check = passed
- Red X = failed (click to see logs)
- Click "Re-run" to retry a failed job
- No browser needed — everything is in VS Code

---

## 8. Debugging Workflow

### Pre-Configured Debug Configs

Every scaffolded project includes `.vscode/launch.json` with:

| Config Name | What It Does | Shortcut |
|------------|-------------|----------|
| Debug Dev Server | Launches `pnpm dev` with debugger attached | F5 (default) |
| Debug Current Test | Runs the open test file with debugger | F5 (when test file is active) |
| Attach to Process | Connects to port 9229 | For running processes |

### Debugging a Failing Test

1. `/build` reports a test failure
2. Open the failing test file in VS Code
3. Set a breakpoint on the failing assertion (click left of line number)
4. Press F5 → select "Debug Current Test"
5. Step through the code: F10 (step over), F11 (step into), Shift+F11 (step out)
6. Inspect variables in the Variables panel
7. Fix the issue, remove breakpoints, continue

### Debugging an API Route

1. Start dev server: `Ctrl+Shift+B` (runs "dev" task)
2. Set breakpoint in the route handler
3. Use REST Client: open `requests/api/your-route.http` → click "Send Request"
4. Debugger pauses at the breakpoint
5. Inspect `req`, `res`, and service variables

### Using /debug Command

For systematic debugging without the VS Code debugger:
```
/debug "the donation webhook is processing duplicates"
```
This runs a structured debugging workflow: reproduce → isolate → identify → fix → verify.

---

## 9. Testing Workflow

### Unit Tests (Vitest)

```bash
pnpm test              # Run all tests
pnpm test -- file.test  # Run single file
```

**In VS Code:**
- Vitest Explorer sidebar shows all test files
- Click ▶ to run a single test
- Right-click → "Debug Test" to debug with breakpoints
- Green/red indicators show pass/fail inline

### E2E Tests (Playwright)

```bash
pnpm test:e2e          # Run all 12 project suites
pnpm test:e2e:m15      # Run milestone 15 suite
```

**In VS Code:**
- Playwright extension shows test tree in Testing sidebar
- Click to run individual flows
- Trace viewer shows step-by-step replay of failures
- Point-and-click locator generation for fixing selectors

### Test-Driven with Claude

The workflow enforces tests alongside implementation:

```
/build "add rate limiting to donation API"
    │
    ├── Claude writes the rate limiter service
    ├── Claude writes rate-limiter.service.test.ts alongside
    ├── Claude writes the route integration
    ├── Claude writes the E2E test
    └── Claude runs pnpm test to verify
```

### Coverage

Target: 80% for new code. Check with:
```bash
pnpm test -- --coverage
```

---

## 10. Building Custom Agent Tools

### When to Use CLI vs SDK

| Task | Use |
|------|-----|
| Daily dev work | Claude Code CLI (built-in tools, CLAUDE.md) |
| CI automation | `claude -p` with `--output-format json` |
| Custom multi-agent pipeline | Agent SDK |
| RAG-enhanced research tool | Agent SDK + custom MCP |
| IDE integration | Agent SDK with streaming |

### Quick Start

```bash
/new-agent-app my-research-bot ts
```

This creates a working project with:
- Orchestrator (`src/index.ts`) — runs `query()` with subagents
- Researcher subagent — reads codebases and docs
- Implementer subagent — writes code changes
- Custom MCP tool — semantic search placeholder
- Permission hooks — blocks writes to `.env`, logs tool usage

### Key Concepts

**`query()` is the core entry point:**
```typescript
for await (const msg of query({ prompt, agents, tools, hooks })) {
  // Streaming messages: text, tool_use, result
}
```

**Subagents are one level deep:**
```
Parent (orchestrates) → Researcher (reads) → returns findings
                      → Implementer (writes) → returns changes
// Subagents CANNOT spawn subagents
```

**Custom MCP tools extend capabilities:**
```typescript
@tool("semantic_search", { ... })
async function semanticSearch(query: string) {
  return await vectorDb.search(query);
}
```

**Full reference:** `~/.claude/agent_docs/claude-agent-sdk.md`

---

## 11. Session Lifecycle

### Start of Session

```
session-start.sh runs automatically
    │
    ├── Logs session start
    ├── Checks: git, node, pnpm, uv, docker, gh auth, code CLI
    ├── Checks: .nvmrc version match, disk space
    └── Checks: consolidation overdue?
```

### During Session

```
/plan → /build → /check → /ship → /reflect

At any point:
  /compact     — compress context at ~65% usage (not 90%)
  /clear       — reset between unrelated tasks
  /debug       — systematic debugging workflow
  /auto-build  — orchestrated pipeline for one task
```

### End of Session

```
/reflect
    │
    ├── Extracts corrections and successful patterns
    ├── Records learnings to the ledger
    └── Updates AGENTS.md with project-specific knowledge
```

### Two-Correction Rule

If Claude is corrected twice on the same issue, it stops and re-reads the full spec/requirements. A clean restart beats a polluted context.

### Weekly Maintenance

```
/consolidate
    │
    ├── Reviews all learnings from the week
    ├── Promotes high-confidence patterns
    └── Cleans up stale or contradictory learnings
```

---

## 12. Quick Reference Card

### Commands

| Command | Purpose | Time |
|---------|---------|------|
| `/dev <feature>` | Full pipeline with gates | Varies |
| `/plan <task>` | Plan the approach | 5-45 min |
| `/build <task>` | Implement code | Varies |
| `/check` | Quality gate | ~5 min |
| `/ship` | Commit + PR | ~2 min |
| `/reflect` | Capture learnings | ~1 min |
| `/new-project <name> <stack>` | Scaffold any project | ~5 min |
| `/new-app <stack> <name>` | Scaffold curated app | ~5 min |
| `/new-agent-app <name> <variant>` | Scaffold Agent SDK project | ~3 min |
| `/auto-build` | Orchestrated single task | ~15 min |
| `/auto-build-all` | All pending tasks | Varies |
| `/debug <issue>` | Systematic debugging | ~10 min |

### File Layout

```
~/.claude/
├── CLAUDE.md                          ← Global rules (loaded every session)
├── commands/
│   ├── plan.md, build.md, check.md, ship.md  ← Core workflow
│   ├── new-project.md, new-app.md    ← Scaffold commands
│   └── new-agent-app.md              ← Agent SDK scaffold
├── hooks/
│   └── session-start.sh              ← Environment health checks
├── agent_docs/
│   ├── architecture.md               ← Backend/frontend patterns
│   ├── ci-standards.md               ← CI/CD rules
│   ├── testing.md                    ← Test strategy
│   ├── security.md                   ← Security standards
│   └── claude-agent-sdk.md           ← Agent SDK reference
└── config/
    └── stacks/                        ← YAML templates for /new-app
```

### Per-Project Files

```
your-project/
├── .vscode/settings.json             ← Editor config
├── .vscode/launch.json               ← F5 debugger
├── .vscode/extensions.json            ← Recommended extensions
├── .vscode/tasks.json                 ← Ctrl+Shift+B tasks
├── .devcontainer/devcontainer.json    ← Docker sandbox
├── .claude/mcp.json                   ← RAG config
├── CLAUDE.md                          ← Project-specific guidance
├── AGENTS.md                          ← Learning memory
├── tasks.json                         ← Task tracking
└── docs/                              ← RAG-indexed knowledge base
```

### VS Code Sidebar Panels

```
Explorer          ← Files + Timeline (bottom)
Search            ← Full-text search
Source Control    ← Git changes + GitLens
Run and Debug     ← F5 configs
Testing           ← Vitest + Playwright trees
GitHub            ← PRs + Issues
GitHub Actions    ← CI/CD workflow runs
Todo Tree         ← TODO/FIXME across codebase
Docker            ← Container management
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Claude API access |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Model for subagents (default: Sonnet) |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Enable agent teams |

### Verification After Setup

```bash
# Check everything is working
gh auth status               # GitHub CLI authenticated
code --version               # VS Code CLI available
docker --version             # Docker available
node -v                      # Node 22+
pnpm -v                      # pnpm 9+
claude --version             # Claude Code installed
```
