# AGENTS.md

Shared project context for Claude Code and Cursor agents.

## Purpose
- Keep agent behavior consistent across both editors.
- Record repo-specific patterns and gotchas as they emerge.

## Cursor Integration Conventions
- Canonical MCP source is global: `~/.cursor/mcp.json`.
- Project `.cursor/mcp.json` defaults to inherit-global mode (`mcpServers: {}`).
- Use template MCP only when project-specific overrides are required.
- Regenerate project rules with:
  - `bash ~/.claude-super-setup/scripts/cursor-sync.sh rules --force`

## Workflow Expectations
- Follow the `.cursor/rules/*.mdc` workflow rules for planning/building/shipping.
- Prefer one logical change per commit and conventional commit messages.
- Keep docs and scripts in sync when behavior changes.

## Telegram Integration
- Telegram plugin is bidirectional: inbound messages via `--channels plugin:telegram@claude-plugins-official`, outbound via `reply` MCP tool.
- Ghost Mode supports `--telegram` flag which adds `--channels` to the Claude launch and enables Telegram notifications.
- `ghost-notify.sh` is triple-channel: macOS osascript + ntfy.sh + Telegram Bot API (auto-detects chat_id from `access.json`).
- Bot token lives in `~/.claude/channels/telegram/.env`, access control in `~/.claude/channels/telegram/access.json`.
- `grep -oP` (Perl regex) is NOT available on macOS — use `grep + sed` pattern instead in shell scripts.

## Telegram Dispatch System
- `/telegram-dispatch` routes inbound Telegram `/commands` to slash commands via safety tiers (SAFE/CONFIRM/BLOCKED).
- Long-running commands spawn separate `screen` sessions via `hooks/telegram-dispatch-runner.sh` using `claude -p` (headless, no `--channels`).
- **409 Conflict Rule:** Only ONE session can hold `--channels` at a time. Spawned dispatch sessions must NEVER use `--channels`.
- Task queue: `~/.claude/telegram-queue.json`. Session registry: `~/.claude/telegram-sessions.json`. Logs: `~/.claude/logs/dispatch-*.log`.
- `/telegram-cron` manages recurring tasks via `CronCreate`/`CronList`/`CronDelete`.
- `/telegram-parallel` dispatches up to 3 concurrent tasks in separate screen sessions.

## Patterns
- PTY sessions: Ghost Mode uses `screen`, overnight.sh uses `tmux` — standardization pending.
- Notification channels all fail silently (|| true) to prevent blocking the pipeline.
- Telegram server uses long-polling (grammy `bot.start()`), NOT webhooks — only one poller per token allowed.
- grammy pinned to exact 1.41.1 (no `^`) to prevent silent behavior changes on restart.

## Gotchas
- Telegram typing indicator (`sendChatAction`) expires after ~5s — must re-fire on interval for long tasks.
- If Claude Code exits uncleanly, the old Telegram bot process lingers as a zombie holding the poll slot — causes 409 Conflict for new sessions. Always `pkill -f "bun.*telegram.*server.ts"` before starting.
- `caffeinate -s` only prevents sleep on AC power, not battery. Wi-Fi power management is separate.
- Bash variable named `done` conflicts with `done` keyword — use `completed_count` or similar instead (SC1010).
- systemd template units MUST use `@.service` suffix for `%i`/`%h` specifiers to expand correctly. Without `@`, `User=%i` is literal.
- `caffeinate` is macOS-only — guard with `command -v caffeinate` before calling in scripts that run on Linux VPS.
- Never use `proc.returncode or 0` in Python — it masks `None` returncode. Use `if returncode is not None else -1`.
- Docker APT repos differ between ubuntu and debian — branch on `$OS` when constructing GPG key and repo URLs.
- `shlex.quote()` is required for user-supplied paths in shell commands — never interpolate raw strings into f-string shell commands.
- `--skip-chezmoi` flag in setup-vps.sh is parsed but intentionally unused — reserved for Sprint 2 chezmoi dotfiles integration.

## Gemini Media Integration (Sprint 2)
- Gemini MCP provides 37 tools via `@rlabs-inc/gemini-mcp` (image gen, video gen, TTS, editing).
- Setup: `bash scripts/setup-gemini-mcp.sh` — requires `GEMINI_API_KEY` env var.
- `/prototype` generates UI mockups via Gemini Imagen 3, saves to `docs/{project}/mockups/`.
- `/demo-video` generates short videos via Gemini Veo 2, saves to `docs/{project}/demos/`.
- fal.ai is the cheaper video alternative — add with `--with-fal` flag on setup script.

