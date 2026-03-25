---
name: dispatch-local
description: Send a task to your Mac bot (@ghost_run_bot) for local execution
---

Dispatch a task to the local Mac for execution: $ARGUMENTS

## Process

### Step 1: Parse the Task

Extract the task description from $ARGUMENTS. If empty, ask what to run on the Mac.

### Step 2: Send to Mac Bot

Send the task as a message to the Mac bot via Telegram Bot API. The Mac Telegram listener will pick it up and execute it.

```bash
# Read Mac bot token from env
MAC_BOT_TOKEN=$(grep 'MAC_BOT_TOKEN=' ~/.claude/.env.local 2>/dev/null | sed 's/^MAC_BOT_TOKEN=//' | tr -d '[:space:]')
CHAT_ID=$(grep 'TELEGRAM_CHAT_ID=' ~/.claude/.env.local 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]' || echo "8328233140")

curl -s -X POST \
  "https://api.telegram.org/bot${MAC_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=$ARGUMENTS"
```

### Step 3: Confirm

Reply: "Dispatched to Mac: $ARGUMENTS — check @ghost_run_bot for results."

## Notes

- The Mac bot token is stored in `~/.claude/.env.local` as `MAC_BOT_TOKEN`
- This command is primarily used from the VPS to trigger work on the local Mac
- The Mac must have its Telegram listener running (start-telegram-server.sh)
