#!/bin/bash
# PostToolUse: Warn about dead links (href="#" or href="") in .tsx files.
# Allows: href="/#section" (hash with a path prefix is intentional).
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

# Write Python scanner to a temp script to avoid heredoc/subshell quoting issues
PYSCRIPT=$(mktemp /tmp/dead_link_check_XXXXXX.py)
trap 'rm -f "$PYSCRIPT"' EXIT

cat > "$PYSCRIPT" << 'PYEOF'
import re, sys

with open(sys.argv[1], 'r', errors='replace') as f:
    content = f.read()

# Find all href values (single or double quoted)
href_pattern = re.compile(r'href=["\']([^"\']*)["\']')
dead = set()
for m in href_pattern.finditer(content):
    val = m.group(1)
    # Allow: anything starting with /# (e.g. /#about, /#section)
    if val.startswith('/#'):
        continue
    # Block: empty string, bare "#", or "#word" (bare fragment with no path prefix)
    if val == '' or val == '#' or re.match(r'^#[^/]', val):
        dead.add('href="%s"' % val)

for d in sorted(dead):
    print(d)
PYEOF

DEAD_LINKS=$(python3 "$PYSCRIPT" "$FILE_PATH")

if [[ -n "$DEAD_LINKS" ]]; then
  LINKS_INLINE=$(echo "$DEAD_LINKS" | tr '\n' ' ')
  echo "Dead link warning in '$FILE_PATH': found placeholder href(s): ${LINKS_INLINE}— replace with real routes or use href=\"/#section\" for anchor links." >&2
  exit 2
fi

exit 0
