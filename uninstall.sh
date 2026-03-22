#!/usr/bin/env bash
set -euo pipefail

# claude-super-setup uninstaller

REPO_DIR="$HOME/.claude-super-setup"
CLAUDE_DIR="$HOME/.claude"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RESTORE=false

for arg in "$@"; do
  case $arg in
    --restore) RESTORE=true ;;
    --help|-h)
      echo "Usage: uninstall.sh [--restore]"
      echo "  --restore  Restore from most recent backup"
      exit 0
      ;;
  esac
done

echo ""
echo -e "${BLUE}claude-super-setup uninstaller${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Remove symlinks that point to our repo
MODULES=(commands hooks rules skills agent_docs)
for module in "${MODULES[@]}"; do
  target="$CLAUDE_DIR/$module"
  if [ -L "$target" ]; then
    link_target=$(readlink "$target" 2>/dev/null || true)
    if echo "$link_target" | grep -q "claude-super-setup"; then
      rm "$target"
      echo -e "${GREEN}[OK]${NC} Removed symlink: $module"
    fi
  fi
done

# Remove symlinked config files
for file in settings.json CLAUDE.md .mcp.json statusline-command.sh; do
  target="$CLAUDE_DIR/$file"
  if [ -L "$target" ]; then
    link_target=$(readlink "$target" 2>/dev/null || true)
    if echo "$link_target" | grep -q "claude-super-setup"; then
      rm "$target"
      echo -e "${GREEN}[OK]${NC} Removed symlink: $file"
    fi
  fi
done

# Remove stack templates symlink
if [ -L "$CLAUDE_DIR/config/stacks" ]; then
  link_target=$(readlink "$CLAUDE_DIR/config/stacks" 2>/dev/null || true)
  if echo "$link_target" | grep -q "claude-super-setup"; then
    rm "$CLAUDE_DIR/config/stacks"
    echo -e "${GREEN}[OK]${NC} Removed symlink: config/stacks"
  fi
fi

# Restore from backup if requested
if $RESTORE; then
  # Find most recent backup
  LATEST_BACKUP=$(ls -dt "$HOME"/.claude-backup-* 2>/dev/null | head -1)
  if [ -n "$LATEST_BACKUP" ]; then
    echo ""
    echo -e "${BLUE}Restoring from: $LATEST_BACKUP${NC}"
    cp -r "$LATEST_BACKUP/"* "$CLAUDE_DIR/" 2>/dev/null || true
    echo -e "${GREEN}[OK]${NC} Restored from backup"
  else
    echo -e "${YELLOW}[WARN]${NC} No backup found to restore"
  fi
fi

echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
echo "Note: $REPO_DIR was NOT removed. Delete manually if desired."
echo ""
