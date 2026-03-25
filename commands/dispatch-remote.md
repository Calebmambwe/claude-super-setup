---
name: dispatch-remote
description: Send a task to your VPS bot (@ghost_run_remote_bot) for remote execution
---

Dispatch a task to the VPS for remote execution: $ARGUMENTS

## Process

### Step 1: Parse the Task

Extract the task description from $ARGUMENTS. If empty, ask what to run on the VPS.

### Step 2: Send to VPS Bot

Send the task as a message to the VPS bot via Telegram Bot API. The VPS Telegram listener will pick it up and execute it.

```bash
# Read VPS bot token from env
VPS_BOT_TOKEN=$(grep 'VPS_BOT_TOKEN=' ~/.claude/.env.local 2>/dev/null | sed 's/^VPS_BOT_TOKEN=//' | tr -d '[:space:]')
CHAT_ID=$(grep 'TELEGRAM_CHAT_ID=' ~/.claude/.env.local 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]' || echo "8328233140")

curl -s -X POST \
  "https://api.telegram.org/bot${VPS_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=$ARGUMENTS"
```

### Step 3: Confirm

Reply: "Dispatched to VPS: $ARGUMENTS — check @ghost_run_remote_bot for results."

If called from Telegram, also react with a checkmark and reply via MCP tool.

## Notes

- The VPS bot token is stored in `~/.claude/.env.local` as `VPS_BOT_TOKEN`
- The VPS listener picks up the message and routes it through `/telegram-dispatch` (NLP or slash command)
- Results come back via the VPS bot in Telegram
