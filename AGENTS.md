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

## Maintenance
- Update this file whenever durable project conventions change.
- Re-run `/cursor-setup` after major setup updates.
