---
name: coordinate
description: Send a message to both Mac and VPS agents with Caleb in the loop — bidirectional agent coordination
---

Coordinate between Mac and VPS agents: $ARGUMENTS

## Overview

This command enables three-way communication: Mac <-> VPS <-> Caleb. Every message sent between agents is CC'd to Caleb's Telegram so he's always in the loop.

## Process

### Step 1: Parse the Message

Extract from $ARGUMENTS:
- **Target**: `mac`, `vps`, `both`, or `status` (default: `both`)
- **Message**: The coordination message to send

Examples:
- `/coordinate vps: push your current work to the branch`
- `/coordinate mac: pull latest and review VPS changes`
- `/coordinate both: sync on feat/self-improvement-engine branch`
- `/coordinate status` — check what both agents last reported

### Step 2: Read Coordination State

Check the shared coordination file for context:
```bash
cat ~/.claude/coordination.json 2>/dev/null || echo '{"mac": {}, "vps": {}, "last_sync": null}'
```

This file tracks:
- Last message sent to/from each agent
- Current task each agent is working on
- Last sync timestamp
- Pending responses

### Step 3: Send Messages

**To VPS (@ghost_run_remote_bot):**
```bash
VPS_BOT_TOKEN=$(grep 'VPS_BOT_TOKEN=' ~/.claude/.env.local 2>/dev/null | sed 's/^VPS_BOT_TOKEN=//' | tr -d '[:space:]')
CHAT_ID=$(grep 'TELEGRAM_CHAT_ID=' ~/.claude/.env.local 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]')

# Format: [MAC->VPS] prefix so VPS knows the source
curl -s -X POST \
  "https://api.telegram.org/bot${VPS_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=[MAC->VPS] $MESSAGE"
```

**To Mac (@ghost_run_bot) — used when VPS sends:**
```bash
MAC_BOT_TOKEN=$(grep 'MAC_BOT_TOKEN=' ~/.claude/.env.local 2>/dev/null | sed 's/^MAC_BOT_TOKEN=//' | tr -d '[:space:]')
CHAT_ID=$(grep 'TELEGRAM_CHAT_ID=' ~/.claude/.env.local 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]')

curl -s -X POST \
  "https://api.telegram.org/bot${MAC_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=[VPS->MAC] $MESSAGE"
```

### Step 4: CC Caleb (Always)

After sending to the target agent, ALWAYS also notify Caleb via the current Telegram channel:

```
[COORDINATION] Mac -> VPS:
"{message}"

Waiting for VPS response. You'll see it in @ghost_run_remote_bot.
```

This ensures Caleb sees every inter-agent message in his own chat.

### Step 5: Update Coordination State

Write the message to the shared coordination file:

```bash
# Update coordination.json with latest message
python3 -c "
import json, datetime
f = '$HOME/.claude/coordination.json'
try:
    state = json.load(open(f))
except:
    state = {'mac': {}, 'vps': {}, 'messages': [], 'last_sync': None}
state['messages'].append({
    'from': '$FROM',
    'to': '$TO',
    'message': '$MESSAGE',
    'timestamp': datetime.datetime.utcnow().isoformat() + 'Z'
})
state['messages'] = state['messages'][-20:]  # Keep last 20
state['last_sync'] = datetime.datetime.utcnow().isoformat() + 'Z'
json.dump(state, open(f, 'w'), indent=2)
"
```

### Step 6: Check for VPS Response (if status)

If `$ARGUMENTS` is `status`:
1. Read `~/.claude/coordination.json`
2. Show last 5 messages between agents
3. Show what each agent last reported working on
4. Check if VPS pushed anything: `git fetch origin && git log origin/feat/self-improvement-engine --oneline -5`

### Step 7: Git-Based Sync Check

Also check if VPS pushed code we haven't pulled:
```bash
git fetch origin 2>/dev/null
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/$(git branch --show-current) 2>/dev/null || echo "unknown")
if [ "$LOCAL" != "$REMOTE" ] && [ "$REMOTE" != "unknown" ]; then
    echo "VPS has pushed new commits! Run: git pull origin $(git branch --show-current)"
fi
```

## Auto-Coordination Rules

When you (Mac agent) are about to:
1. **Push code** — send: `/coordinate vps: I just pushed to {branch}. Pull when ready.`
2. **Need VPS input** — send: `/coordinate vps: Need you to {task}. Reply when done.`
3. **Complete a task** — send: `/coordinate both: Task complete: {summary}`
4. **Hit a blocker** — send: `/coordinate both: Blocked on: {issue}. Need help.`

When you receive a `[VPS->MAC]` message in Telegram:
1. Parse the message content
2. Act on it (pull code, review changes, etc.)
3. Reply via `/coordinate vps: Done. {status}`
4. CC Caleb automatically

## Message Format Convention

All inter-agent messages use prefixes:
- `[MAC->VPS]` — Mac sending to VPS
- `[VPS->MAC]` — VPS sending to Mac
- `[MAC->ALL]` — Mac broadcasting to VPS + Caleb
- `[VPS->ALL]` — VPS broadcasting to Mac + Caleb
- `[COORDINATION]` — Status update visible to Caleb

This makes it easy to filter and understand the conversation flow.

## Rules

- ALWAYS CC Caleb on every inter-agent message
- ALWAYS prefix messages with source/destination tags
- ALWAYS update coordination.json after sending
- NEVER send sensitive data (tokens, keys) between agents
- Keep messages concise — agents don't need prose, they need instructions
- If no response from VPS after 5 minutes, notify Caleb: "VPS hasn't responded. May need to check if it's running."
