# Feature Brief: Unified Agent System

**Created:** 2026-03-24
**Updated:** 2026-03-24
**Status:** Phase 1 MVP Complete | Phase 1.5 (Dispatch System) In Progress

---

## Problem

The user has a working Telegram bot (grammy-based MCP plugin) and persistent Claude Code sessions (Ghost Mode via screen, overnight.sh via tmux), but they're disconnected. To trigger a dev task from a phone, the user must SSH into the machine, attach to a screen/tmux session, and type commands manually. There's no mobile-first "text a task, get results" workflow despite all the infrastructure pieces already existing.

---

## Proposed Solution

A **Telegram-driven task dispatcher** that bridges the existing Telegram MCP plugin with Ghost Mode's persistent sessions. The flow: send a message to the Telegram bot -> a dispatcher picks it up -> launches or attaches to a Claude Code session in the correct project workspace -> streams results back to Telegram. Phase 1 focuses on this core loop using existing infrastructure. Phase 2 evaluates OpenClaw as an orchestrator if life/business automation (email, calendar, multi-model routing) becomes a priority. Phase 3 adds Gemini/Veo media pipeline.

---

## Target Users

**Primary:** Solo developer who wants mobile-first control over dev tasks via Telegram

**Secondary:** Anyone using claude-super-setup who wants remote Telegram-driven development

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Technical | Must work on existing local/cloud machine (no new VPS), reuse existing Telegram plugin and Ghost Mode infrastructure |
| Timeline | Time to first value is the priority — MVP in 1-2 sessions |
| Team | 1 engineer (solo) |
| Integration | Must not break existing Ghost Mode, overnight.sh, or Telegram plugin |

---

## Scope

### In Scope
- Telegram message -> Claude Code task execution -> results back to Telegram
- Reuse existing Telegram MCP plugin (grammy-based) and screen/tmux sessions
- Ghost Mode notifications routed to Telegram (in addition to ntfy.sh)
- Simple task queue: one task at a time, sequential execution
- Verify if Claude Code Channels (`--channels` flag) already provides this natively

### Out of Scope
- OpenClaw integration (evaluate after Phase 1 works)
- Multi-model routing (Claude-only for now)
- WhatsApp support
- Scheduled/cron automation (heartbeat)
- Gemini/Veo media pipeline
- Multi-agent parallel sessions
- Email/calendar/social media automation

---

## Feature Name

**Kebab-case identifier:** `unified-agent-system`

**Folder:** `docs/unified-agent-system/`

---

## Notes

1. **Existing infrastructure inventory:**
   - Telegram plugin: `~/.claude/plugins/claude-plugins-official/external_plugins/telegram/` (grammy, 4 MCP tools: reply, edit_message, react, download_attachment)
   - Ghost Mode: `commands/ghost.md` + `hooks/ghost-watchdog.sh` (screen-based, crash-resilient)
   - Overnight runner: `scripts/overnight.sh` (tmux-based, simpler one-shot)
   - Notifications: `hooks/ghost-notify.sh` (osascript + ntfy.sh, no Telegram)

2. **Architecture decision pending:** Whether to enhance Ghost Mode directly, build a new dispatcher, or leverage Claude Code's `--channels` flag. Step 2 of implementation will determine this.

3. **PTY unification opportunity:** Codebase uses both screen (Ghost Mode) and tmux (overnight.sh). This project should standardize on one (tmux recommended for better scripting API).

4. **OpenClaw evaluation deferred:** Research suggests OpenClaw is a real project but production readiness and plugin quality are unverified. Worth revisiting once the core Telegram->Claude Code loop is proven.

5. **Unverified commands from research notes:** `mcp install gemini-composio` and `claude mcp add gemini --url https://composio.dev` are potentially hallucinated. Do not use without checking against current docs.

---

## Phase 1.5: Telegram Dispatch System (2026-03-24)

### What Was Built

| Component | File | Purpose |
|-----------|------|---------|
| Dispatch command | `commands/telegram-dispatch.md` | Routes `/commands` from Telegram to slash commands via safety tiers |
| Queue command | `commands/telegram-queue.md` | Shows task queue status |
| Cron command | `commands/telegram-cron.md` | Manages recurring scheduled tasks |
| Parallel command | `commands/telegram-parallel.md` | Dispatches up to 3 concurrent tasks |
| Dispatch runner | `hooks/telegram-dispatch-runner.sh` | Spawns headless `claude -p` screen sessions for dispatched tasks |
| Watchdog fix | `hooks/ghost-watchdog.sh` | Wired `--channels` flag conditionally based on `telegram_enabled` |

### Architecture

- Persistent listener session (`start-telegram-server.sh`) acts as router, not executor
- Long-running tasks spawn separate `screen` sessions via `claude -p` (no `--channels` = no 409 conflict)
- Results flow back via log files + direct Bot API notifications
- Commands classified into SAFE (inline/spawn), CONFIRM, and BLOCKED tiers
- Queue at `~/.claude/telegram-queue.json`, sessions at `~/.claude/telegram-sessions.json`
