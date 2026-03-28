#!/usr/bin/env bash
set -euo pipefail

# Self-Improvement Sync — Ensures Mac and VPS share learning/skill improvements
# Runs on Mac after each self-improvement cron job.
# 1. Pulls latest from git (VPS pushes via config-sync-daemon)
# 2. Checks if VPS already ran the job today (skip duplicate work)
# 3. If VPS missed it (offline), Mac runs it as fallback
# 4. Pushes any Mac-side improvements back to git for VPS to pick up
#
# Cron: runs daily at 7:00 AM (1 hour after VPS's 6:03 AM consolidate)

LOG_FILE="$HOME/.claude/logs/self-improve-sync.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

REPO_DIR=""
for DIR in "$HOME/claude_super_setup" "$HOME/.claude-super-setup"; do
  [ -d "$DIR/.git" ] && REPO_DIR="$DIR" && break
done

if [ -z "$REPO_DIR" ]; then
  log "ERROR: No repo found"
  exit 1
fi

cd "$REPO_DIR"

# --- Step 1: Pull latest (get VPS improvements) ---
log "Pulling latest from remote..."
git pull --rebase --autostash >> "$LOG_FILE" 2>&1 || {
  log "WARN: git pull failed, continuing with local state"
}

# --- Step 2: Check if VPS ran the job ---
VPS_IP="187.77.15.168"
ENV_FILE="$HOME/.claude/.env.local"
VPS_PASS=""
if [ -f "$ENV_FILE" ]; then
  VPS_PASS=$(grep '^VPS_PASS=' "$ENV_FILE" 2>/dev/null | sed 's/^VPS_PASS=//' | tr -d '[:space:]' || echo "")
fi
if [ -z "$VPS_PASS" ]; then
  log "ERROR: VPS_PASS not set in $ENV_FILE. Add VPS_PASS=yourpassword to ~/.claude/.env.local"
  exit 1
fi

JOB_TYPE="${1:-consolidate}"  # consolidate | self-improve | evolve-skills
TODAY=$(date +%Y-%m-%d)

VPS_RAN="false"
VPS_LOG=$(sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 root@"$VPS_IP" \
  "su - claude -c \"grep '$TODAY' ~/.claude/logs/cron-${JOB_TYPE}.log 2>/dev/null | tail -1\"" 2>/dev/null || echo "")

if echo "$VPS_LOG" | grep -q "Completed with exit code: 0"; then
  VPS_RAN="true"
fi

if [ "$VPS_RAN" = "true" ]; then
  log "VPS already ran /$JOB_TYPE today ($TODAY). Skipping Mac fallback."
  exit 0
fi

# --- Step 3: VPS missed it — Mac runs as fallback ---
log "VPS did NOT run /$JOB_TYPE today. Running Mac fallback..."

RUNNER="$REPO_DIR/hooks/telegram-dispatch-runner.sh"
if [ -x "$RUNNER" ]; then
  CHAT_ID=$(grep '^TELEGRAM_CHAT_ID=' "$ENV_FILE" 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]' || echo "8328233140")
  bash "$RUNNER" "$JOB_TYPE" "" "$REPO_DIR" "mac-fallback-${JOB_TYPE}-$(date +%s)" "$CHAT_ID"
  log "Mac fallback dispatched for /$JOB_TYPE"
else
  log "ERROR: Runner not executable at $RUNNER"
  exit 1
fi

# --- Step 4: Push any changes back ---
cd "$REPO_DIR"
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "chore: self-improvement sync from Mac (fallback for $JOB_TYPE)" || true
  git push || log "WARN: git push failed"
  log "Pushed Mac improvements to remote"
fi
