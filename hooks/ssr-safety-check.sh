#!/bin/bash
# PostToolUse: Warn about Framer Motion patterns that can cause invisible above-fold content on SSR.
# Checks for initial={{ opacity: 0 }} or initial="hidden" without a whileInView counterpart.
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only act on Write and Edit tool calls
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# Only check .tsx files
if [[ "$FILE_PATH" != *.tsx ]]; then
  exit 0
fi

# File must exist on disk (PostToolUse — it has been written)
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

FILE_CONTENT=$(cat "$FILE_PATH")

# Check for risky Framer Motion initial patterns
HAS_OPACITY_ZERO=false
HAS_HIDDEN_INITIAL=false

if echo "$FILE_CONTENT" | grep -qE 'initial=\{\{[^\}]*opacity[[:space:]]*:[[:space:]]*0'; then
  HAS_OPACITY_ZERO=true
fi

if echo "$FILE_CONTENT" | grep -qF 'initial="hidden"'; then
  HAS_HIDDEN_INITIAL=true
fi

# If neither pattern present, we're done
if [[ "$HAS_OPACITY_ZERO" == "false" && "$HAS_HIDDEN_INITIAL" == "false" ]]; then
  exit 0
fi

# Check whether the same motion elements have whileInView (safe pattern)
HAS_WHILE_IN_VIEW=false
if echo "$FILE_CONTENT" | grep -qF 'whileInView='; then
  HAS_WHILE_IN_VIEW=true
fi

# Determine if this file is likely above-fold:
# Check if it is directly imported by page.tsx or layout.tsx in the same directory tree
FILE_DIR=$(dirname "$FILE_PATH")
PROJECT_ROOT="$FILE_DIR"
while [[ "$PROJECT_ROOT" != "/" && ! -f "$PROJECT_ROOT/package.json" ]]; do
  PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

IS_ABOVE_FOLD=false
if [[ -f "$PROJECT_ROOT/package.json" ]]; then
  BASENAME=$(basename "$FILE_PATH")
  COMPONENT_NAME="${BASENAME%.tsx}"
  # Search page.tsx and layout.tsx files for an import of this component
  while IFS= read -r -d '' page_file; do
    if grep -q "$COMPONENT_NAME" "$page_file" 2>/dev/null; then
      IS_ABOVE_FOLD=true
      break
    fi
  done < <(find "$PROJECT_ROOT" \( -name "page.tsx" -o -name "layout.tsx" \) -print0 2>/dev/null)
fi

# Build warning message
WARN_PARTS=()

if [[ "$HAS_OPACITY_ZERO" == "true" && "$HAS_WHILE_IN_VIEW" == "false" ]]; then
  WARN_PARTS+=("initial={{ opacity: 0 }} without whileInView — element may stay invisible if JS is slow")
fi

if [[ "$HAS_HIDDEN_INITIAL" == "true" && "$HAS_WHILE_IN_VIEW" == "false" ]]; then
  WARN_PARTS+=('initial="hidden" without whileInView — element may stay invisible if JS is slow')
fi

if [[ "$IS_ABOVE_FOLD" == "true" ]]; then
  WARN_PARTS+=("above-fold content detected — consider initial={false} to prevent invisible content on SSR")
fi

if [[ ${#WARN_PARTS[@]} -gt 0 ]]; then
  echo "SSR safety warning in '$FILE_PATH':" >&2
  for msg in "${WARN_PARTS[@]}"; do
    echo "  - $msg" >&2
  done
  exit 2
fi

exit 0
