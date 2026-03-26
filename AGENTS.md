# AGENTS.md

Shared project context for Claude Code and Cursor agents.

## Purpose
- Keep agent behavior consistent across both editors.
- Record repo-specific patterns and gotchas as they emerge.

## Cursor Integration
- Canonical MCP source: `~/.cursor/mcp.json`. Project defaults to inherit-global mode.
- Regenerate rules: `bash ~/.claude-super-setup/scripts/cursor-sync.sh rules --force`

## Telegram System
- Plugin is bidirectional: inbound via `--channels plugin:telegram@claude-plugins-official`, outbound via `reply` MCP tool.
- **409 Conflict Rule:** Only ONE session can hold `--channels`. Spawned dispatch sessions must NEVER use `--channels`.
- `ghost-notify.sh` is triple-channel: macOS osascript + ntfy.sh + Telegram Bot API.
- Bot token: `~/.claude/channels/telegram/.env`. Access control: `access.json`. Queue: `telegram-queue.json`.
- Dispatch runs commands in `screen` sessions via `telegram-dispatch-runner.sh` (37 allowed commands).
- NLP routing: "build X" -> `/ghost`, "fix X" -> `/debug`, "teach me X" -> `/teach-me`. High-confidence auto-dispatches.
- `grep -oP` (Perl regex) is NOT available on macOS — use `grep + sed` instead.

## Marketplace Integration
- MCP registry cache: `~/.claude/mcp-registry/cache.json` (24h TTL, `scripts/mcp-registry-fetch.py`).
- Knowledge RAG: per-project SQLite at `~/.claude/knowledge/{hash}.db`. FTS5 baseline, optional sqlite-vss + sentence-transformers.
- Imported skills: `~/.claude/skills/imported/<name>/`. Tracked in `~/.claude/skill-registry.json`.
- Imported agents: `agents/community/imported/<name>.md`. Tracked in `catalog.json` with `source="imported"`.
- Agent converter: import only (LobeHub JSON -> our MD). 20+ model tier mappings.
- `/mcp-install` uses `jq` merge — never overwrites full settings.json. Requires `jq`.
- FTS5 requires sanitizing special chars before MATCH. Cache writes use atomic rename.

## Patterns
- PTY sessions: Ghost Mode uses `screen`, overnight.sh uses `tmux` — standardization pending.
- Notifications fail silently (`|| true`) to prevent blocking pipelines.
- Telegram long-polling (grammy 1.41.1 pinned exact), NOT webhooks.
- All hooks use `set -euo pipefail` + `#!/usr/bin/env bash`.
- Budget guard tracks tool calls per session (default max: 200 calls, 20 subagents).
- `PROJECT_ANCHOR.md` prevents goal drift — agents re-read every task iteration.
- Session protocol: HANDOVER -> tasks.json -> PROJECT_ANCHOR -> work.

## Gotchas
- Telegram typing indicator expires ~5s — re-fire on interval for long tasks.
- Zombie bot process on unclean exit: `pkill -f "bun.*telegram.*server.ts"` before starting.
- `caffeinate -s` = AC power only. macOS-only — guard with `command -v caffeinate`.
- Bash `done` is a keyword — use `completed_count` instead (SC1010).
- systemd `@.service` suffix required for `%i`/`%h` specifier expansion.
- `proc.returncode or 0` in Python masks `None` — use `if returncode is not None else -1`.
- Docker APT repos differ between ubuntu/debian — branch on `$OS`.
- `shlex.quote()` required for user-supplied paths in shell commands.
- Multi-gate commands must keep agent counts consistent between headings and rules sections.
- Feature flag rollout must hash `flagName + userId`, not `flagName` alone.
- All `$ARGUMENTS`-accepting commands need prompt injection guards via Telegram dispatch.
- Knowledge RAG enforces HOME boundary — paths outside `$HOME` are rejected.

## Security
- `protect-files.sh` guards: `.env*`, lockfiles, `.git/`, `settings.json`, `CLAUDE.md`.
- Voice transcriptions and `/prototype` args are user-supplied — Telegram allowlist is the primary injection boundary.
- `/flag` is CONFIRM tier in dispatch — validate names against `^[a-z][a-z0-9-]{1,49}$`.
- MCP servers validate path boundaries (must be under `$HOME`).

## Testing
- 166 unit tests (pytest): knowledge-rag, agent-converter, mcp-registry-fetch.
- 5 integration test suites: hooks existence, config validation, dispatch security, notifications, VPS flags.
- Budget guard: 200 tool calls max, 20 subagents max, 10-call warm-up grace.

## VS Code Agent Teams (Sprint 5)
- `agents/teams/` contains VS Code team presets: `review.json`, `feature.json`, `debug.json`.
- Each preset defines agent composition, workflow steps with dependencies, model tiers, and VS Code keybindings.
- Presets reference agents from `catalog.json` — agent names must match exactly.
- Schema at `schemas/team-preset.schema.json` validates preset structure.
- Review team: code-reviewer + security-auditor + verifier (Cmd+Shift+R). Feature team: architect + backend-dev + frontend-dev + tdd-test-writer (Cmd+Shift+F). Debug team: env-doctor + test-writer-fixer + researcher (Cmd+Shift+D).
- Verifier agent (`agents/core/verifier.md`) now validates team presets: checks agent existence, model tier validity, role assignment, workflow dependency cycles.

## Remote Control Architecture (Sprint 5)
- Full architecture documented at `docs/remote-control.md` — covers Telegram dispatch, cron, parallel sessions, Ghost Mode, notifications.
- Worktree isolation documented at `docs/worktree-isolation.md` — covers when/how to use git worktrees for parallel agent execution.
- URI handler documented at `docs/uri-handler.md` — `claude://` deep links for VS Code (commands, tasks, agents, pipeline).
- URI security mirrors Telegram dispatch tiers: read-only URIs auto-execute, state-changing URIs require confirmation.

## Smart Hub API (Sprint 5)
- API spec at `docs/smart-hub/api-spec.md` — 10 endpoints covering pipeline status, tasks, metrics, agents, teams, commands, health.
- Endpoints are Tauri IPC commands documented with REST conventions for clarity.
- `POST /api/commands/:name/run` uses async event streaming for live output.
- All endpoints source data from existing files (ghost-config.json, tasks.json, metrics.jsonl, catalog.json).

## Maintenance
- Update this file whenever durable project conventions change.
- Re-run `/cursor-setup` after major setup updates.
- Keep this file under 80 lines. Consolidate when it grows past 80.
