# claude-super-setup

A portable, enterprise-grade, always-on AI development platform with 98+ commands, 70+ agents, 16 stack templates, autonomous CI/CD, sandboxed development, RAG-powered planning, and mobile-first remote control via Telegram.

**[Full Usage Guide](docs/USAGE.md)** | **[Contributing](CONTRIBUTING.md)** | **[Upgrading](UPGRADING.md)**

## Quick Install

```bash
git clone https://github.com/calebtala-zm/claude-super-setup.git ~/.claude-super-setup
~/.claude-super-setup/install.sh
```

Or preview first:
```bash
~/.claude-super-setup/install.sh --dry-run
```

### Sandboxed Install (Container)

For safe autonomous operation — open in VS Code, then **Command Palette → "Reopen in Container"**:

```bash
git clone https://github.com/calebtala-zm/claude-super-setup.git
cd claude-super-setup
code .
```

Inside the container, `claude --dangerously-skip-permissions` is safe — the container IS the sandbox.

## Enterprise Agent Platform

Built across 6 sprints, the Enterprise Agent Platform transforms claude-super-setup into a portable, always-on AI development environment with enterprise-grade rigor:

| Pillar | What It Does | Sprint |
|--------|-------------|--------|
| Portable Setup | `setup-vps.sh` bootstrap, chezmoi dotfiles, systemd services, cross-machine MCP | Sprint 1 |
| Enterprise Dev Process | Enhanced design docs, SMURF tests, 3-gate code review, feature flags, PR/FAQ brainstorm, SRE post-mortems | Sprint 3 |
| Gemini Media | UI prototyping via Imagen 3, video demos via Veo 2, TTS — 37 Gemini MCP tools | Sprint 2 |
| Voice Brainstorming | Telegram voice notes → Whisper transcription → structured briefs | Sprint 2 |
| Personal Assistant | Morning brief, EOD summary, weekly health, PR reminders — all via Telegram cron | Sprint 4 |
| VS Code Agent Teams | Review/Feature/Debug team presets, remote control, worktree isolation, URI handler | Sprint 5 |
| Smart Hub API | 10-endpoint API spec for pipeline status, tasks, metrics, agents, teams, commands | Sprint 5 |
| Autonomous Agent | `/auto-develop` — zero-gate pipeline from raw idea to shipped PR | Sprint 1 |

## What's Included

### Commands (98+)

| Category | Commands | Purpose |
|----------|----------|---------|
| Core Workflow | /plan, /build, /check, /ship, /dev | Manual development pipeline |
| Autonomous | /auto-dev, /auto-ship, /auto-build-all | Fully autonomous pipelines |
| Ghost Mode | /ghost, /ghost-status, /ghost-run | Overnight autonomous work |
| Scaffolding | /new-app, /new-project, /new-agent-app | Project creation |
| Quality | /code-review, /security-check, /test-plan | Code quality gates |
| BMAD | /bmad:prd, /bmad:architecture, /bmad:sprint-planning | Product lifecycle |
| Documentation | /design-doc, /spec, /api-docs, /adr | Technical documentation |
| Observability | /pipeline-status, /metrics, /learning-dashboard | Pipeline monitoring |
| Enterprise | /flag, /post-mortem, /morning-brief, /eod-summary | Enterprise dev process |
| Media | /prototype, /demo-video, /voice-brief | Gemini media + voice |
| Assistant | /morning-brief, /eod-summary, /weekly-health, /pr-reminder | Proactive assistant |
| Teams | /team-build, /design-review | Agent team orchestration |

### Stack Templates (16)

| Category | Template | Stack |
|----------|----------|-------|
| Web | web-nextjs | Next.js 15 + Supabase |
| Web | web-astro | Astro 5 + Cloudflare Pages |
| Web | web-t3 | Next.js + tRPC + Prisma + NextAuth |
| Web | web-sveltekit | SvelteKit 2 + Lucia + Drizzle |
| Web | web-remix | Remix + Vite + Cloudflare Workers |
| Backend | api-hono | Hono + Drizzle + PostgreSQL |
| Backend | api-fastapi | FastAPI + SQLAlchemy + PostgreSQL |
| Backend | api-hono-edge | Hono + Cloudflare Workers + D1 |
| Mobile | mobile-expo | Expo + TypeScript + Supabase |
| Mobile | mobile-nativewind | Expo + NativeWind + Supabase |
| Mobile | mobile-flutter | Flutter 3 + Supabase + Riverpod |
| Mobile | mobile-expo-revenucat | Expo + RevenueCat + IAP |
| Specialized | saas-starter | Next.js + Stripe + Supabase Auth |
| Specialized | ai-ml-app | Next.js + AI SDK + pgvector |
| Specialized | chrome-extension | TypeScript + Vite + Manifest V3 |
| Specialized | cli-tool | TypeScript + Commander.js + tsup |

### Agents (70+)

Core agents across 8 departments plus community agents for language specialists, data/AI, infrastructure, and mobile.

