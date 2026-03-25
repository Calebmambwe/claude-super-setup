# VPS Setup Guide — Claude Super Setup

Deploy your full AI development platform to any Ubuntu VPS in under 15 minutes.

---

## Prerequisites

- Ubuntu 24.04 LTS VPS (minimum 4GB RAM, 2 vCPU)
- SSH access to the VPS
- Your Mac (to generate the auth token)

## Step 1: Generate Auth Token (on your Mac)

```bash
claude setup-token
```

This generates a one-year OAuth token. Copy it — you'll need it on the VPS.

## Step 2: SSH into VPS and Run Setup

### Option A: Standard Setup

```bash
curl -sSL https://raw.githubusercontent.com/Calebmambwe/claude-super-setup/main/scripts/setup-vps.sh | bash
```

### Option B: With Local Models (Ollama)

```bash
curl -sSL https://raw.githubusercontent.com/Calebmambwe/claude-super-setup/main/scripts/setup-vps.sh | bash -s -- --with-ollama
```

### Option C: Dry Run (test without installing)

```bash
curl -sSL https://raw.githubusercontent.com/Calebmambwe/claude-super-setup/main/scripts/setup-vps.sh | bash -s -- --dry-run
```

## Step 3: Set API Keys

After the setup script runs, set your API keys:

```bash
# Required — Claude authentication
export CLAUDE_CODE_OAUTH_TOKEN="<paste-token-from-step-1>"
echo 'export CLAUDE_CODE_OAUTH_TOKEN="<your-token>"' >> ~/.bashrc

# Required — Anthropic API (fallback auth)
export ANTHROPIC_API_KEY="<your-key>"
echo 'export ANTHROPIC_API_KEY="<your-key>"' >> ~/.bashrc

# Optional — Gemini (image/video generation)
echo 'GEMINI_API_KEY=<your-key>' >> ~/.claude/.env.local

# Optional — OpenAI (Whisper voice transcription)
echo 'OPENAI_API_KEY=<your-key>' >> ~/.claude/.env.local

# Optional — Manus.ai (agent collaboration)
echo 'MANUS_API_KEY=<your-key>' >> ~/.claude/.env.local

# Required — Telegram bot
mkdir -p ~/.claude/channels/telegram
echo 'TELEGRAM_BOT_TOKEN=<your-bot-token>' > ~/.claude/channels/telegram/.env
chmod 600 ~/.claude/channels/telegram/.env

# Set Telegram access (your Telegram user ID)
echo '{"dmPolicy":"allowlist","allowFrom":["<your-telegram-user-id>"],"groups":{},"pending":{}}' > ~/.claude/channels/telegram/access.json
```

## Step 4: Start Services

```bash
# Enable and start all services
sudo systemctl daemon-reload
sudo systemctl enable claude-telegram@$USER
sudo systemctl enable claude-learning@$USER
sudo systemctl start claude-telegram@$USER
sudo systemctl start claude-learning@$USER

# Optional: Start Ollama (if installed with --with-ollama)
sudo systemctl enable ollama
sudo systemctl start ollama
```

## Step 5: Verify Everything Works

```bash
# Check services
systemctl status claude-telegram@$USER
systemctl status claude-learning@$USER

# Check Claude Code
claude --version

# Run health check
bash ~/.claude-super-setup/scripts/inventory-check.sh

# Test Telegram connection (send a message to your bot)
# Then check: journalctl -u claude-telegram@$USER -f
```

---

## What Gets Installed

| Component | Details |
|-----------|---------|
| **Node.js 22 LTS** | Via nvm |
| **Python 3.12** | Via uv |
| **Claude Code CLI** | `npm install -g @anthropic-ai/claude-code` |
| **Docker** | For sandbox execution |
| **tmux + screen** | Persistent sessions |
| **jq** | JSON processing |
| **ffmpeg** | Voice message conversion (OGG to MP3) |
| **Tailscale** | Optional, secure remote access |
| **Ollama** | Optional, local models (llama3, codellama) |

## What Gets Configured

| Component | Count | Description |
|-----------|-------|-------------|
| Commands | 86 | Full SDLC pipeline, Telegram dispatch, personal assistant |
| Hooks | 19 | Auto-quality, telemetry, alerts, branch guard, session management |
| Agents | 50+ | Specialized agents (frontend, backend, security, testing, etc.) |
| Skills | 6 | Design system, backend architecture, BMAD, Docker, meta-rules, reflect |
| MCP Servers | 4 | context7, learning ledger, sandbox, Gemini |
| Systemd Services | 3 | Telegram listener, learning server, sandbox server |

