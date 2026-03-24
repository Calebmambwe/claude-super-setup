#!/usr/bin/env bash
set -euo pipefail

# cursor-automations-provision — Provision Cursor Automations from YAML templates
# Usage: cursor-automations-provision.sh [TEMPLATE_DIR] [--dry-run]

TEMPLATE_DIR="${1:-$HOME/.claude/config/cursor-automations}"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Cursor Automations Provisioner${NC}"
echo ""

if [[ -n "${CURSOR_API_KEY:-}" ]]; then
  echo -e "${GREEN}[OK]${NC} CURSOR_API_KEY is set — programmatic provisioning available"
  echo ""

  for template in "$TEMPLATE_DIR"/*.yaml; do
    [[ -f "$template" ]] || continue
    name=$(basename "$template" .yaml)

    if [[ "$DRY_RUN" == true ]]; then
      echo -e "${BLUE}[dry-run]${NC} Would provision: $name"
      continue
    fi

    echo -e "Provisioning: ${name}..."

    # Note: This API endpoint is provisional. Verify against current Cursor API docs.
    # The Cursor Automations API may require OAuth authentication via cursor.com
    response=$(curl -s -w "\n%{http_code}" \
      -X POST "https://api.cursor.com/v1/automations" \
      -H "Authorization: Bearer $CURSOR_API_KEY" \
      -H "Content-Type: application/yaml" \
      --data-binary "@$template" 2>/dev/null || echo "000")

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -n -1)

    if [[ "$http_code" == "201" || "$http_code" == "200" ]]; then
      echo -e "  ${GREEN}[OK]${NC} $name provisioned successfully"
    else
      echo -e "  ${YELLOW}[WARN]${NC} $name failed (HTTP $http_code)"
      echo -e "  Fallback: import manually at cursor.com/automations"
    fi
  done
else
  echo -e "${YELLOW}[INFO]${NC} CURSOR_API_KEY not set — showing manual import instructions"
  echo ""
  echo "To import automation templates into Cursor:"
  echo ""
  echo "  1. Open https://cursor.com/automations"
  echo "  2. Click 'Create Automation' or 'Import Template'"
  echo "  3. Copy the contents of each YAML template below:"
  echo ""

  for template in "$TEMPLATE_DIR"/*.yaml; do
    [[ -f "$template" ]] || continue
    name=$(basename "$template" .yaml)
    echo -e "  ${BLUE}Template: $name${NC}"
    echo "  File: $template"
    echo ""
  done

  echo "Available templates:"
  ls -1 "$TEMPLATE_DIR"/*.yaml 2>/dev/null | while read -r f; do
    echo "  - $(basename "$f")"
  done
  echo ""
  echo "To enable API provisioning, set CURSOR_API_KEY in your environment:"
  echo "  export CURSOR_API_KEY='your-cursor-api-key'"
fi
