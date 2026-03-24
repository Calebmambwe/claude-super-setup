---
name: telegram-queue
description: Show Telegram dispatch task queue status
---

Read `~/.claude/telegram-queue.json` and `~/.claude/telegram-sessions.json` and display a formatted task queue dashboard.

## Process

### Step 1: Read Queue Files

Read both files. If either doesn't exist, report "Queue is empty."

### Step 2: Format Output

For each queue entry, display:

```
📋 Task Queue

Running:
  ⏳ #2 /check — 12m ago — session: dispatch-check-20260324-1415

Pending:
  ⏸ #3 /auto-ship — queued 5m ago

Completed (last 5):
  ✅ #1 /ghost "dark mode" — 45m — completed 2h ago
  ❌ #4 /build "auth" — failed (exit 1) — 20m ago

Use /cancel <#> to stop a running task.
```

### Step 3: Active Screen Sessions

Run `screen -ls` to show any active dispatch sessions that may not be in the queue file (edge case after crash recovery).

### Step 4: Reply

If called from Telegram (channel context available), send via `mcp__plugin_telegram_telegram__reply`.
If called from terminal, output normally.