---

## Daily Usage from Phone (Telegram)

Once running on VPS, you can do everything from Telegram:

### Natural Language (NLP Router)

```
"build me a habit tracker app"     → auto-routes to /auto-develop
"fix the login bug in twendai"     → auto-routes to /debug
"how's the build going"            → auto-routes to /ghost-status
"check the code quality"           → auto-routes to /check
"what's on my calendar today"      → auto-routes to /morning-brief
```

### Slash Commands

```
/ghost "feature description"       — autonomous overnight pipeline
/auto-develop "raw idea"           — full SDLC: research → ship
/check                             — code review + security + tests
/ship                              — commit + PR
/ghost-status                      — pipeline dashboard
/queue                             — task queue status
/morning-brief                     — daily briefing
/eod-summary                       — end of day summary
/weekly-health                     — all projects health report
/prototype "UI description"        — generate mockup images (Gemini)
/demo-video "app walkthrough"      — generate video demos (Veo)
/flag create "feature-name"        — manage feature flags
/cancel <session>                  — kill a running task
/parallel "/check" "/auto-build"   — run tasks concurrently
```

### Voice Messages

Send a voice note on Telegram — it gets transcribed via Whisper and processed as text. Speak your scattered thoughts, get structured requirements back.

---

## Monitoring & Alerts

The system sends automatic Telegram notifications for:

| Alert | Trigger |
|-------|---------|
| Ghost progress | Every phase transition (start, build, check, ship) |
| Ghost monitor | Status update every 5 minutes while running |
| Token spike | >20% above 7-day average |
| Tool errors | >10% failure rate in 5-minute window |
| Stale ghost | >2 hours without a commit |
| CRITICAL action | Any high-risk action without explicit approval |

---

## Security

| Measure | Details |
|---------|---------|
| **API keys** | Stored in `~/.claude/.env.local` (chmod 600, gitignored) |
| **Telegram** | Allowlist-only access (your user ID only) |
| **VPS firewall** | UFW: SSH + Tailscale only |
| **Brute force** | fail2ban enabled |
| **Permissions** | `permissions.deny` blocks rm -rf, sudo, force push, eval, curl pipe sh |
| **Command allowlist** | Telegram dispatch only accepts whitelisted commands |
| **Path validation** | Dispatch runner validates PROJECT_DIR stays under $HOME |

---

## Troubleshooting

### Telegram bot not responding

```bash
# Check the service
sudo systemctl status claude-telegram@$USER

# Check for zombie bot processes (409 conflict)
pkill -f "bun.*telegram.*server.ts"
sudo systemctl restart claude-telegram@$USER
```

### Ghost Mode stuck

```bash
# Emergency stop
touch ~/.claude/ghost-stop

# Check what's running
screen -ls
```

### MCP server not connecting

```bash
# Restart learning server
sudo systemctl restart claude-learning@$USER

# Check logs
journalctl -u claude-learning@$USER --since "5 min ago"
```

### Ollama models not loading

```bash
# Check Ollama service
sudo systemctl status ollama

# Pull models manually
ollama pull llama3
ollama pull codellama
```

---

## Architecture

```
Phone (Telegram)
    │
    ▼
VPS (Ubuntu 24.04)
    ├── Claude Code CLI (claude)
    │   ├── 86 commands (symlinked from ~/.claude-super-setup/)
    │   ├── 19 hooks (auto-quality, telemetry, alerts)
    │   ├── 50+ agents (specialized roles)
    │   └── 4 MCP servers (context7, learning, sandbox, gemini)
    │
    ├── systemd services
    │   ├── claude-telegram@.service (persistent listener)
    │   ├── claude-learning@.service (learning MCP)
    │   └── claude-sandbox@.service (sandbox MCP)
    │
    ├── Ghost Mode (screen sessions)
    │   ├── ghost-watchdog.sh (crash recovery, 3 max attempts)
    │   └── ghost-notify.sh (triple-channel: macOS + ntfy + Telegram)
    │
    ├── Telegram Dispatch
    │   ├── telegram-dispatch.md (NLP router)
    │   ├── telegram-dispatch-runner.sh (session spawner)
    │   └── telegram-queue.json (task queue)
    │
    └── Ollama (optional)
        ├── llama3 (general tasks)
        └── codellama (code tasks)
```

---

## Repo

**Single source of truth:** https://github.com/Calebmambwe/claude-super-setup

```bash
# Update your VPS installation
cd ~/.claude-super-setup && git pull origin main
```

---

*Generated 2026-03-24 by Claude Code (Opus 4.6)*