## Voice Transcription (Sprint 2)
- `scripts/transcribe-voice.sh` converts OGG/OGA voice files to text via OpenAI Whisper API ($0.006/min).
- Requires `OPENAI_API_KEY` env var and `ffmpeg` installed.
- `/voice-brief` structures raw voice transcriptions into feature briefs at `docs/{feature}/brief.md`.
- Voice notes from Telegram arrive as OGG files — the transcription script handles the OGG→MP3→Whisper pipeline.

## Enterprise Dev Process (Sprint 3)
- `/design-doc` now includes mandatory "Alternatives Considered" (with revisit triggers) and "Cross-Cutting Concerns" (6 areas: security, observability, error handling, testing, deployment, performance).
- `/generate-tests` uses SMURF taxonomy: [S]moke, [M]utation, [U]nit, [R]egression, [F]unctional. Every test must be tagged.
- `/check` runs 3-gate code review: Gate A (Correctness), Gate B (Ownership), Gate C (Readability). Only A and B block merge; C is advisory.
- `/flag create|enable|disable|list|remove|status` manages feature flags in `flags.json`. Flags are disabled by default.
- `/brainstorm` includes optional PR/FAQ step (Amazon Working Backwards) — generates press release + FAQs to pressure-test ideas.
- `/post-mortem` uses Google SRE template: adds Detection metrics (TTD/TTE/TTM/TTR), Recurrence Assessment, Support & Communication, and PREVENT/DETECT/MITIGATE/PROCESS action item types.

## Security Notes
- Voice transcriptions and `/prototype` `$ARGUMENTS` are user-supplied — Telegram allowlist (`access.json`) is the primary injection boundary. Keep it restrictive.
- `transcribe-voice.sh` suppresses API error bodies by default to avoid leaking partial API keys in logs. Use `VERBOSE=1` for debugging.
- `/flag` should be `CONFIRM` tier in Telegram dispatch — it writes to filesystem. Validate flag names against `^[a-z][a-z0-9-]{1,49}$`; treat `--description` as data, never interpolate into shell commands.

## Sprint 3 QA Gotchas
- Multi-gate commands (like `/check` with 5 agents) must keep agent counts consistent between headings, instructions, and rules sections — contradictions cause silent agent omission.
- Nested markdown code fences in templates (e.g., `` ```markdown `` inside `` ```markdown ``) easily produce duplicate closing fences that break parsing.
- Feature flag percentage rollout must hash `flagName + userId`, not `flagName` alone — flag-only hash produces all-or-nothing, not distributed rollout.
- All `$ARGUMENTS`-accepting commands need prompt injection guards when reachable via Telegram dispatch.

## Sprint 4: Personal Assistant + Manus Patterns
- `/morning-brief` (7am cron), `/eod-summary` (6pm weekday), `/weekly-health` (Sunday), `/pr-reminder` (9am+2pm) — all support Telegram delivery with 4096-char split, gracefully skip missing integrations.
- `PROJECT_ANCHOR.md` — attention anchoring: agents re-read every task iteration to prevent goal drift.
- `agents/core/verifier.md` — independent verifier (sonnet, no builder context). Accepts acceptance criteria + git diff, returns PASS/FAIL.
- `HANDOVER.md` — cross-session state. Session protocol: HANDOVER → tasks.json → PROJECT_ANCHOR → work.

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

## Sprint 6: Ghost Mode Hardening + Telegram Dev Parity + Local Models

### NLP Natural Language Routing
- `telegram-dispatch.md` now supports natural language intent detection alongside explicit `/commands`.
- Pattern-based routing: "build X" → `/ghost "X"`, "fix X" → `/debug X`, "ship it" → `/auto-ship`, "what's running?" → `/queue`.
- Always-autonomous default: BUILD/PLAN intents route to `/ghost` (fire-and-forget from mobile).
- High-confidence matches dispatch immediately; medium-confidence asks for confirmation.
- No-match falls back to conversational mode — no false positives.
- Queue entries include `nlp_routed: true/false` flag for observability.

