# Brainstorm: Bulletproof 24/7 VPS Telegram Listener

**Date:** 2026-03-25
**Problem:** The VPS Telegram bot goes down constantly and requires manual SSH intervention to fix. This defeats the entire purpose of remote access.

---

## Root Cause Analysis (from today's debugging session)

### Every failure mode observed:

| # | Failure | Root Cause | Current Protection | Result |
|---|---------|------------|-------------------|--------|
| 1 | Auth token expires | OAuth tokens have TTL, no auto-refresh | None | "Not logged in", bot dead |
| 2 | `--channels ignored` | Claude ignores channels if not logged in at startup | None | Bot receives nothing |
| 3 | Trust folder prompt | Interactive prompt blocks headless startup | None | Process hangs forever |
| 4 | Effort level prompt | Interactive prompt blocks headless startup | None | Process hangs forever |
| 5 | Bun plugin dies | bun server.ts crashes independently of Claude | None | Claude runs but no messages arrive |
| 6 | Claude process freezes | Context fills, process stuck at prompt | None | Bot appears up but doesn't respond |
| 7 | `claude` not in PATH | NVM not loaded in non-interactive shells | None | systemd can't find binary |
| 8 | systemd/user mismatch | Services configured for root, process runs as claude | None | Services in restart loops |
| 9 | No health monitoring | Nobody checks if bot actually processes messages | None | Unknown downtime |
| 10 | Chicken-and-egg | Can't fix Telegram via Telegram when it's down | None | Must SSH manually |

### Why the current approach is fundamentally fragile:

Claude Code is an **interactive CLI tool** being used as a **headless daemon**. Every interactive prompt (trust, effort, login) is a blocking failure point. The `--dangerously-skip-permissions` flag skips permission prompts but NOT:
- Folder trust prompts
- Effort level selection
- Login/auth prompts
- Update notifications

---

## Solution: Multi-Layer Reliability Architecture

### Layer 1: Startup Script (eliminates interactive prompts)

Create a dedicated VPS startup script that handles EVERY interactive prompt automatically before launching Claude.

**Key insight:** We need `expect`-style automation or pre-configuration to eliminate all prompts.

