#!/usr/bin/env bash
set -euo pipefail

# Config Sync Daemon — runs on BOTH Mac and VPS via cron
# Keeps claude-super-setup repo in sync across all machines.
# Mac pushes changes → GitHub → VPS pulls. VPS auto-commits local changes → pushes → Mac pulls.
#
# Cron: */5 * * * * /path/to/scripts/config-sync-daemon.sh
#
# Safe: uses git merge (not force), fails gracefully on conflicts.

LOG_FILE="$HOME/.claude/logs/config-sync.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# --- Find repo ---
REPO_DIR=""
for DIR in "$HOME/.claude-super-setup" "$HOME/claude_super_setup"; do
  if [ -d "$DIR/.git" ]; then
    REPO_DIR="$DIR"
    break
  fi
done

if [ -z "$REPO_DIR" ]; then
  log "ERROR: No git repo found"
  exit 1
fi

cd "$REPO_DIR"

# --- Detect machine ---
IS_VPS=false
[ "$(uname)" != "Darwin" ] && IS_VPS=true
MACHINE=$(hostname -s)

# --- Step 1: Fetch latest ---
git fetch -q origin 2>/dev/null || { log "WARN: git fetch failed (offline?)"; exit 0; }

# --- Step 2: Check if we're behind remote ---
LOCAL=$(git rev-parse HEAD 2>/dev/null)
REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "")

if [ -z "$REMOTE" ]; then
  log "WARN: Could not resolve origin/main"
  exit 0
fi

# --- Step 3: Pull if behind ---
if [ "$LOCAL" != "$REMOTE" ]; then
  # Check for local uncommitted changes first
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    # Stash local changes, pull, then pop
    git stash -q 2>/dev/null || true
    git pull -q --rebase origin main 2>/dev/null && log "PULLED: updated from remote (with stash)" || log "WARN: pull failed"
    git stash pop -q 2>/dev/null || true
  else
    git pull -q origin main 2>/dev/null && log "PULLED: updated from remote" || log "WARN: pull failed"
  fi
fi

# --- Step 4: Check for local changes to push ---
# Only auto-commit+push certain safe directories
CHANGED=false
for SAFE_DIR in docs/ scripts/ agents/ config/; do
  if [ -n "$(git status --porcelain "$SAFE_DIR" 2>/dev/null)" ]; then
    CHANGED=true
    break
  fi
done

if $CHANGED; then
  # Auto-commit safe changes
  git add docs/ scripts/ agents/ config/ 2>/dev/null || true

  if ! git diff --cached --quiet 2>/dev/null; then
    git commit -q -m "sync: auto-commit from $MACHINE $(date +%Y%m%d-%H%M)

Co-Authored-By: Config Sync Daemon <sync@claude-super-setup>" 2>/dev/null

    git push -q origin main 2>/dev/null && log "PUSHED: local changes from $MACHINE" || log "WARN: push failed (conflict?)"
  fi
fi

# --- Step 5: Touch sentinel for running Claude sessions ---
if $IS_VPS; then
  touch "$HOME/.claude/.config-updated" 2>/dev/null || true
fi

# --- Step 6: Trim log (keep last 500 lines) ---
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 1000 ]; then
  tail -500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
