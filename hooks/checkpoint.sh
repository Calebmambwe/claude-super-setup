#!/usr/bin/env bash
set -euo pipefail
# PreToolUse hook — creates a git stash checkpoint before destructive edits
# Only triggers for files matching critical patterns (not every edit)

FILE_PATH="${CLAUDE_FILE_PATH:-}"
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"

# Only checkpoint for Write/Edit operations
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Only checkpoint for important file types (not temp files, logs, etc.)
# Skip: node_modules, .git, dist, build, tmp, log files
case "$FILE_PATH" in
    */node_modules/*|*/.git/*|*/dist/*|*/build/*|*/tmp/*|*.log)
        echo '{"decision": "allow"}'
        exit 0
        ;;
esac

CHECKPOINT_DIR="$HOME/.claude/checkpoints"
mkdir -p "$CHECKPOINT_DIR"

# Create checkpoint every 20 edits (not every single one — too expensive)
EDIT_COUNT_FILE="$CHECKPOINT_DIR/.edit-count"
COUNT=$(cat "$EDIT_COUNT_FILE" 2>/dev/null || echo "0")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$EDIT_COUNT_FILE"

if (( COUNT % 20 == 0 )); then
    # Create a lightweight checkpoint using git stash
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    cd "$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        # Only stash if there are changes
        if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
            git stash push -m "checkpoint-$TIMESTAMP" --include-untracked 2>/dev/null || true
            git stash pop 2>/dev/null || true
            echo "$TIMESTAMP" >> "$CHECKPOINT_DIR/history.log"
            # Keep only last 50 checkpoints in log
            tail -50 "$CHECKPOINT_DIR/history.log" > "$CHECKPOINT_DIR/history.log.tmp" 2>/dev/null
            mv "$CHECKPOINT_DIR/history.log.tmp" "$CHECKPOINT_DIR/history.log" 2>/dev/null || true
        fi
    fi
fi

echo '{"decision": "allow"}'