| Department | Example Agents |
|------------|---------------|
| Engineering | architect, backend-dev, frontend-dev, mobile-app-builder |
| Testing | tdd-test-writer, test-writer-fixer, visual-tester |
| Design | ui-designer, whimsy-injector, brand-guardian |
| Security | security-auditor, code-reviewer |
| Product | sprint-prioritizer, feedback-synthesizer |
| Community | go-specialist, rust-specialist, ml-pipeline-builder, kubernetes-specialist |

### Model Routing (4-tier)

| Tier | Model | Use For |
|------|-------|---------|
| haiku | claude-haiku-4-5 | Simple tasks: formatting, lookups |
| sonnet | claude-sonnet-4-6 | Standard: implementation, testing |
| opus | claude-opus-4-6 | Critical: architecture, security review |
| custom | varies | Specialized tasks |

### Preset Agent Teams

| Team | Agents | Keybinding | Use Case |
|------|--------|------------|----------|
| review | code-reviewer + security-auditor + verifier | Cmd+Shift+R | Code quality gate |
| feature | architect + backend-dev + frontend-dev + tdd-test-writer | Cmd+Shift+F | Full feature sprint |
| debug | env-doctor + test-writer-fixer + researcher | Cmd+Shift+D | Debug complex issues |
| frontend | frontend-dev + ui-designer + tdd-test-writer | — | Frontend sprint |
| backend | backend-dev + architect + security-auditor | — | API development |
| fullstack | architect + backend-dev + frontend-dev + test-writer-fixer | — | Full feature |
| mobile | mobile-app-builder + ui-designer + test-writer-fixer | — | Mobile dev |

### Lifecycle Hooks (12)

Auto-formatting, auto-testing, branch protection, SDLC gate enforcement, Ghost Mode supervision, and more.

### CI/CD (3 workflows)

- **ci.yml** — Validates every PR: shellcheck, markdownlint, YAML schema, actionlint, inventory
- **release.yml** — Automated semver releases via release-please
- **improve.yml** — Weekly: Claude Code Action proposes improvements as PRs

### RAG-Powered Planning

The setup includes a `knowledge-rag` MCP server that indexes its own `docs/` and `agent_docs/` directories. Claude can search the research brief, design document, architecture standards, and security guidelines during any `/plan` session. Per-project RAG is also generated by `/new-app` and `/new-project`.

### Sandboxed Development

A `.devcontainer/` is included for running Claude Code inside a Docker container. This enables safe autonomous operation with `--dangerously-skip-permissions` — the container is the blast radius. Includes Node 22, Python 3.12, pnpm, gh CLI, shellcheck, and all VS Code extensions pre-configured.

## Install Options

```bash
# Symlink mode (default) — git pull updates instantly
./install.sh

# Copy mode — independent copy
./install.sh --mode=copy

# Selective modules
./install.sh --modules=commands,agents,hooks

# Custom location
./install.sh --prefix=/path/to/claude-config
```

### VPS Deployment

Deploy the full stack to a remote Ubuntu VPS for always-on operation:

```bash
# On your VPS (Ubuntu 24.04 LTS)
curl -fsSL https://raw.githubusercontent.com/calebtala-zm/claude-super-setup/main/scripts/setup-vps.sh | bash

# Authenticate Claude
claude setup-token

# Start services
sudo systemctl enable --now claude-telegram claude-ghost claude-learning
```

The VPS setup installs Node 22, Python 3.12, Claude Code, Telegram listener, and all MCP servers. Uses systemd for service management and Tailscale for secure access.

## Updating

```bash
cd ~/.claude-super-setup && git pull
```

With symlink mode, pulling updates the live config instantly.

## Uninstalling

```bash
~/.claude-super-setup/uninstall.sh

# Restore from backup
~/.claude-super-setup/uninstall.sh --restore
```

## Architecture

```
~/.claude-super-setup/          (git repo)
├── config/                     (CLAUDE.md, settings.json, stack templates, systemd units)
├── commands/                   (98+ slash commands)
├── agents/core/                (50+ core agents)
├── agents/community/           (18+ community agents)
├── agents/teams/               (VS Code team presets: review, feature, debug)
├── agents/catalog.json         (agent registry + model routing)
├── hooks/                      (14 lifecycle hooks)
├── rules/                      (14 path-scoped rules)
├── skills/                     (6 skill modules)
├── schemas/                    (JSON Schema for validation)
├── scripts/                    (CI validation + media + VPS bootstrap)
├── mcp-servers/                (learning server, sandbox server)
├── docs/                       (feature briefs, design docs, architecture)
├── .github/workflows/          (CI + release + improvement)
├── install.sh                  (one-command installer)
└── uninstall.sh                (clean removal)
```

## Configuration

### Shared (tracked in git)
Commands, agents, hooks, rules, templates, skills, settings.json

### Personal (gitignored)
settings.local.json, ghost-config.json, logs, learning database, session history

Override shared settings by editing `~/.claude/settings.local.json`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
