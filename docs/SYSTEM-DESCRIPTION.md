# Claude Super Setup — Full System Description

## For integration with LobeHub or any agent platform

---

## What This Is

An enterprise-grade AI development platform built on Claude Code (Anthropic). It provides 86+ slash commands, 50+ specialized agents, and autonomous development pipelines accessible from terminal, VS Code, and Telegram.

## Core Capabilities

### 1. Autonomous Development Pipeline
```
/auto-develop "build a habit tracker"
  → /bmad:research (market research)
  → /brainstorm (feature brief)
  → /design-doc (architecture)
  → /auto-plan (task decomposition)
  → /auto-build-all (implement all tasks)
  → /check (code review + security + tests)
  → /ship (commit + PR)
  → /reflect (capture learnings)
```

### 2. Ghost Mode (Overnight Autonomous Builds)
```
/ghost "feature" --trust aggressive --budget 50
  → Launches in screen session
  → Survives terminal close, Mac sleep, crashes
  → Auto-restarts with exponential backoff
  → Sends Telegram notifications at each phase
  → Creates PR when done
```

### 3. Full Telegram Integration
- Two bots: `@ghost_run_bot` (Mac), `@ghost_run_remote_bot` (VPS)
- NLP natural language routing ("build me X" → auto-routes to right command)
- Voice transcription (Gemini free tier)
- Cross-machine dispatch (Mac↔VPS)
- 24/7 persistent listener with auto-restart

### 4. Enterprise Dev Process (Google-Level)
- Design docs with Alternatives Considered + Cross-Cutting Concerns
- SMURF test classification (Small/Medium/Large)
- 3-gate code review (correctness + ownership + readability)
- Feature flags (`/flag create/enable/disable/list`)
- Google SRE postmortem template
- Amazon PR/FAQ brainstorming

### 5. Personal Assistant
- `/morning-brief` — calendar + tasks + overnight results
- `/eod-summary` — daily done/blocked/tomorrow
- `/weekly-health` — all projects health report
- `/pr-reminder` — open PRs needing review

### 6. Media Generation
- Gemini MCP (37 tools) — image gen, video gen (Veo), TTS
- `/prototype "UI description"` — generate mockup images
- `/demo-video "walkthrough"` — generate video demos

## Agent Catalog

### Core Agents (50+)
| Department | Agents |
|-----------|--------|
| Engineering | architect, backend-dev, frontend-dev, go-specialist, rust-specialist, java-specialist, swift-specialist, kotlin-specialist, ruby-specialist, elixir-specialist, php-specialist |
| Testing | tdd-test-writer, test-writer-fixer, visual-tester |
| Security | security-auditor, rn-security |
| Design | ui-designer, frontend-dev, rn-accessibility |
| Product | prompt-engineer, data-engineer, ml-pipeline-builder |
| DevOps | devops-automator, aws-architect, terraform-specialist, gcp-specialist, kubernetes-specialist |
| Code Review | code-reviewer, pr-review-toolkit (silent-failure-hunter, code-simplifier, type-design-analyzer, comment-analyzer, pr-test-analyzer) |

### Agent Teams (Pre-configured)
```json
{
  "review": ["code-reviewer", "security-auditor", "test-writer-fixer"],
  "feature": ["architect", "frontend-dev", "backend-dev"],
  "debug": ["code-reviewer", "test-writer-fixer", "security-auditor"]
}
```

## MCP Servers

| Server | Purpose |
|--------|---------|
| context7 | Library documentation (always up-to-date) |
| learning | SQLite learning ledger (self-improving) |
| sandbox | Docker sandbox execution |
| gemini | Google Gemini (37 tools: image, video, TTS, search) |
| Gmail | Email triage and drafts |
| Google Calendar | Calendar management |
| GitHub | Repository management, PRs, issues |
| Playwright | Browser automation and visual testing |

## Commands by Category (86 total)