### New Hooks
- `hooks/auto-quality-gate.sh` — PostToolUse hook that runs lint (ESLint/Biome/ruff) and typecheck (tsc/mypy) after Edit/Write on source files. Supports JS/TS/Python.
- `hooks/telemetry.sh` — PostToolUse hook that logs structured JSON events to `~/.claude/logs/telemetry.jsonl`. Classifies tool types (read/write/exec/agent/mcp). Auto-rotates at 10MB.
- `hooks/alert-check.sh` — PostToolUse hook (Bash) with 4 mandatory alerts: (1) test suite failure, (2) build/compile failure, (3) disk space >90%, (4) Ghost Mode timeout exceeding max_hours. All alerts log to `~/.claude/logs/alerts.jsonl` and dispatch via `ghost-notify.sh`.

### Local Model Support (Ollama)
- `config/model-routing.json` — routing config mapping task types (planning, implementation, review, testing, triage, embedding) to models with Anthropic primary and Ollama fallback.
- Fallback triggers: HTTP 429/529/500+, budget < $1, network timeout > 30s.
- Offline mode: `CLAUDE_OFFLINE=1` skips Anthropic entirely, uses only Ollama.
- `setup-vps.sh --with-ollama` — Phase 9/10 installs Ollama, pulls llama3.2:3b, copies model-routing.json with Ollama enabled.

### Observability Dashboard
- `commands/dashboard.md` — unified view aggregating pipeline status, task progress, tool usage, alerts, system health, and queue.
- Full terminal version with box-drawing characters, condensed Telegram version under 4096 chars.
- Sources: ghost-config.json, tasks.json, telemetry.jsonl, alerts.jsonl, model-costs.jsonl, telegram-queue.json.

### Extended Test-After-Impl
- `hooks/test-after-impl.sh` now triggers on ALL source file changes (.ts/.tsx/.js/.jsx/.py/.go/.rs), not just test files.
- For source files: searches 6 patterns to find corresponding test file (co-located, __tests__, tests/ mirror, Python test_ prefix).
- Silently skips if no corresponding test found. Reports which source file triggered the test.

### Integration Tests
- 5 integration tests in `tests/integration/`: hooks existence (15 checks), config validation (12 checks), dispatch runner security (12 checks), ghost-notify levels (8 checks), setup-vps flags (10 checks).
- Total: 57 assertions, all passing.

## Multi-Model Routing (Sprint 6+)
- `config/model-routing.json` — central routing config: Anthropic (primary) → OpenRouter (fallback) → Ollama (local).
- `scripts/openrouter-client.sh` — unified OpenRouter caller. Exit codes: 0=ok, 1=auth, 2=model, 3=network, 4=rate-limit.
- `scripts/model-router.sh` — task-type router. Reads config, resolves provider+model, implements fallback chain.
- `scripts/dual-compare.sh` — runs 2 models in parallel, Opus judges winner. Logs to `~/.claude/logs/comparisons.jsonl`.
- `scripts/embed.sh` — embeddings via OpenRouter or Ollama.
- `/compare` command — user-facing dual-model comparison.
- `OPENROUTER_API_KEY` must be in `~/.claude/.env.local`. Telegram dispatch runner sources it automatically.
- Dual-mode is opt-in: `--dual` flag on `/build` and `/ghost`, or `dual_mode.enabled: true` in config.
- Opus 4.6 is ALWAYS the brain — other models are workers only. Never route planning/judgment to non-Anthropic models.
- Benchmark winner: `qwen/qwen3-coder` (9.5/10 correctness, 2.1s avg). See `docs/local-models/openrouter-benchmarks.md`.
- `comparisons.jsonl` stores SHA256 hash of prompts, never raw prompt text (PII/IP protection).

### Multi-Model Gotchas
- jq shorthand `{ts, foo}` means `{ts: .ts, foo: .foo}` (field lookup), NOT `{ts: $ts, foo: $foo}` (variable). Always use explicit `{ts: $ts}` when using `--arg`.
- curl `-w "%{http_code}" -o file` is the reliable pattern for separating HTTP code from body. Never parse HTTP code from response string suffix.
- OpenRouter can return HTTP 200 with `{"error": {...}}` body — always check `.error.message` even on 200.
- Free models (`:free` suffix) are unreliable — never use as primary for anything except triage.
- `claude -p` outputs telemetry JSON to stdout on exit — pipe through `grep -v` to filter if capturing output.

## Maintenance
- Update this file whenever durable project conventions change.
- Re-run `/cursor-setup` after major setup updates.
