# How to Use claude-super-setup

Complete guide to installing, running, and getting the most out of this setup.

---

## 1. Installation

### Method A: Quick Install (Recommended)

```bash
# Clone the repo
git clone https://github.com/calebtala-zm/claude-super-setup.git ~/.claude-super-setup

# Run the installer (creates symlinks — git pull updates instantly)
~/.claude-super-setup/install.sh
```

That's it. Open a new Claude Code session and everything is active.

### Method B: Container Install (Sandboxed)

For safe autonomous operation or team onboarding:

```bash
git clone https://github.com/calebtala-zm/claude-super-setup.git
cd claude-super-setup
```

Then in VS Code: **Command Palette → "Dev Containers: Reopen in Container"**

The container installs everything automatically. Inside the container, you can safely run:
```bash
claude --dangerously-skip-permissions
```
The container IS the blast radius — Claude can't touch your host.

### Method C: Selective Install

Only install what you need:

```bash
~/.claude-super-setup/install.sh --modules=commands,agents,hooks
```

Available modules: `commands`, `agents`, `hooks`, `rules`, `skills`, `agent_docs`, `config`

### Method D: Copy Mode (No Symlinks)

If symlinks cause issues on your system:

```bash
~/.claude-super-setup/install.sh --mode=copy
```

Note: With copy mode, you must re-run the installer after `git pull` to get updates.

### Preview Before Installing

```bash
~/.claude-super-setup/install.sh --dry-run
```

Shows exactly what would change without touching anything.

---

## 2. First Run Checklist

After installing, verify everything works:

```bash
# 1. Check Claude Code is installed
claude --version

# 2. Start a Claude Code session — hooks should fire
claude
# You should see session-start.sh output with health checks

# 3. Test a command
/plan "hello world test"
# Should route to Quick Plan and produce a plan

# 4. Check your config
cat ~/.claude/settings.json | jq '.env'
# Should show AUTOCOMPACT, SUBAGENT_MODEL, AGENT_TEAMS
```

### Customize Your Setup

Edit `~/.claude/settings.local.json` for personal overrides:

```json
{
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-4-6"
  },
  "permissions": {
    "allow": ["Bash(your-custom-tool *)"]
  }
}
```

This file is gitignored — your personal settings won't leak to the repo.

---

## 3. Daily Workflow

### Three Autonomy Levels

| Level | Command | Human Gates | Best For |
|-------|---------|-------------|----------|
| Manual | `/plan → /build → /check → /ship` | Every phase | Learning, complex decisions |
| Semi-auto | `/dev <feature>` | Between phases | Daily development |
| Autonomous | `/auto-dev <feature>` | Plan + task approval only | Well-understood features |

### Manual Flow (Maximum Control)

```bash
# 1. Plan the approach
/plan add user authentication

# 2. Implement the plan
/build

# 3. Quality gate (code review + security + tests)
/check

# 4. Commit and create PR
/ship

# 5. Capture learnings
/reflect
```

### Semi-Auto Flow (Recommended for Daily Work)

```bash
/dev add rate limiting to the API
```

This chains `/plan → /build → /check → /ship` with human gates between phases. You review each phase output before continuing.

### Fully Autonomous Flow

```bash
/auto-dev add rate limiting to the API
```

Two human gates only: approve the plan, approve the task list. Everything else (build, test, review, commit, PR) runs autonomously.

### Overnight Autonomous (Ghost Mode)

```bash
/ghost --trust=high --hours=8 --budget=50
```

Runs in a screen session with:
- macOS sleep prevention (caffeinate)
- Crash recovery with exponential backoff
- Push notifications via ntfy.sh
- Emergency stop: `touch ~/.claude/ghost-stop`

Check progress:
```bash
/ghost-status
```

---

## 4. Creating Projects

### From Templates (16 Available)

```bash
/new-app <stack> <project-name>
```

| Stack | Template | What You Get |
|-------|----------|-------------|
| `web` | Next.js 15 + Supabase | Full-stack web app |
| `astro` | Astro 5 + Cloudflare | Content site / blog |
| `t3` | Next.js + tRPC + Prisma | Type-safe full-stack |
| `sveltekit` | SvelteKit 2 + Lucia | Performance-first web |
| `remix` | Remix + Cloudflare Workers | Edge-first web |
| `api` | Hono + Drizzle + PostgreSQL | REST API service |
| `fastapi` | FastAPI + SQLAlchemy | Python API service |
| `hono-edge` | Hono + Cloudflare + D1 | Edge API (no cold start) |
| `mobile` | Expo + TypeScript + Supabase | React Native mobile |
| `nativewind` | Expo + NativeWind (Tailwind) | Tailwind-styled mobile |
| `flutter` | Flutter 3 + Supabase + Riverpod | Dart mobile app |
| `revenucat` | Expo + RevenueCat | Mobile with subscriptions |
| `saas` | Next.js + Stripe + Supabase Auth | SaaS with billing |
| `ai` | Next.js + AI SDK + pgvector | AI app with RAG |
| `chrome-ext` | TypeScript + Vite + Chrome MV3 | Browser extension |
| `cli` | TypeScript + Commander.js + tsup | CLI tool for npm |

Every template includes:
- Working starter code (not boilerplate)
- CLAUDE.md with project-specific conventions
- AGENTS.md with real gotchas
- Test setup with smoke test
- CI workflow
- Environment validation (Zod/Pydantic)

