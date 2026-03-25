# Changelog

All notable changes to claude-super-setup are documented here.

## [Sprint 6] — 2026-03-24: Polish, Documentation & Release

### Changed
- Updated README.md with full Enterprise Agent Platform feature list and setup instructions
- Updated docs/FEATURES.md marking all features complete
- Updated AGENTS.md with all patterns and gotchas from Sprints 1-5
- Updated install.sh to handle agents/teams and schemas directories
- Updated docs/enterprise-agent-platform/brief.md status to Complete

### Added
- CHANGELOG.md (this file)

## [Sprint 5] — 2026-03-24: VS Code Agent Teams + Smart Hub API

### Added
- VS Code Agent Team presets: `review.json`, `feature.json`, `debug.json` in `agents/teams/`
- Team preset JSON schema at `schemas/team-preset.schema.json`
- Agent catalog with model routing at `agents/catalog.json`
- Smart Hub API spec (10 endpoints) at `docs/smart-hub/api-spec.md`
- Remote control architecture docs at `docs/remote-control.md`
- Worktree isolation docs at `docs/worktree-isolation.md`
- URI handler docs at `docs/uri-handler.md`
- Verifier agent validates team presets (agent existence, model tiers, dependency cycles)

### Fixed
- Updated success criteria and fixed workflow dependency in team presets

## [Sprint 4] — 2026-03-24: Personal Assistant + Manus Patterns

### Added
- `/morning-brief` (7am cron), `/eod-summary` (6pm weekday), `/weekly-health` (Sunday), `/pr-reminder` (9am+2pm)
- All assistant commands support Telegram delivery with 4096-char message splitting
- `PROJECT_ANCHOR.md` — attention anchoring to prevent agent goal drift
- `HANDOVER.md` — cross-session state protocol
- `agents/core/verifier.md` — independent verifier agent (sonnet, no builder context)
- Graceful degradation when integrations are missing

## [Sprint 3] — 2026-03-24: Enterprise Dev Process + Manus Collaboration

### Added
- Enhanced `/design-doc` with mandatory "Alternatives Considered" and "Cross-Cutting Concerns" (6 areas)
- SMURF test taxonomy for `/generate-tests`: [S]moke, [M]utation, [U]nit, [R]egression, [F]unctional
- 3-gate code review in `/check`: Gate A (Correctness), Gate B (Ownership), Gate C (Readability)
- `/flag create|enable|disable|list|remove|status` — feature flag management via `flags.json`
- Amazon PR/FAQ step in `/brainstorm` (Working Backwards press release + FAQs)
- Enhanced `/post-mortem` with Google SRE template (TTD/TTE/TTM/TTR, PREVENT/DETECT/MITIGATE/PROCESS)

## [Sprint 2] — 2026-03-24: Gemini Media + Voice Transcription

### Added
- Gemini MCP integration (37 tools) via `@rlabs-inc/gemini-mcp`
- `scripts/setup-gemini-mcp.sh` — one-command Gemini MCP setup
- `/prototype` command — UI mockup generation via Gemini Imagen 3
- `/demo-video` command — video demo generation via Gemini Veo 2
- fal.ai MCP as cheaper video alternative (`--with-fal` flag)
- `scripts/transcribe-voice.sh` — OGG/OGA voice → text via OpenAI Whisper API
- `/voice-brief` command — voice note → structured feature brief

## [Sprint 1] — 2026-03-24: Portability Foundation + Auto-Develop

### Added
- `scripts/setup-vps.sh` — one-command Ubuntu VPS bootstrap (Node 22, Python 3.12, Claude Code, MCP servers)
- chezmoi integration for `~/.claude/` dotfiles with encrypted secrets
- systemd unit files for Telegram listener, Ghost Mode, learning server
- `~/.mcp.json` template with path variables for cross-machine portability
- MCP servers tracked in repo: `mcp-servers/learning-server.py`, `mcp-servers/sandbox-server.py`
- `/auto-develop` command — zero-gate SDLC pipeline (idea → PR)

### Fixed
- Reduced ghost-watchdog MAX_ATTEMPTS from 5 to 3, BACKOFF from 30s to 15s

## [1.0.0] — 2026-03-23: Initial Release

### Added
- 82 slash commands across core workflow, autonomous, scaffolding, quality, BMAD, documentation, and observability
- 50 core agents across 8 departments (engineering, testing, design, security, product, community)
- 18+ community agents (language specialists, infrastructure, data/AI)
- 14 lifecycle hooks (auto-formatting, auto-testing, branch protection, SDLC gates, Ghost Mode)
- 16 stack templates (web, backend, mobile, specialized)
- 14 path-scoped rules
- 6 skill modules (design-system, backend-architecture, docker, BMAD, meta-rules, self-learning)
- 3 CI/CD workflows (ci.yml, release.yml, improve.yml)
- Agent catalog with 4-tier model routing (haiku, sonnet, opus, custom)
- Preset agent teams (review, frontend, backend, fullstack, mobile)
- RAG-powered planning via knowledge-rag MCP
- Sandboxed development via `.devcontainer/`
- `install.sh` with symlink/copy modes, selective modules, backup
- `uninstall.sh` with backup restoration
- Drift detection and inventory validation scripts
- Comprehensive docs: USAGE.md, CONTRIBUTING.md, UPGRADING.md
