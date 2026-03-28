#!/usr/bin/env bash
# shadcn-skills-cache.sh — Cache shadcn/skills output per-project
# Usage: scripts/shadcn-skills-cache.sh [project-dir]
# Generates .shadcn/skills-cache.json with 1-hour TTL

set -euo pipefail

PROJECT_DIR="${1:-.}"
CACHE_DIR="${PROJECT_DIR}/.shadcn"
CACHE_FILE="${CACHE_DIR}/skills-cache.json"
COMPONENTS_JSON="${PROJECT_DIR}/components.json"
MAX_AGE=3600  # 1 hour in seconds

# Skip silently if not a shadcn project
if [ ! -f "$COMPONENTS_JSON" ]; then
  exit 0
fi

# Check if cache exists and is fresh
if [ -f "$CACHE_FILE" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    file_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
  else
    file_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  fi
  if [ "$file_age" -lt "$MAX_AGE" ]; then
    echo "Cache is fresh (${file_age}s old, max ${MAX_AGE}s). Skipping refresh."
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Generate skills context
echo "Refreshing shadcn skills cache for ${PROJECT_DIR}..."

skills_output=""
if command -v pnpm &>/dev/null; then
  skills_output=$(cd "$PROJECT_DIR" && pnpm dlx shadcn@latest skills 2>/dev/null || true)
elif command -v npx &>/dev/null; then
  skills_output=$(cd "$PROJECT_DIR" && npx shadcn@latest skills 2>/dev/null || true)
fi

# Generate diff output
diff_output=""
if command -v pnpm &>/dev/null; then
  diff_output=$(cd "$PROJECT_DIR" && pnpm dlx shadcn@latest diff 2>/dev/null || true)
elif command -v npx &>/dev/null; then
  diff_output=$(cd "$PROJECT_DIR" && npx shadcn@latest diff 2>/dev/null || true)
fi

# Write cache file
cat > "$CACHE_FILE" <<CACHE_EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project_dir": "$PROJECT_DIR",
  "skills_output": $(echo "$skills_output" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '""'),
  "diff_output": $(echo "$diff_output" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo '""'),
  "has_drift": $([ -n "$diff_output" ] && echo "true" || echo "false")
}
CACHE_EOF

echo "Cache written to ${CACHE_FILE}"
cat "$CACHE_FILE"
