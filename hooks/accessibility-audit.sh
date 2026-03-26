#!/bin/bash
# PostToolUse: Warn about basic accessibility issues in .tsx files.
# Checks: missing alt on <img>, unlabelled <button>, unlabelled <input>,
#         onClick on non-interactive elements without role="button" + tabIndex.
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

ISSUES=""

# ── Check 1: <img without alt= ────────────────────────────────────────────────
# Match <img tags that do NOT have alt= anywhere on the same tag open.
# Strategy: grab every <img ... > block, then check if alt= is absent.
IMG_WITHOUT_ALT=$(grep -n '<img\b' "$FILE_PATH" | grep -v 'alt=' || true)
if [[ -n "$IMG_WITHOUT_ALT" ]]; then
  while IFS= read -r line; do
    ISSUES="${ISSUES}\n  [img-alt]   ${line}"
  done <<< "$IMG_WITHOUT_ALT"
fi

# ── Check 2: <button with no text content and no aria-label ──────────────────
# Look for self-closing buttons or empty buttons: <button ... /> or <button ...></button>
# Also flag buttons where the opening tag has no aria-label and no visible text on the same line.
EMPTY_BUTTON=$(grep -n '<button\b' "$FILE_PATH" | grep -v 'aria-label' | grep -E '(/>|></button>|>\s*</button>)' || true)
if [[ -n "$EMPTY_BUTTON" ]]; then
  while IFS= read -r line; do
    ISSUES="${ISSUES}\n  [button-label] ${line}"
  done <<< "$EMPTY_BUTTON"
fi

# ── Check 3: <input without aria-label, aria-labelledby, or nearby <label ────
# Flag <input tags missing both aria-label= and aria-labelledby=.
# (We cannot check for a nearby <label reliably with grep, so we warn when
# both aria attributes are absent — the developer should verify a <label exists.)
INPUT_WITHOUT_LABEL=$(grep -n '<input\b' "$FILE_PATH" | grep -v 'aria-label' | grep -v 'aria-labelledby' | grep -v 'type="hidden"' | grep -v "type='hidden'" || true)
if [[ -n "$INPUT_WITHOUT_LABEL" ]]; then
  while IFS= read -r line; do
    ISSUES="${ISSUES}\n  [input-label] ${line}"
  done <<< "$INPUT_WITHOUT_LABEL"
fi

# ── Check 4: onClick on non-interactive elements without role+tabIndex ────────
# Match div or span tags that have onClick but lack role="button" and tabIndex.
CLICKABLE_DIV=$(grep -n 'onClick' "$FILE_PATH" | grep -E '<(div|span)\b' | grep -v 'role=' | grep -v 'tabIndex' || true)
if [[ -n "$CLICKABLE_DIV" ]]; then
  while IFS= read -r line; do
    ISSUES="${ISSUES}\n  [interactive-role] ${line}"
  done <<< "$CLICKABLE_DIV"
fi

# ── Report ────────────────────────────────────────────────────────────────────
if [[ -n "$ISSUES" ]]; then
  echo -e "Accessibility warning in '${FILE_PATH}':\n${ISSUES}\n\nFix: add alt text, aria-label/aria-labelledby, or role=\"button\" + tabIndex={0} as appropriate." >&2
  exit 2
fi

exit 0