### Pipeline
`auto-develop`, `auto-dev`, `auto-plan`, `auto-tasks`, `auto-build`, `auto-build-all`, `auto-ship`, `ghost`, `ghost-run`, `ghost-status`, `next-task`, `pipeline-status`, `rollback`

### Planning
`plan`, `brainstorm`, `spec`, `design-doc`, `full-pipeline`, `init-tasks`

### Building
`build`, `dev`, `scaffold`, `api-endpoint`, `db-migrate`, `refactor`, `debug`, `build-page`, `new-app`, `new-project`, `new-agent-app`, `ci-setup`, `team-build`, `parallel-implement`

### Quality
`check`, `code-review`, `security-audit`, `security-check`, `review`, `generate-tests`, `test-plan`, `design-review`, `perf-audit`, `deps-audit`, `visual-verify`, `visual-regression`, `web-test`

### Shipping
`ship`, `pr`, `changelog`

### Telegram
`telegram-dispatch`, `telegram-queue`, `telegram-cron`, `telegram-parallel`, `dispatch-remote`, `dispatch-local`

### Personal Assistant
`morning-brief`, `eod-summary`, `weekly-health`, `pr-reminder`, `dashboard`

### Media
`prototype`, `demo-video`, `voice-brief`

### Enterprise Process
`flag`, `post-mortem`, `adr`, `metrics`

### BMAD Workflow
`bmad:product-brief`, `bmad:prd`, `bmad:architecture`, `bmad:tech-spec`, `bmad:sprint-planning`, `bmad:dev-story`, `bmad:create-story`, `bmad:create-ux-design`, `bmad:brainstorm`, `bmad:research`, `bmad:workflow-init`, `bmad:workflow-status`

### Documentation
`api-docs`, `api-spec`, `reverse-doc`, `onboard`, `sdlc-meta-prompt`, `implement-design`, `implement-meta-prompt`, `milestone-prompts`

### Learning
`reflect`, `consolidate`, `learning-dashboard`, `init-agents-md`

## Hooks (19 lifecycle scripts)

| Hook | Trigger | Action |
|------|---------|--------|
| session-start | Session begins | Health check, load learnings |
| session-end | Session ends | Log session |
| auto-fix-loop | PostToolUse (Write/Edit) | Auto-lint and format |
| auto-quality-gate | PostToolUse (Write/Edit) | Auto lint+typecheck on code |
| telemetry | PostToolUse (all) | Log tool calls for observability |
| alert-check | Session end | Check for anomalies, send alerts |
| test-after-impl | PostToolUse (Write) | Auto-run tests on source changes |
| branch-guard | PreToolUse (Bash) | Block push to main |
| protect-files | PreToolUse (Write/Edit) | Block writes to .env, .ssh |
| read-before-write | PreToolUse (Write) | Force read before overwrite |
| ghost-notify | Notification | Triple-channel: macOS + ntfy + Telegram |
| ghost-watchdog | Ghost Mode | Process supervisor with crash recovery |
| ghost-monitor | Background | 24/7 Telegram status updates |
| telegram-dispatch-runner | Telegram | Spawn sessions for dispatched commands |

## API Keys Available

| Service | Purpose |
|---------|---------|
| Anthropic (OAuth) | Claude models |
| Gemini | Image/video generation, voice transcription |
| OpenAI | Whisper voice (backup) |
| Manus.ai | Agent collaboration |
| Telegram | Two bots (Mac + VPS) |

## VPS Deployment

```bash
# One-liner setup
curl -sSL https://raw.githubusercontent.com/Calebmambwe/claude-super-setup/main/scripts/setup-vps.sh | bash
```

Server: 187.77.15.168 (Ubuntu 24.04, 16GB RAM, 193GB disk)
Services: tmux sessions, systemd services, Docker Compose
Boot persistence: @reboot crontab

## Repository

Private repo: https://github.com/Calebmambwe/claude-super-setup