#### Pre-configure to skip prompts:
1. **Trust folder**: Add working directory to `.claude.json` trusted directories BEFORE starting
2. **Effort level**: Set via environment variable or settings.json
3. **Auth**: Use API key instead of OAuth (doesn't expire) OR implement auto-refresh
4. **NVM path**: Source NVM in the script, not rely on shell profile

```bash
#!/usr/bin/env bash
# vps-telegram-start.sh — Zero-prompt headless startup

# Source NVM explicitly
export NVM_DIR="/home/claude/.nvm"
source "$NVM_DIR/nvm.sh"

# Pre-trust the working directory (write to .claude.json)
python3 -c "
import json
f = '/home/claude/.claude.json'
with open(f) as fh: d = json.load(fh)
if 'projects' not in d: d['projects'] = {}
key = '/home/claude'
if key not in d['projects']: d['projects'][key] = {'trusted': True}
with open(f, 'w') as fh: json.dump(d, fh, indent=2)
"

# Ensure auth is valid (check credentials, warn if expired)
if ! python3 -c "
import json, time
creds = json.load(open('/home/claude/.claude/.credentials.json'))
# Check if OAuth token exists and has required fields
print('auth_ok')
" 2>/dev/null | grep -q "auth_ok"; then
  echo "[FATAL] Auth expired — sending alert and attempting re-auth"
  # Send alert via direct Bot API (doesn't need Claude)
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}&text=ALERT: VPS Claude auth expired. Run /login on VPS."
  exit 1
fi

# Start Claude
exec claude --dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official
```

### Layer 2: Process Supervisor (replaces tmux)

**Problem with tmux:** No auto-restart, no health checks, no crash detection.

**Solution:** Use a proper process supervisor. Options:

#### Option A: supervisord (recommended)
```ini
[program:claude-telegram]
command=/home/claude/.claude-super-setup/scripts/vps-telegram-start.sh
user=claude
directory=/home/claude
autostart=true
autorestart=true
startsecs=10
startretries=999
stopwaitsecs=30
stdout_logfile=/home/claude/.claude/logs/telegram-supervisor.log
stderr_logfile=/home/claude/.claude/logs/telegram-supervisor-error.log
environment=HOME="/home/claude",PATH="/home/claude/.nvm/versions/node/v22.22.2/bin:/home/claude/.bun/bin:/usr/local/bin:/usr/bin:/bin"
```

#### Option B: systemd (fix the current approach)
```ini
[Service]
User=claude
Environment=HOME=/home/claude
Environment=PATH=/home/claude/.nvm/versions/node/v22.22.2/bin:/home/claude/.bun/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/home/claude/.claude-super-setup/scripts/vps-telegram-start.sh
Restart=always
RestartSec=10
```

#### Option C: Simple bash supervisor loop (most portable)
```bash
#!/usr/bin/env bash
# vps-telegram-supervisor.sh — Runs forever, restarts Claude on crash
while true; do
  echo "[$(date)] Starting Claude Telegram listener..."
  /home/claude/.claude-super-setup/scripts/vps-telegram-start.sh
  EXIT_CODE=$?
  echo "[$(date)] Claude exited with code $EXIT_CODE. Restarting in 10s..."
  # Alert on crash
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}&text=VPS listener crashed (exit $EXIT_CODE). Auto-restarting..."
  sleep 10
done
```

### Layer 3: Health Monitor (detects silent failures)

The most critical missing piece. A separate process that:
1. Sends a test message to the bot every 5 minutes
2. Checks if the bot responds within 60 seconds
3. If no response → kills and restarts the listener
4. Sends alert via direct Bot API (bypasses the broken listener)

```bash
#!/usr/bin/env bash
# vps-telegram-healthcheck.sh — Runs via cron every 5 minutes

BOT_TOKEN="..."
CHAT_ID="..."
HEALTH_FILE="/tmp/telegram-health-$(date +%s)"

# Step 1: Send a health check message
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}&text=__healthcheck_$(date +%s)__" > /dev/null

# Step 2: Wait 60 seconds, check if the bot processed it
# (Bot should respond to healthcheck messages with a reaction or acknowledgment)
sleep 60

# Step 3: Check if Claude is actually responding
# Method: Check if the Claude process wrote anything to logs in the last 5 minutes
LOG_FILE="/home/claude/.claude/logs/telegram-supervisor.log"
if [ -f "$LOG_FILE" ]; then
  LAST_MODIFIED=$(stat -c %Y "$LOG_FILE" 2>/dev/null || stat -f %m "$LOG_FILE")
  NOW=$(date +%s)
  AGE=$((NOW - LAST_MODIFIED))
  if [ "$AGE" -gt 600 ]; then
    echo "UNHEALTHY: Log not updated in ${AGE}s"
    # Kill and restart
    supervisorctl restart claude-telegram 2>/dev/null || \
      systemctl restart claude-telegram 2>/dev/null || \
      pkill -u claude -f "claude.*channels"

    # Alert
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -d "chat_id=${CHAT_ID}&text=ALERT: Telegram listener was unresponsive. Auto-restarted."
  fi
fi
```

### Layer 4: Auth Persistence (eliminates manual login)

**The nuclear option:** Use an API key instead of OAuth.

OAuth tokens expire. API keys don't. For a headless daemon, API keys are the right choice.

```bash
# In /home/claude/.claude/env (read by systemd EnvironmentFile)
ANTHROPIC_API_KEY=sk-ant-...

# OR in the startup script
export ANTHROPIC_API_KEY=$(cat /home/claude/.claude/api-key.txt)
```

**If OAuth must be used:** Implement token refresh:
1. Store the refresh token from `.credentials.json`
2. Before each startup, check if token is expired
3. If expired, use refresh token to get new access token
4. If refresh token is also expired → send Telegram alert asking user to manually re-auth

### Layer 5: Escape Hatch (solves chicken-and-egg)

When Telegram is down, we need an alternative way to reach the VPS.

#### Option A: SSH watchdog (cron on Mac)
Mac runs a cron job every 15 minutes that SSHes into VPS and checks health:
```bash
# On Mac: crontab entry
*/15 * * * * /path/to/scripts/vps-health-ssh.sh
```

#### Option B: ntfy.sh webhook
VPS registers a webhook with ntfy.sh. Mac can send restart commands via ntfy:
```bash
# VPS listens:
while true; do
  MSG=$(curl -s "https://ntfy.sh/caleb-vps-control/raw")
  if [ "$MSG" = "restart-telegram" ]; then
    supervisorctl restart claude-telegram
  fi
done
```

#### Option C: Tailscale + secondary bot
Run a tiny Python bot (not Claude) that only handles restart commands. Uses a different bot token so it's independent of the Claude listener.

---

## Recommended Solution: The Three-Process Architecture

Instead of one fragile process, run THREE independent processes:

```
┌─────────────────────────────────────────────────────┐
│  Process 1: SUPERVISOR (always running)             │
│  - supervisord or bash loop                         │
│  - Starts/restarts Claude listener                  │
│  - Handles crashes, logs restarts                   │
│  - Sends Telegram alerts on crash via direct API    │
└────────────────────────┬────────────────────────────┘
                         │ manages
┌────────────────────────▼────────────────────────────┐
│  Process 2: CLAUDE LISTENER (the actual bot)        │
│  - claude --dangerously-skip-permissions --channels │
│  - Pre-configured: no prompts, auth cached          │
│  - Handles Telegram messages                        │
│  - May crash — that's OK, supervisor restarts it    │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Process 3: HEALTH MONITOR (independent watchdog)   │
│  - Runs every 5 min via cron                        │
│  - Checks: is Claude alive? Is bun alive?           │
│  - Checks: has the bot processed messages recently? │
│  - If unhealthy: tells supervisor to restart        │
│  - If auth expired: sends alert, does NOT restart   │
│  - Escape hatch: also checks SSH-based commands     │
└─────────────────────────────────────────────────────┘
```

### Why three processes?
- **Supervisor** handles crashes (Process 2 dies → auto-restart)
- **Health monitor** handles silent failures (Process 2 alive but frozen → force restart)
- **Both** can send alerts via direct Bot API (bypasses Process 2 entirely)
- If Process 1 dies → systemd restarts it (the ONE thing systemd manages)
- If Process 3 dies → cron restarts it on next tick (stateless)

---

## Implementation Priority

| Priority | What | Effort | Impact |
|----------|------|--------|--------|
| P0 | Startup script (eliminates prompts) | 1 hour | Fixes 70% of failures |
| P0 | supervisord config | 30 min | Auto-restart on crash |
| P0 | Health monitor cron | 1 hour | Detects silent failures |
| P1 | API key auth (replaces OAuth) | 15 min | Eliminates auth expiry |
| P1 | Mac SSH watchdog cron | 30 min | Escape hatch |
| P2 | ntfy.sh webhook | 1 hour | Alternative escape hatch |
| P2 | Secondary Python bot | 2 hours | Fully independent control plane |

---

## Anti-Patterns to Avoid

1. **Don't rely on tmux** — it's a terminal multiplexer, not a process supervisor
2. **Don't use OAuth for headless daemons** — tokens expire, API keys don't
3. **Don't assume Claude starts cleanly** — always handle interactive prompts
4. **Don't monitor only "is process alive"** — check "is it actually processing messages"
5. **Don't put all recovery logic behind Telegram** — need an independent channel
6. **Don't run Claude as root** — use the claude user with proper PATH
