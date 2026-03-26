---
name: telegram-dispatch
description: Route Telegram messages to slash commands — core dispatcher with NLP natural language routing for remote mobile control
---

Telegram Command Dispatcher — routes inbound Telegram messages to the appropriate slash command using both explicit `/command` syntax and natural language intent detection. Manages task queue and reports results.

## When This Runs

This logic activates when the persistent Telegram listener session receives a `<channel source="telegram" ...>` message. The listener session (started via `bash ~/.claude/start-telegram-server.sh`) runs Claude with `--channels plugin:telegram@claude-plugins-official`.

**You do NOT need to be explicitly told to use this command.** When you receive a `<channel source="telegram">` message, automatically apply this dispatch logic — whether the message starts with `/` or is natural language.

## Process

### Step 1: Parse the Inbound Message

Extract from the `<channel>` tag:
- `chat_id` — needed for replies
- `message_id` — needed for reactions
- `user` — for logging
- The message text content

**Two parsing paths:**

**Path A — Explicit command** (message starts with `/`):
- **Command name**: the first word after `/` (e.g., `ghost`, `auto-ship`, `queue`)
- **Arguments**: everything after the command name
- Proceed to Step 2.

**Path B — Natural language** (message does NOT start with `/`):
- Apply NLP intent routing (Step 1.5) to determine if this is an actionable request or conversational.

### Step 1.5: NLP Natural Language Routing

When the message does NOT start with `/`, classify the user's intent using these pattern rules. The default mode is **always-autonomous** — if a message looks like a task, route it to the autonomous pipeline. Only fall back to conversational mode when no intent matches.

#### Intent Detection Rules

Match against these patterns (case-insensitive). The FIRST matching rule wins:

| Pattern | Intent | Routes To | Example |
|---------|--------|-----------|---------|
| `build ...`, `create ...`, `add ...`, `implement ...`, `make ...` | BUILD | `/ghost "<captured args>"` | "build a dark mode toggle" → `/ghost "dark mode toggle"` |
| `fix ...`, `debug ...`, `repair ...`, `solve ...` | FIX | `/debug <captured args>` | "fix the login bug" → `/debug the login bug` |
| `test ...`, `run tests ...`, `check tests ...` | TEST | `/generate-tests <captured args>` | "test the auth module" → `/generate-tests auth module` |
| `review ...`, `check code ...`, `audit ...` | REVIEW | `/check` | "review my latest changes" → `/check` |
| `ship ...`, `deploy ...`, `push ...`, `release ...` | SHIP | `/auto-ship` | "ship it" → `/auto-ship` |
| `plan ...`, `design ...`, `architect ...` | PLAN | `/ghost "<captured args>"` | "plan a notification system" → `/ghost "notification system"` |
| `status`, `how's it going`, `progress`, `what's running` | STATUS | `/queue` | "what's running?" → `/queue` |
| `refactor ...`, `clean up ...`, `improve ...` | REFACTOR | `/refactor <captured args>` | "refactor the auth service" → `/refactor auth service` |
| `security ...`, `vulnerabilities ...`, `secure ...` | SECURITY | `/security-check` | "check for security issues" → `/security-check` |
| `docs ...`, `document ...`, `explain ...` | DOCS | `/reverse-doc <captured args>` | "document the API" → `/reverse-doc API` |
| `scaffold ...`, `bootstrap ...`, `new project ...`, `new app ...` | SCAFFOLD | `/new-app <captured args>` | "scaffold a todo app" → `/new-app todo app` |
| `cancel ...`, `stop ...`, `kill ...`, `abort ...` | CANCEL | `/cancel <captured args>` | "stop the ghost run" → `/cancel` (latest running) |
| `coordinate ...`, `tell vps ...`, `tell mac ...`, `sync with ...` | COORDINATE | `/coordinate <captured args>` | "tell vps to push" → `/coordinate vps: push your current work` |
| `benchmark ...`, `run benchmark ...` | BENCHMARK | `/benchmark <captured args>` | "run benchmark" → `/benchmark` |
| `help`, `what can you do`, `commands` | HELP | `/help` | "what can you do?" → `/help` |

#### Confidence & Confirmation

When NLP routing matches an intent:

1. **High confidence** (exact verb match at start of message): Route immediately. React with ⏳ and reply:
   ```
   🧠 Understood: "<original message>"
   → Routing to: /<resolved-command> <args>
   ```

2. **Medium confidence** (verb found but not at start, or ambiguous args): Ask for confirmation:
   ```
   🤔 I think you want:
   → /<resolved-command> <args>

   Reply YES to confirm, or rephrase your request.
   ```
   Store as `status: "awaiting_nlp_confirm"` in the queue. On "YES", dispatch. Otherwise, treat as conversational.

