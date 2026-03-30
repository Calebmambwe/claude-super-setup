---
name: a2a
description: Agent-to-Agent protocol — send tasks to peer agents, check status, manage connections
---

A2A Agent Coordination: $ARGUMENTS

## Overview

This command enables A2A (Agent-to-Agent) protocol communication with peer agents: Mac local agent, Manus.ai, Gemini, and any other A2A-compatible agents.

## Commands

Parse $ARGUMENTS for one of these subcommands:

### `send <agent> <task>`
Send a task to a peer agent and wait for the result.

```bash
# Send to Mac agent
/a2a send mac "Pull latest changes and run tests on zed-impact"

# Send to Manus for research
/a2a send manus "Research the top 5 alternatives to Stripe for African payments"

# Explicit routing
/a2a send claude "Review the PR on feat/a2a-protocol"
```

**Implementation:**
```python
import asyncio, sys
sys.path.insert(0, "$HOME/.claude-super-setup")
from claude_a2a.client import send_to_peer
result = asyncio.run(send_to_peer("$AGENT", "$TASK"))
print(result)
```

### `status`
Check which peer agents are online and their capabilities.

```python
import asyncio, sys, json
sys.path.insert(0, "$HOME/.claude-super-setup")
from claude_a2a.client import list_peers
peers = asyncio.run(list_peers())
print(json.dumps(peers, indent=2))
```

### `server start|stop|status`
Manage the local A2A server.

```bash
# Start
bash ~/.claude-super-setup/scripts/start-a2a-server.sh --background

# Status
if [ -f ~/.claude/a2a-server.pid ]; then
    PID=$(cat ~/.claude/a2a-server.pid)
    if kill -0 "$PID" 2>/dev/null; then
        echo "A2A server running (PID $PID) on port ${A2A_PORT:-9999}"
    else
        echo "A2A server not running (stale PID file)"
    fi
else
    echo "A2A server not running"
fi

# Stop
if [ -f ~/.claude/a2a-server.pid ]; then
    kill "$(cat ~/.claude/a2a-server.pid)" 2>/dev/null
    rm -f ~/.claude/a2a-server.pid
    echo "A2A server stopped"
fi
```

### `card`
Show this agent's A2A Agent Card (what peers see when they discover us).

```python
import sys, json
sys.path.insert(0, "$HOME/.claude-super-setup")
from claude_a2a.server import build_agent_card
card = build_agent_card()
print(json.dumps(card.model_dump(), indent=2))
```

### `peers`
List configured peer agents from environment.

```bash
echo "Configured peers (A2A_PEERS env):"
echo "${A2A_PEERS:-none}" | tr ',' '\n' | while IFS='=' read -r name url; do
    echo "  $name → $url"
done
```

## Routing Conventions

When sending tasks, the router auto-detects the best executor:
- **@claude** or default → Claude CLI (code, deploy, review)
- **@manus** or "research deeply" → Manus.ai (autonomous research)
- **@gemini-image** or "generate image" → Gemini image gen
- **@gemini-video** or "generate video" → Gemini Veo video gen

Or use explicit routing: prefix your prompt with `[manus]`, `[gemini-image]`, `[gemini-video]`, or `[claude]`.

## Configuration

Peer agents are configured via the `A2A_PEERS` environment variable in `~/.claude/.env.local`:
```bash
A2A_PEERS="mac=http://mac-ip:9999,manus=http://localhost:9999"
```

API keys:
```bash
MANUS_API_KEY=your-manus-key
GEMINI_API_KEY=your-gemini-key
A2A_API_KEY=shared-secret-for-peer-auth
```

## Rules

- ALWAYS CC Caleb on inter-agent coordination (send Telegram message)
- NEVER send secrets or API keys via A2A
- Tasks timeout after 10 minutes by default
- If a peer is offline, report clearly — don't retry silently
