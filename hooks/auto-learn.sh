#!/usr/bin/env bash
# SessionEnd hook — auto-extract learning signals from the latest transcript.
# Runs in background so it doesn't block session teardown.
set -euo pipefail

LOG_DIR="$HOME/.claude/logs"
SCRIPTS_DIR="$HOME/.claude/skills/reflect/scripts"
LOG_FILE="$LOG_DIR/auto-learn.log"

mkdir -p "$LOG_DIR"

_do_extract() {
  # Find the latest transcript for this session
  TRANSCRIPT=""

  # Strategy 1: Use CLAUDE_SESSION_ID if available
  if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
    CANDIDATE=$(find "$HOME/.claude/projects" -name "${CLAUDE_SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)
    if [ -f "$CANDIDATE" ]; then
      TRANSCRIPT="$CANDIDATE"
    fi
  fi

  # Strategy 2: Derive project dir from cwd using Claude's encoding (/ → -)
  if [ -z "$TRANSCRIPT" ]; then
    PROJECT_KEY=$(echo "$PWD" | sed 's|/|-|g')
    PROJECT_DIR="$HOME/.claude/projects/${PROJECT_KEY}"

    if [ -d "$PROJECT_DIR" ]; then
      # Find the most recently modified .jsonl file (top-level only, skip subagent dirs)
      TRANSCRIPT=$(find "$PROJECT_DIR" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null \
        | xargs ls -t 2>/dev/null | head -1)
    fi
  fi

  # Strategy 3: Search ALL project dirs for the most recent transcript (last resort)
  if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    TRANSCRIPT=$(find "$HOME/.claude/projects" -maxdepth 2 -name "*.jsonl" -type f \
      -newer "$HOME/.claude/logs/auto-learn.log" 2>/dev/null \
      | xargs ls -t 2>/dev/null | head -1)
  fi

  if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] auto-learn: no transcript found (pwd=$PWD, session_id=${CLAUDE_SESSION_ID:-unset})" >> "$LOG_FILE"
    return 0
  fi

  # Skip tiny transcripts (< 1KB = likely empty/aborted sessions)
  FILESIZE=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
  if [ "$FILESIZE" -lt 1024 ]; then
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] auto-learn: skipping tiny transcript ($FILESIZE bytes)" >> "$LOG_FILE"
    return 0
  fi

  PROJECT_DIR="$(pwd)"

  python3 "$SCRIPTS_DIR/auto_extract.py" "$TRANSCRIPT" --project-dir "$PROJECT_DIR" \
    >> "$LOG_FILE" 2>&1

  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] auto-learn: extraction complete transcript=$TRANSCRIPT" >> "$LOG_FILE"
}

# Run in background — never block session teardown
_do_extract &

exit 0
