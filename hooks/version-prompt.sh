#!/usr/bin/env bash
# version-prompt.sh — archive a prompt file before it's overwritten
#
# Triggered by PreToolUse hook on Write(**/prompts/milestone-*.md) etc.
# If the target file already exists, copy it to .archive/ with a timestamp suffix.
# If it doesn't exist, this is a first write — no-op.
#
# Environment variables set by Claude Code:
#   CLAUDE_FILE_PATH — absolute path of the file about to be written

set -euo pipefail

TARGET="${CLAUDE_FILE_PATH:-}"

if [[ -z "$TARGET" ]]; then
  # No file path provided — nothing to do
  exit 0
fi

if [[ ! -f "$TARGET" ]]; then
  # File doesn't exist yet — first write, no archiving needed
  exit 0
fi

# Build archive path: same dir as prompts/ but inside .archive/
PROMPTS_DIR="$(dirname "$TARGET")"
ARCHIVE_DIR="${PROMPTS_DIR}/.archive"
BASENAME="$(basename "$TARGET" .md)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_FILE="${ARCHIVE_DIR}/${BASENAME}.${TIMESTAMP}.md"

mkdir -p "$ARCHIVE_DIR"
cp "$TARGET" "$ARCHIVE_FILE"

echo "[version-prompt] Archived: $(basename "$TARGET") → .archive/$(basename "$ARCHIVE_FILE")"
exit 0