### Flexible Scaffold

```bash
/new-project myapp next    # Any stack, flexible options
```

### Claude Agent SDK Project

```bash
/new-agent-app my-tool ts  # Custom agentic tool
```

---

## 5. Agent Teams

Pre-configured teams for common workflows:

```bash
# Code review sprint
/team-build --team=review

# Frontend development
/team-build --team=frontend

# Full-stack feature
/team-build --team=fullstack

# Security audit
/team-build --team=security
```

| Team | Agents | Use Case |
|------|--------|----------|
| review | code-reviewer, security-auditor, silent-failure-hunter | Quality gate |
| frontend | frontend-dev, ui-designer, tdd-test-writer, whimsy-injector | UI sprint |
| backend | backend-dev, architect, security-auditor | API development |
| fullstack | architect, backend-dev, frontend-dev, test-writer-fixer | Full feature |
| mobile | mobile-app-builder, ui-designer, test-writer-fixer | Mobile dev |
| research | researcher, trend-researcher, feedback-synthesizer | Research |
| security | security-auditor, code-reviewer, silent-failure-hunter | Security audit |

---

## 6. RAG — Knowledge Base

The setup includes a `knowledge-rag` MCP server that indexes:
- `docs/` — research briefs, design docs, brainstorms
- `agent_docs/` — architecture standards, testing, security, CI standards

This means Claude can search the setup's own documentation during any session. When you run `/plan`, the planner automatically queries RAG for relevant context.

### Adding More Knowledge

Drop any `.md`, `.txt`, or `.yaml` file into `docs/` or `agent_docs/`:

```bash
cp my-research-notes.md ~/.claude-super-setup/docs/
```

They're indexed automatically on the next Claude session start.

### Per-Project RAG

When you create a project with `/new-app` or `/new-project`, it generates a `.claude/mcp.json` that indexes the project's own `docs/` directory. Drop PRDs, design docs, or API specs there.

---

## 7. Customization

### Personal Settings (settings.local.json)

Override any shared setting without touching the repo:

```json
{
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "claude-opus-4-6",
    "CUSTOM_API_KEY": "sk-..."
  },
  "permissions": {
    "allow": ["Bash(terraform *)"]
  }
}
```

### Personal CLAUDE.md

Add personal identity and preferences. Create or edit `~/.claude/CLAUDE.md.personal`:

```markdown
## Identity
I'm a senior backend engineer working primarily in Go and Python.
I prefer minimal abstractions and explicit error handling.

## Personal Preferences
- Always use table-driven tests in Go
- Use dataclasses over Pydantic for internal models
```

### Adding Project-Specific Agents

Create agents in your project's `.claude/agents/` directory. They override global agents with the same name.

---

## 8. Updating

### With Symlink Mode (Default)

```bash
cd ~/.claude-super-setup && git pull
```

Done. Symlinks mean the live config updates instantly.

### With Copy Mode

```bash
cd ~/.claude-super-setup && git pull
~/.claude-super-setup/install.sh --mode=copy
```

### Check for Drift

```bash
bash ~/.claude-super-setup/scripts/drift-detect.sh
```

Reports any files modified locally but not committed.

### Weekly Maintenance

```bash
# Clean up learnings
/consolidate

# Check for autonomous improvement PRs on GitHub
gh pr list --repo calebtala-zm/claude-super-setup --label autonomous-improvement
```

---

## 9. Running in a Container (Sandboxed)

### When to Use

| Scenario | Use Container? |
|----------|---------------|
| Running with `--dangerously-skip-permissions` | Yes |
| Ghost Mode overnight | Yes (recommended) |
| Team onboarding | Yes |
| Daily development on trusted machine | No |

### How to Start

1. Open the repo in VS Code
2. Command Palette → **"Dev Containers: Reopen in Container"**
3. Wait for build (first time ~3 min, subsequent ~30s)
4. Terminal is now inside the container

Inside the container:
```bash
# Safe to use — container is the sandbox
claude --dangerously-skip-permissions

# Ghost Mode is safe here too
/ghost --trust=high --hours=8
```

### What's Inside

- Ubuntu base with Node 22, Python 3.12, pnpm, gh CLI
- Full setup pre-installed (copy mode)
- VS Code extensions: Claude Code, GitLens, ShellCheck, Error Lens
- All 82 commands, 67 agents, 12 hooks, 16 templates

---

## 10. Troubleshooting

### "Command not found" after install

Restart Claude Code. Commands are loaded at session start.

### Hooks not firing

Check that hooks are executable:
```bash
ls -la ~/.claude/hooks/*.sh
# All should show -rwxr-xr-x
```

If not: `chmod +x ~/.claude/hooks/*.sh`

### "knowledge-rag" MCP not available

Install it globally:
```bash
npm install -g knowledge-rag
```

The setup works without it — RAG is optional. Claude gracefully skips unavailable MCP servers.

### Session start warnings

The `session-start.sh` hook checks for: git, node, pnpm, docker, gh auth, .nvmrc version, disk space. Fix any warnings it reports.

### Restoring from backup

If something went wrong:
```bash
~/.claude-super-setup/uninstall.sh --restore
```

This restores from the most recent `~/.claude-backup-{timestamp}/` directory.
