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
- `grep -oP` (Perl regex) is NOT available on macOS — use `grep + sed` instead in shell scripts.
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

## Maintenance
- Update this file whenever durable project conventions change.
- Re-run `/cursor-setup` after major setup updates.