3. **No match**: Treat as conversational — respond normally as a helpful assistant via `mcp__plugin_telegram_telegram__reply`. Do NOT force-route unclear messages.

#### Inter-Agent Messages

If the message starts with `[VPS->MAC]` or `[VPS->ALL]`, this is a coordination message from the VPS agent:
1. Parse the content after the prefix
2. Act on the instruction (pull code, review changes, respond, etc.)
3. Reply via `/coordinate vps: {response}`
4. CC Caleb by also replying to the Telegram chat: "[COORDINATION] Received from VPS: {summary}. Action taken: {what you did}"

#### Always-Autonomous Default

When BUILD or PLAN intent is detected, ALWAYS route to `/ghost` (fully autonomous) rather than `/auto-dev` or `/plan` (which require interaction). The user is on mobile — they want fire-and-forget.

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
ghost-status, pipeline-status, metrics, learning-dashboard, consolidate, dashboard,
coordinate, benchmark-status, budget-status
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
team-build, parallel-implement, production-ready, reverse-doc
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
     "result_sent": false,
     "nlp_routed": false
   }
   ```
   Set `nlp_routed: true` if the command was resolved via NLP rather than explicit `/command`.
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

💡 Or just describe what you want in plain English — I'll route it autonomously.
```

#### Meta-Commands (handled inline by this dispatcher)

**`/queue`** — Read `~/.claude/telegram-queue.json` and `~/.claude/telegram-sessions.json`. Reply with a formatted status table:
```
📋 Task Queue

| # | Command | Status | Duration | Source |
|---|---------|--------|----------|--------|
| 1 | /ghost "dark mode" | ✅ completed | 45m | NLP |
| 2 | /check | ⏳ running | 12m | /cmd |
| 3 | /auto-ship | ⏸ pending | — | /cmd |
```

The "Source" column shows `NLP` for natural-language-routed tasks and `/cmd` for explicit commands.

**`/help`** — Reply with the list of available remote commands grouped by tier, AND include the NLP natural language examples:
```
🤖 Remote Commands

📌 Quick Status (inline):
/ghost-status, /pipeline-status, /metrics, /dashboard

🚀 Pipelines (spawned):
/ghost, /auto-ship, /check, /build, /debug, ...

⚠️ Destructive (confirm required):
/rollback, /db-migrate

📝 Or just type naturally:
• "build a dark mode toggle"
• "fix the login bug"
• "ship it"
• "what's running?"
```

**`/cancel <session_name_or_number>`** — Kill the screen session for a running task:
```bash
screen -X -S <screen_name> quit
```
Update queue status to "cancelled". Reply confirming cancellation.

**`/status`** — Alias for `/queue`.

**`/dashboard`** — Execute the dashboard command and reply with the output.

### Step 4: Initialize Queue File if Absent

If `~/.claude/telegram-queue.json` does not exist, create it:
```json
{
  "version": 2,
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
💡 Or just describe what you want in plain English!
```

## Important Rules

1. **Always reply via MCP tool** — use `mcp__plugin_telegram_telegram__reply` with the `chat_id` from the channel tag. Never just output text; the user is on Telegram, not in a terminal.

2. **React first, reply second** — for spawned tasks, immediately react with ⏳ so the user knows their message was received, then send the detailed reply.

3. **New reply for completions** — always use `reply` (not `edit_message`) for task completion notifications, so the user's phone pings with a push notification.

4. **No --channels on spawned sessions** — the dispatch runner uses `claude -p` without `--channels`. Only this listener session holds the Telegram bot connection.

5. **Log everything** — all dispatched tasks log to `~/.claude/logs/dispatch-<session_name>.log`.

6. **Prune old sessions** — when the queue grows past 50 entries, remove completed entries older than 7 days.

7. **NLP routing is fire-and-forget** — when natural language maps to a BUILD/PLAN intent, always use `/ghost` (autonomous). Never route to interactive commands from NLP.

8. **No false positives** — if NLP confidence is low, default to conversational mode. A missed routing is better than a wrong one.

9. **Prompt injection guard** — NLP-extracted arguments are user-supplied data. Never interpolate them into shell commands without sanitization. The dispatch runner validates against its allowlist.

## File Paths

- Queue: `~/.claude/telegram-queue.json`
- Sessions: `~/.claude/telegram-sessions.json`
- Runner: `hooks/telegram-dispatch-runner.sh` (in the project directory)
- Logs: `~/.claude/logs/dispatch-*.log`
