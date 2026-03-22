#!/usr/bin/env bash
# SessionEnd hook — auto-extract learning signals from the latest transcript.
# Runs in background so it doesn't block session teardown.

LOG_DIR="$HOME/.claude/logs"
SCRIPTS_DIR="$HOME/.claude/skills/reflect/scripts"
LOG_FILE="$LOG_DIR/auto-learn.log"

mkdir -p "$LOG_DIR"

_do_extract() {
  # Find the latest transcript for this session
  TRANSCRIPT=""

  # Try CLAUDE_SESSION_ID-based path first
  if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
    CANDIDATE=$(find "$HOME/.claude/projects" -name "${CLAUDE_SESSION_ID}.jsonl" 2>/dev/null | head -1)
    if [ -f "$CANDIDATE" ]; then
      TRANSCRIPT="$CANDIDATE"
    fi
  fi

  # Fall back: scope to the project-specific directory, exclude subagent files
  if [ -z "$TRANSCRIPT" ]; then
    # Derive the Claude project dir from cwd (same encoding Claude uses)
    PROJECT_KEY=$(echo "$PWD" | sed 's|/|-|g')
    PROJECT_DIR="$HOME/.claude/projects/${PROJECT_KEY}"

    # Find only top-level session transcripts (maxdepth 1), not subagent files
    TRANSCRIPT=$(find "$PROJECT_DIR" -maxdepth 1 -name "*.jsonl" 2>/dev/null \
      | xargs ls -t 2>/dev/null | head -1)
  fi

  if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] auto-learn: no transcript found" >> "$LOG_FILE"
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
