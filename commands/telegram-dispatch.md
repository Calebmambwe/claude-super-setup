---
name: telegram-dispatch
description: Route Telegram messages to slash commands — core dispatcher for remote mobile control
---

Telegram Command Dispatcher — routes inbound Telegram messages to the appropriate slash command, manages task queue, and reports results.

## When This Runs

This logic activates when the persistent Telegram listener session receives a `<channel source="telegram" ...>` message. The listener session (started via `bash ~/.claude/start-telegram-server.sh`) runs Claude with `--channels plugin:telegram@claude-plugins-official`.

**You do NOT need to be explicitly told to use this command.** When you receive a `<channel source="telegram">` message that starts with `/`, automatically apply this dispatch logic.

## Process

### Step 1: Parse the Inbound Message

Extract from the `<channel>` tag:
- `chat_id` — needed for replies
- `message_id` — needed for reactions
- `user` — for logging
- The message text content

If the message does NOT start with `/`, treat it as **conversational** — respond normally via `mcp__plugin_telegram_telegram__reply` and stop. You are a helpful assistant in chat mode.

If the message starts with `/`, extract:
- **Command name**: the first word after `/` (e.g., `ghost`, `auto-ship`, `queue`)
- **Arguments**: everything after the command name

### Step 2: Check for Completed Sessions

Before dispatching anything, scan `~/.claude/telegram-sessions.json` for sessions where `completed_at` is not null and the result has not been sent yet. For each completed session:

1. Read the last 20 lines of its `log_file`
2. Send a summary via `mcp__plugin_telegram_telegram__reply` to the session's `chat_id`:
   ```
   ✅ Task completed: /ghost "add dark mode"
   Session: dispatch-ghost-20260324-1400
   Duration: 45m

   [last few lines of output]
   ```
   Or if failed:
   ```
   ❌ Task failed: /ghost "add dark mode"
   Exit code: 1

   [last few lines of output]
   ```
3. Mark the session as reported (set a `result_sent` flag or remove from the sessions file)

Note: The dispatch runner (`telegram-dispatch-runner.sh`) also sends completion notifications directly via the Bot API. This step is a backup for cases where the direct notification failed.

### Step 3: Classify the Command

Commands are organized into safety tiers:

#### SAFE — Inline (execute in this session, reply immediately)

These are read-only or quick status commands:

```
ghost-status, pipeline-status, metrics, learning-dashboard, consolidate
```

**Action:** Execute the command directly using the Skill tool, then send the output via `mcp__plugin_telegram_telegram__reply`.

#### SAFE — Spawn (launch a separate session)

These are long-running pipeline commands:

```
ghost, auto-ship, auto-build-all, auto-build, auto-tasks, check, ship,
next-task, reflect, code-review, security-audit, security-check,
generate-tests, changelog, test-plan, perf-audit, deps-audit,
visual-verify, web-test, build, scaffold, api-endpoint, refactor,
debug, new-app, new-project, ci-setup, auto-plan, review,
team-build, parallel-implement, production-ready
```

**Action:**
1. React to the message with ⏳ using `mcp__plugin_telegram_telegram__react`
2. Generate a session name: `dispatch-<command>-<YYYYMMDD-HHMM>`
3. Determine project directory (use current working directory unless the user specifies a path)
4. Add entry to `~/.claude/telegram-queue.json`:
   ```json
   {
     "id": "<uuid>",
     "command": "<command>",
     "args": "<args>",
     "chat_id": "<chat_id>",
     "message_id": "<message_id>",
     "project_dir": "<project_dir>",
     "status": "running",
     "enqueued_at": "<ISO8601>",
     "started_at": "<ISO8601>",
     "finished_at": null,
     "screen_name": "<session_name>",
     "log_file": "~/.claude/logs/dispatch-<session_name>.log",
     "result_sent": false
   }
   ```
5. Run the dispatch runner:
   ```bash
   bash hooks/telegram-dispatch-runner.sh "<command>" "<args>" "<project_dir>" "<session_name>" "<chat_id>"
   ```
6. Reply via `mcp__plugin_telegram_telegram__reply`:
   ```
   ✅ Queued: /<command> <args>
   Session: <session_name>
   Project: <project_dir>

   Use /queue to check status.
   ```

#### CONFIRM (ask before executing)

These commands have potentially destructive effects:

```
rollback, db-migrate
```

**Action:** Reply asking for explicit confirmation:
```
⚠️ This command can have destructive effects:

/<command> <args>

Reply YES to confirm, or anything else to cancel.
```

Store the pending command in `~/.claude/telegram-queue.json` with `status: "awaiting_confirm"`. When the next message is "YES" (case-insensitive), change status to "running" and dispatch. Otherwise, mark as "cancelled".

#### BLOCKED (cannot run remotely)

These commands require interactive multi-turn conversation:

```
brainstorm, auto-dev, dev, full-pipeline, plan,
telegram:access, telegram:configure,
bmad:product-brief, bmad:prd, bmad:architecture, bmad:brainstorm,
bmad:research, bmad:sprint-planning
```

**Action:** Reply with explanation and suggest an alternative:
```
🚫 /<command> requires interactive conversation and can't run remotely.

Try instead:
• /ghost "<feature>" — autonomous pipeline, no interaction needed
• /auto-ship — if you already have tasks.json
• /auto-build-all — build all pending tasks autonomously
```

#### Meta-Commands (handled inline by this dispatcher)

**`/queue`** — Read `~/.claude/telegram-queue.json` and `~/.claude/telegram-sessions.json`. Reply with a formatted status table:
```
📋 Task Queue

| # | Command | Status | Duration |
|---|---------|--------|----------|
| 1 | /ghost "dark mode" | ✅ completed | 45m |
| 2 | /check | ⏳ running | 12m |
| 3 | /auto-ship | ⏸ pending | — |
```

**`/help`** — Reply with the list of available remote commands grouped by tier.

**`/cancel <session_name_or_number>`** — Kill the screen session for a running task:
```bash
screen -X -S <screen_name> quit
```
Update queue status to "cancelled". Reply confirming cancellation.

**`/status`** — Alias for `/queue`.

### Step 4: Initialize Queue File if Absent

If `~/.claude/telegram-queue.json` does not exist, create it:
```json
{
  "version": 1,
  "queue": []
}
```

If `~/.claude/telegram-sessions.json` does not exist, create it:
```json
{
  "sessions": []
}
```

### Step 5: Handle Unknown Commands

If the command name doesn't match any known command, reply:
```
❓ Unknown command: /<command>

Type /help to see available commands.
```

## Important Rules

1. **Always reply via MCP tool** — use `mcp__plugin_telegram_telegram__reply` with the `chat_id` from the channel tag. Never just output text; the user is on Telegram, not in a terminal.

2. **React first, reply second** — for spawned tasks, immediately react with ⏳ so the user knows their message was received, then send the detailed reply.

3. **New reply for completions** — always use `reply` (not `edit_message`) for task completion notifications, so the user's phone pings with a push notification.

4. **No --channels on spawned sessions** — the dispatch runner uses `claude -p` without `--channels`. Only this listener session holds the Telegram bot connection.

5. **Log everything** — all dispatched tasks log to `~/.claude/logs/dispatch-<session_name>.log`.

6. **Prune old sessions** — when the queue grows past 50 entries, remove completed entries older than 7 days.

## File Paths

- Queue: `~/.claude/telegram-queue.json`
- Sessions: `~/.claude/telegram-sessions.json`
- Runner: `hooks/telegram-dispatch-runner.sh` (in the project directory)
- Logs: `~/.claude/logs/dispatch-*.log`
