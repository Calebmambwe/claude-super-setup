#!/usr/bin/env bash
set -euo pipefail

# Compare local ~/.claude/ against repo HEAD
# Identifies files modified locally but not committed to the repo

REPO_DIR="${1:-$HOME/.claude-super-setup}"
CLAUDE_DIR="$HOME/.claude"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -d "$REPO_DIR" ]; then
  echo -e "${RED}ERROR:${NC} Repo not found at $REPO_DIR"
  echo "Usage: drift-detect.sh [repo-path]"
  exit 1
fi

echo "Comparing $CLAUDE_DIR against $REPO_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DRIFTS=0

for module in commands hooks rules skills agent_docs; do
  local_dir="$CLAUDE_DIR/$module"
  repo_dir="$REPO_DIR/$module"

  if [ ! -d "$local_dir" ] || [ ! -d "$repo_dir" ]; then
    continue
  fi

  # Check if it's a symlink pointing to repo (no drift possible)
  if [ -L "$local_dir" ]; then
    link_target=$(readlink "$local_dir" 2>/dev/null || true)
    if echo "$link_target" | grep -q "claude-super-setup"; then
      echo -e "${GREEN}[SYNCED]${NC} $module (symlinked)"
      continue
    fi
  fi

  # Compare contents
  DIFF_OUTPUT=$(diff -rq "$local_dir" "$repo_dir" 2>/dev/null | head -20 || true)
  if [ -z "$DIFF_OUTPUT" ]; then
    echo -e "${GREEN}[SYNCED]${NC} $module"
  else
    echo -e "${YELLOW}[DRIFT]${NC}  $module"
    echo "$DIFF_OUTPUT" | while read -r line; do
      echo "         $line"
    done
    DRIFTS=$((DRIFTS + 1))
  fi
done

echo ""
if [ "$DRIFTS" -gt 0 ]; then
  echo -e "${YELLOW}Found $DRIFTS module(s) with drift.${NC}"
  echo "To sync: cd $REPO_DIR && git pull"
else
  echo -e "${GREEN}All modules in sync.${NC}"
fi
