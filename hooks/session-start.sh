#!/usr/bin/env bash
# Session start hook — runs when a new Claude Code session begins
# Checks environment health and logs session start

set -euo pipefail

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

SESSION_LOG="$LOG_DIR/sessions.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Log session start
echo "[$TIMESTAMP] SESSION_START dir=$(pwd)" >> "$SESSION_LOG"

# Rotate log if over 1000 lines
if [ -f "$SESSION_LOG" ] && [ "$(wc -l < "$SESSION_LOG")" -gt 1000 ]; then
  tail -500 "$SESSION_LOG" > "$SESSION_LOG.tmp" && mv "$SESSION_LOG.tmp" "$SESSION_LOG"
fi

# Check for common environment issues
WARNINGS=""

# Check if git is available
if ! command -v git &>/dev/null; then
  WARNINGS="${WARNINGS}WARNING: git not found in PATH\n"
fi

# Check if node is available
if ! command -v node &>/dev/null; then
  WARNINGS="${WARNINGS}WARNING: node not found in PATH\n"
fi

# Check if pnpm is available
if ! command -v pnpm &>/dev/null; then
  WARNINGS="${WARNINGS}NOTE: pnpm not found — install with 'npm i -g pnpm' if needed\n"
fi

# Check if uv is available (Python projects)
if [ -f "pyproject.toml" ] && ! command -v uv &>/dev/null; then
  WARNINGS="${WARNINGS}WARNING: uv not found — install with 'curl -LsSf https://astral.sh/uv/install.sh | sh'\n"
fi

# Check if docker is available
if ! command -v docker &>/dev/null; then
  WARNINGS="${WARNINGS}NOTE: docker not found — devcontainer workflows unavailable\n"
fi

# Check if gh CLI is available and authenticated
if ! command -v gh &>/dev/null; then
  WARNINGS="${WARNINGS}NOTE: gh CLI not found — GitHub operations unavailable\n"
elif ! gh auth status &>/dev/null; then
  WARNINGS="${WARNINGS}WARNING: gh CLI not authenticated — run 'gh auth login' for GitHub integration\n"
fi

# Check if VS Code CLI is available
if ! command -v code &>/dev/null; then
  WARNINGS="${WARNINGS}NOTE: VS Code 'code' CLI not in PATH — run 'Install code command in PATH' from VS Code\n"
fi

# Check Node version matches .nvmrc if present
if [ -f ".nvmrc" ] && command -v node &>/dev/null; then
  EXPECTED=$(cat .nvmrc | tr -d '[:space:]')
  ACTUAL=$(node -v | sed 's/v//' | cut -d. -f1)
  if [ "$EXPECTED" != "$ACTUAL" ]; then
    WARNINGS="${WARNINGS}WARNING: Node version mismatch — .nvmrc expects $EXPECTED, running $ACTUAL\n"
  fi
fi

# Check disk space (warn if <1GB free)
if command -v df &>/dev/null; then
  FREE_KB=$(df -k "$HOME" | tail -1 | awk '{print $4}')
  if [ "$FREE_KB" -lt 1048576 ] 2>/dev/null; then
    WARNINGS="${WARNINGS}WARNING: Low disk space (<1GB free on home partition)\n"
  fi
fi

# Output warnings if any
if [ -n "$WARNINGS" ]; then
  echo -e "$WARNINGS"
fi

# Check tasks.json state
if [ -f "tasks.json" ]; then
  PENDING=$(grep -c '"pending"' tasks.json 2>/dev/null || echo 0)
  COMPLETED=$(grep -c '"completed"' tasks.json 2>/dev/null || echo 0)
  if [ "$PENDING" -eq 0 ] && [ "$COMPLETED" -gt 0 ]; then
    echo "NOTE: tasks.json — all $COMPLETED tasks complete. Run /auto-tasks to generate new ones."
  elif [ "$PENDING" -gt 0 ]; then
    echo "NOTE: tasks.json — $PENDING pending, $COMPLETED completed. Run /auto-build to continue."
  fi
fi

# Check if learning consolidation is overdue (>7 days)
LAST_CONSOLIDATION="$HOME/.claude/reflect/last-consolidation.timestamp"
if [ ! -f "$LAST_CONSOLIDATION" ]; then
  echo "NOTE: Learning consolidation has never been run. Run /consolidate to review and promote learnings."
else
  if [[ "$(uname)" == "Darwin" ]]; then
    FILE_MTIME=$(stat -f %m "$LAST_CONSOLIDATION" 2>/dev/null || echo 0)
  else
    FILE_MTIME=$(stat -c %Y "$LAST_CONSOLIDATION" 2>/dev/null || echo 0)
  fi
  if [ "$(( $(date +%s) - $FILE_MTIME ))" -gt 604800 ]; then
    echo "NOTE: Learning consolidation overdue (>7 days). Run /consolidate."
  fi
fi
