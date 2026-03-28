#!/bin/bash
# preview-helpers.sh — helper functions for /preview-templates
# Usage:
#   bash preview-helpers.sh check_tier1 <stack-name>
#   bash preview-helpers.sh clean_previews
#   bash preview-helpers.sh list_previews

PREVIEWS_DIR="$HOME/.claude/config/stacks/previews"
TEMP_DIR="/tmp"

check_tier1() {
  local stack="$1"
  local path="$PREVIEWS_DIR/$stack.png"
  if [[ -f "$path" ]]; then
    echo "$path"
  else
    echo ""
  fi
}

clean_previews() {
  rm -f "$TEMP_DIR"/preview-*.png
  rm -f "$TEMP_DIR"/preview-gallery.png
}

list_previews() {
  if [[ -d "$PREVIEWS_DIR" ]]; then
    ls -1 "$PREVIEWS_DIR"/*.png 2>/dev/null || echo "No cached previews found"
  else
    echo "Previews directory does not exist"
  fi
}

mkdir -p "$PREVIEWS_DIR"

# Route to function based on first argument
case "${1:-}" in
  check_tier1)   check_tier1 "$2" ;;
  clean_previews) clean_previews ;;
  list_previews)  list_previews ;;
  *)              echo "Usage: preview-helpers.sh {check_tier1|clean_previews|list_previews}" ;;
esac
