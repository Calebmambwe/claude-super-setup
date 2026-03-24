---
name: telegram-cron
description: Manage scheduled recurring tasks — add, list, remove cron jobs triggered via Telegram
---

Manage recurring scheduled tasks that execute commands automatically on a cron schedule.

## Process

### Step 1: Parse Sub-command

Extract the action from $ARGUMENTS:
- `add "<schedule>: <command>"` — create a new cron job
- `list` — show all active cron jobs
- `remove <id>` — delete a cron job
- No arguments — show help

### Step 2: Handle Action

#### Add

Parse the schedule and command. Examples:
- `/cron add "9am daily: /ghost-status"` → cron: `0 9 * * *`, command: `/ghost-status`
- `/cron add "every 30min: /pipeline-status"` → cron: `*/30 * * * *`, command: `/pipeline-status`
- `/cron add "monday 8am: /check"` → cron: `0 8 * * 1`, command: `/check`
- `/cron add "0 */6 * * *: /ghost-status"` → raw cron expression, command: `/ghost-status`

Translate natural language schedules to cron expressions. If the user provides a raw cron expression, use it directly.

The cron job should execute:
```bash
bash <project_dir>/hooks/telegram-dispatch-runner.sh "<command>" "<args>" "<project_dir>" "cron-<command>-<timestamp>" "<chat_id>"
```

Use the `CronCreate` tool to register the job. Store the chat_id so results go back to the right Telegram chat.

Reply with confirmation:
```
⏰ Scheduled: /ghost-status
Cron: 0 9 * * * (9:00 AM daily)
Next run: 2026-03-25 09:00 UTC
```

#### List

Use the `CronList` tool. Format output:
```
⏰ Scheduled Tasks

| # | Schedule | Command | Next Run |
|---|----------|---------|----------|
| 1 | 9am daily | /ghost-status | 2026-03-25 09:00 |
| 2 | every 30m | /pipeline-status | 2026-03-24 15:30 |
```

#### Remove

Use the `CronDelete` tool with the given ID. Reply confirming deletion.

### Step 3: Reply

If called from Telegram, send via `mcp__plugin_telegram_telegram__reply`.
If called from terminal, output normally.
