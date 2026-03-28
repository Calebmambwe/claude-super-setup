#!/bin/bash
# Self-Improvement System Health Check
# Verifies all self-improvement crons are working on both MAC and VPS
# Reports status via Telegram

set -euo pipefail

LOG="$HOME/.claude/logs/self-improve-check.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

VPS_IP="187.77.15.168"
VPS_PASS=$(grep '^VPS_PASS=' ~/.claude/.env.local 2>/dev/null | sed 's/^VPS_PASS=//' | tr -d '[:space:]' || echo "")
if [ -z "$VPS_PASS" ]; then
  log "ERROR: VPS_PASS not set in ~/.claude/.env.local"
  echo "ERROR: VPS_PASS not set"
  exit 1
fi
VPS_BOT_TOKEN=$(grep 'VPS_BOT_TOKEN=' ~/.claude/.env.local 2>/dev/null | sed 's/^VPS_BOT_TOKEN=//' | tr -d '[:space:]')
MAC_BOT_TOKEN=$(grep 'MAC_BOT_TOKEN=' ~/.claude/.env.local 2>/dev/null | sed 's/^MAC_BOT_TOKEN=//' | tr -d '[:space:]')
CHAT_ID=$(grep 'TELEGRAM_CHAT_ID=' ~/.claude/.env.local 2>/dev/null | sed 's/^TELEGRAM_CHAT_ID=//' | tr -d '[:space:]')

STATUS="[Self-Improvement Health Check]\n"

# Check MAC crons
MAC_CRONS=$(crontab -l 2>/dev/null | grep -c "self-improve\|consolidate\|evolve\|anthropic-docs" || echo "0")
STATUS+="MAC crons active: $MAC_CRONS\n"

# Check MAC learning ledger (SQLite DB via reflect system)
LEARNINGS=$(python3 -c "
import sqlite3, os
db = os.path.expanduser('~/.claude/reflect/learnings.db')
if os.path.exists(db):
    conn = sqlite3.connect(db)
    print(conn.execute('SELECT COUNT(*) FROM learnings').fetchone()[0])
    conn.close()
else:
    print(0)
" 2>/dev/null || echo "0")
STATUS+="MAC learnings recorded: $LEARNINGS\n"

# Check VPS status
VPS_STATUS=$(sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$VPS_IP "
echo \"VPS uptime: \$(uptime -p 2>/dev/null || uptime)\"
echo \"VPS Claude sessions: \$(sudo -u claude tmux ls 2>/dev/null | wc -l)\"
echo \"VPS learnings: \$(cat /home/claude/.claude/learning-ledger.json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d.get(\"learnings\",[])))' 2>/dev/null || echo 0)\"
echo \"VPS impactos build: \$(sudo -u claude tmux ls 2>/dev/null | grep impactos && echo RUNNING || echo STOPPED)\"
" 2>&1 || echo "VPS unreachable")

STATUS+="$VPS_STATUS\n"

# Check Anthropic docs cache
DOCS_CACHED=$(ls ~/.claude/cache/anthropic-docs/*.txt 2>/dev/null | wc -l || echo "0")
STATUS+="Anthropic docs cached: $DOCS_CACHED pages\n"

# Check last monitor run
LAST_RUN=$(tail -1 ~/.claude/logs/anthropic-monitor.log 2>/dev/null | head -c 25 || echo "never")
STATUS+="Last docs check: $LAST_RUN\n"

# Check config sync
SYNC_OK=$(diff <(cat ~/.claude/settings.json) <(sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$VPS_IP "cat /home/claude/.claude/settings.json" 2>/dev/null) > /dev/null 2>&1 && echo "IN SYNC" || echo "OUT OF SYNC")
STATUS+="Config MAC↔VPS: $SYNC_OK"

# Send report
if [ -n "$VPS_BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
  curl -s -X POST "https://api.telegram.org/bot${VPS_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=$(echo -e "$STATUS")" > /dev/null 2>&1
fi

log "Health check complete"
echo -e "$STATUS"
