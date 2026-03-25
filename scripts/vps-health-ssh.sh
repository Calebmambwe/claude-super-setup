#!/usr/bin/env bash
set -euo pipefail

# VPS Health SSH Watchdog — runs on Mac via cron every 15 minutes
# Checks if the VPS Telegram listener is alive. If not, restarts it.
# This is the escape hatch when Telegram itself is down.
#
# Usage: bash scripts/vps-health-ssh.sh [--dry-run]

LOG_FILE="$HOME/.claude/logs/vps-health.log"
mkdir -p "$(dirname "$LOG_FILE")"

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# --- Load credentials ---
ENV_FILE="$HOME/.claude/.env.local"
if [ ! -f "$ENV_FILE" ]; then
  log "FATAL: $ENV_FILE not found"
  exit 1
fi

VPS_IP="187.77.15.168"
VPS_PASS=$(grep '^VPS_PASS=' "$ENV_FILE" 2>/dev/null | sed 's/^VPS_PASS=//' | tr -d '[:space:]' || echo "")
VPS_BOT_TOKEN=$(grep '^VPS_BOT_TOKEN=' "$ENV_FILE" | sed 's/^VPS_BOT_TOKEN=//' | tr -d '[:space:]')
CHAT_ID=$(grep '^TELEGRAM_CHAT_ID=' "$ENV_FILE" | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]')

# Fallback: try sshpass with known password if VPS_PASS not set
if [ -z "$VPS_PASS" ]; then
  VPS_PASS="7c8;mnJ9Fn3d5FXP"
fi

SSH_CMD="sshpass -p '$VPS_PASS' ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 root@$VPS_IP"

notify_telegram() {
  local MSG="$1"
  curl -s --max-time 10 -X POST "https://api.telegram.org/bot${VPS_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${MSG}" > /dev/null 2>&1 || true
}

# --- Step 1: Check if VPS is reachable ---
if ! eval "$SSH_CMD 'echo ok'" > /dev/null 2>&1; then
  log "UNREACHABLE: Cannot SSH to VPS $VPS_IP"
  notify_telegram "ALERT: VPS $VPS_IP is unreachable via SSH. Cannot auto-heal."
  exit 1
fi

log "VPS reachable"

# --- Step 2: Check if Claude Telegram listener is running ---
LISTENER_STATUS=$(eval "$SSH_CMD '
  # Check for tmux session
  TMUX_OK=false
  su - claude -c \"tmux has-session -t claude-telegram 2>/dev/null\" && TMUX_OK=true

  # Check for bun telegram server process
  BUN_OK=false
  pgrep -u claude -f \"bun.*server.ts\" > /dev/null 2>&1 && BUN_OK=true

  # Check for claude process with channels
  CLAUDE_OK=false
  pgrep -u claude -f \"channels.*telegram\" > /dev/null 2>&1 && CLAUDE_OK=true

  echo \"tmux=\$TMUX_OK bun=\$BUN_OK claude=\$CLAUDE_OK\"
'" 2>/dev/null || echo "tmux=false bun=false claude=false")

log "Status: $LISTENER_STATUS"

TMUX_OK=$(echo "$LISTENER_STATUS" | grep -o 'tmux=[a-z]*' | cut -d= -f2)
BUN_OK=$(echo "$LISTENER_STATUS" | grep -o 'bun=[a-z]*' | cut -d= -f2)
CLAUDE_OK=$(echo "$LISTENER_STATUS" | grep -o 'claude=[a-z]*' | cut -d= -f2)

# --- Step 3: If everything is healthy, exit ---
if [ "$TMUX_OK" = "true" ] && [ "$BUN_OK" = "true" ]; then
  log "HEALTHY: All processes running"
  exit 0
fi

# --- Step 4: Something is down — restart ---
log "UNHEALTHY: tmux=$TMUX_OK bun=$BUN_OK claude=$CLAUDE_OK — restarting..."

if $DRY_RUN; then
  log "[DRY RUN] Would restart VPS Telegram listener"
  echo "Would restart: tmux=$TMUX_OK bun=$BUN_OK claude=$CLAUDE_OK"
  exit 0
fi

# Kill any stuck processes first
eval "$SSH_CMD '
  su - claude -c \"tmux kill-session -t claude-telegram 2>/dev/null\" || true
  sleep 2

  # Start fresh
  CLAUDE_BIN=\"/home/claude/.nvm/versions/node/v22.22.2/bin/claude\"
  su - claude -s /bin/bash -c \"export PATH=/home/claude/.nvm/versions/node/v22.22.2/bin:/home/claude/.bun/bin:\\\$PATH && cd /home/claude && tmux new-session -d -s claude-telegram \\\"\$CLAUDE_BIN --dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official\\\"\"
  sleep 5

  # Auto-approve trust prompt (send Enter)
  su - claude -c \"tmux send-keys -t claude-telegram Enter\" 2>/dev/null || true
  sleep 3

  # Auto-approve effort prompt (send Enter)
  su - claude -c \"tmux send-keys -t claude-telegram Enter\" 2>/dev/null || true
  sleep 8

  # Verify
  RUNNING=false
  pgrep -u claude -f \"bun.*server.ts\" > /dev/null 2>&1 && RUNNING=true
  echo \"restart_result=\$RUNNING\"
'" 2>/dev/null

RESULT=$(eval "$SSH_CMD 'pgrep -u claude -f \"bun.*server.ts\" > /dev/null 2>&1 && echo ok || echo failed'" 2>/dev/null || echo "failed")

if [ "$RESULT" = "ok" ]; then
  log "HEALED: VPS Telegram listener restarted successfully"
  notify_telegram "VPS watchdog (Mac): Telegram listener was down. Auto-restarted successfully."
else
  log "FAILED: Could not restart VPS Telegram listener"
  notify_telegram "ALERT: VPS Telegram listener is DOWN and auto-restart FAILED. Manual SSH required: ssh root@$VPS_IP"
fi
