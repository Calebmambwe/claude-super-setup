#!/usr/bin/env bash
# overnight.sh — Run Claude automation unattended
# Usage:
#   ./overnight.sh                    # tmux session (default)
#   ./overnight.sh --nohup            # detached background process
#   ./overnight.sh --devcontainer     # inside Docker container (safest)

set -euo pipefail

PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/overnight-${PROJECT_NAME}-${TIMESTAMP}.log"
MODE="${1:---tmux}"

mkdir -p "$LOG_DIR"

# ── Pre-flight checks ──────────────────────────────────────────────

check_prereqs() {
  local errors=0

  if ! command -v claude &>/dev/null; then
    echo "ERROR: claude CLI not found. Install with: npm i -g @anthropic-ai/claude-code"
    errors=$((errors + 1))
  fi

  if ! command -v gh &>/dev/null; then
    echo "ERROR: gh CLI not found. Install with: brew install gh"
    errors=$((errors + 1))
  elif ! gh auth status &>/dev/null 2>&1; then
    echo "ERROR: gh CLI not authenticated. Run: gh auth login"
    errors=$((errors + 1))
  fi

  if [ ! -f "tasks.json" ]; then
    echo "ERROR: tasks.json not found. Run /auto-tasks or /init-tasks first."
    errors=$((errors + 1))
  fi

  local branch
  branch=$(git branch --show-current 2>/dev/null || echo "")
  if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    echo "ERROR: On $branch branch. Create a feature branch first."
    errors=$((errors + 1))
  fi

  # Check for unstaged changes in non-test files
  local dirty
  dirty=$(git diff --name-only -- ':!*.test.*' ':!*.spec.*' ':!__tests__/' 2>/dev/null | head -5)
  if [ -n "$dirty" ]; then
    echo "WARNING: Unstaged changes in non-test files:"
    echo "$dirty"
    echo "Consider committing or stashing before running overnight."
  fi

  if [ "$errors" -gt 0 ]; then
    echo ""
    echo "Fix the above errors before running overnight automation."
    exit 1
  fi
}

# ── The command Claude will run ─────────────────────────────────────

CLAUDE_PROMPT="Run /auto-build-all to complete all pending tasks. After all tasks are done (or stopped due to failures), run /check on all branch changes. If /check passes (no CRITICAL findings), run /ship to commit, push, and create a PR. If /check fails, stop and report the failures. Never auto-merge — always create a PR for human review."

# ── Mode: tmux ──────────────────────────────────────────────────────

run_tmux() {
  if ! command -v tmux &>/dev/null; then
    echo "ERROR: tmux not found. Install with: brew install tmux"
    echo "Or use: ./overnight.sh --nohup"
    exit 1
  fi

  local session_name="overnight-${PROJECT_NAME}"

  # Kill existing session if present
  tmux kill-session -t "$session_name" 2>/dev/null || true

  echo "Starting overnight automation in tmux session: $session_name"
  echo "Log: $LOG_FILE"
  echo ""
  echo "Attach with:  tmux attach -t $session_name"
  echo "Detach with:  Ctrl+B, then D"
  echo "Kill with:    tmux kill-session -t $session_name"

  tmux new-session -d -s "$session_name" -c "$PROJECT_DIR" \
    "claude -p --permission-mode auto \"$CLAUDE_PROMPT\" 2>&1 | tee \"$LOG_FILE\"; echo ''; echo 'Overnight run complete. Press Enter to close.'; read"
}

# ── Mode: nohup ─────────────────────────────────────────────────────

run_nohup() {
  echo "Starting overnight automation as background process..."
  echo "Log: $LOG_FILE"
  echo ""
  echo "Monitor with:  tail -f $LOG_FILE"
  echo "Stop with:     kill \$(cat $LOG_DIR/overnight.pid)"

  nohup bash -c "cd \"$PROJECT_DIR\" && claude -p --permission-mode auto \"$CLAUDE_PROMPT\" > \"$LOG_FILE\" 2>&1" &
  echo $! > "$LOG_DIR/overnight.pid"
  echo "PID: $!"
}

# ── Mode: devcontainer ──────────────────────────────────────────────

run_devcontainer() {
  if [ ! -f ".devcontainer/devcontainer.json" ]; then
    echo "ERROR: No .devcontainer/devcontainer.json found."
    echo "Run /new-project or create a devcontainer config first."
    exit 1
  fi

  if ! command -v devcontainer &>/dev/null; then
    echo "ERROR: devcontainer CLI not found."
    echo "Install with: npm i -g @devcontainers/cli"
    exit 1
  fi

  echo "Starting overnight automation in devcontainer..."
  echo "Log: $LOG_FILE"
  echo "This provides filesystem isolation — safest mode."

  devcontainer exec --workspace-folder "$PROJECT_DIR" \
    bash -c "claude -p --permission-mode auto \"$CLAUDE_PROMPT\" 2>&1 | tee \"$LOG_FILE\""
}

# ── Main ────────────────────────────────────────────────────────────

echo "Overnight Automation — $PROJECT_NAME"
echo "=================================="
echo ""

check_prereqs

case "$MODE" in
  --tmux)
    run_tmux
    ;;
  --nohup)
    run_nohup
    ;;
  --devcontainer)
    run_devcontainer
    ;;
  *)
    echo "Usage: ./overnight.sh [--tmux | --nohup | --devcontainer]"
    echo "  --tmux          tmux session (default, recommended)"
    echo "  --nohup         detached background process"
    echo "  --devcontainer  inside Docker container (safest)"
    exit 1
    ;;
esac
