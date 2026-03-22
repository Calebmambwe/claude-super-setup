#!/usr/bin/env bash
set -euo pipefail

# claude-super-setup installer
# Usage: curl -fsSL https://raw.githubusercontent.com/USER/claude-super-setup/main/install.sh | bash

VERSION="1.0.0"
REPO_DIR="$HOME/.claude-super-setup"
CLAUDE_DIR="$HOME/.claude"
REPO_URL="https://github.com/calebmambwe/claude-super-setup.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
MODE="symlink"
DRY_RUN=false
NO_BACKUP=false
MODULES="all"
PREFIX=""

usage() {
  cat <<USAGE
claude-super-setup installer v${VERSION}

Usage: install.sh [OPTIONS]

Options:
  --mode=symlink|copy    Install mode (default: symlink)
  --dry-run              Show what would be changed without doing it
  --no-backup            Skip backing up existing ~/.claude/
  --modules=LIST         Comma-separated: commands,agents,hooks,rules,skills,agent_docs,config (default: all)
  --prefix=PATH          Install to PATH instead of ~/.claude/
  --help                 Show this help

Examples:
  # Standard install (symlinks, with backup)
  ./install.sh

  # Preview changes without making them
  ./install.sh --dry-run

  # Copy mode (no symlinks)
  ./install.sh --mode=copy

  # Install only specific modules
  ./install.sh --modules=commands,agents,hooks
USAGE
  exit 0
}

log() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
dry() { echo -e "${BLUE}[DRY-RUN]${NC} Would: $1"; }

# Parse arguments
for arg in "$@"; do
  case $arg in
    --mode=*) MODE="${arg#*=}" ;;
    --dry-run) DRY_RUN=true ;;
    --no-backup) NO_BACKUP=true ;;
    --modules=*) MODULES="${arg#*=}" ;;
    --prefix=*) PREFIX="${arg#*=}"; CLAUDE_DIR="$PREFIX" ;;
    --help|-h) usage ;;
    *) err "Unknown argument: $arg"; usage ;;
  esac
done

echo ""
echo -e "${BLUE}claude-super-setup installer v${VERSION}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Pre-flight checks
info "Running pre-flight checks..."

if ! command -v git &>/dev/null; then
  err "git is required but not installed."
  exit 1
fi

BASH_VERSION_NUM="${BASH_VERSINFO[0]}"
if [ "$BASH_VERSION_NUM" -lt 4 ]; then
  warn "bash 4+ recommended. You have bash $BASH_VERSION_NUM."
fi

if ! command -v jq &>/dev/null; then
  warn "jq not found. Some hooks may not work. Install with: brew install jq"
fi

log "Pre-flight checks passed."

# Step 2: Clone or update repo
info "Setting up repository..."

if [ -d "$REPO_DIR" ]; then
  if $DRY_RUN; then
    dry "git pull in $REPO_DIR"
  else
    cd "$REPO_DIR"
    git pull --quiet origin main 2>/dev/null || warn "Could not pull latest. Using existing checkout."
    cd - >/dev/null
    log "Repository updated at $REPO_DIR"
  fi
else
  if $DRY_RUN; then
    dry "git clone $REPO_URL $REPO_DIR"
  else
    # If running from a local checkout, copy instead of clone
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/config/settings.json" ]; then
      cp -r "$SCRIPT_DIR" "$REPO_DIR"
      log "Repository copied to $REPO_DIR"
    else
      git clone --quiet "$REPO_URL" "$REPO_DIR" 2>/dev/null || {
        err "Failed to clone repository. Copy this repo to $REPO_DIR manually."
        exit 1
      }
      log "Repository cloned to $REPO_DIR"
    fi
  fi
fi

# Step 3: Backup existing ~/.claude/
if [ -d "$CLAUDE_DIR" ] && [ "$NO_BACKUP" = false ]; then
  BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"
  if $DRY_RUN; then
    dry "Back up $CLAUDE_DIR to $BACKUP_DIR"
  else
    cp -r "$CLAUDE_DIR" "$BACKUP_DIR"
    log "Backed up existing config to $BACKUP_DIR"
  fi
fi

# Step 4: Create ~/.claude/ if needed
if [ ! -d "$CLAUDE_DIR" ]; then
  if $DRY_RUN; then
    dry "mkdir -p $CLAUDE_DIR"
  else
    mkdir -p "$CLAUDE_DIR"
    log "Created $CLAUDE_DIR"
  fi
fi

# Step 5: Install modules
install_module() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -d "$REPO_DIR/$src" ] && [ ! -f "$REPO_DIR/$src" ]; then
    warn "Source not found: $REPO_DIR/$src — skipping $label"
    return
  fi

  if $DRY_RUN; then
    if [ "$MODE" = "symlink" ]; then
      dry "ln -sfn $REPO_DIR/$src $dst ($label)"
    else
      dry "rsync $REPO_DIR/$src/ $dst/ ($label)"
    fi
    return
  fi

  # Remove existing target (symlink or directory)
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -d "$dst" ] && [ "$MODE" = "symlink" ]; then
    # In symlink mode, remove the directory to create a symlink
    rm -rf "$dst"
  fi

  if [ "$MODE" = "symlink" ]; then
    ln -sfn "$REPO_DIR/$src" "$dst"
    log "Linked $label → $REPO_DIR/$src"
  else
    mkdir -p "$dst"
    rsync -a --delete "$REPO_DIR/$src/" "$dst/"
    log "Copied $label"
  fi
}

install_file() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -f "$REPO_DIR/$src" ]; then
    warn "Source not found: $REPO_DIR/$src — skipping $label"
    return
  fi

  if $DRY_RUN; then
    if [ "$MODE" = "symlink" ]; then
      dry "ln -sf $REPO_DIR/$src $dst ($label)"
    else
      dry "cp $REPO_DIR/$src $dst ($label)"
    fi
    return
  fi

  if [ "$MODE" = "symlink" ]; then
    ln -sf "$REPO_DIR/$src" "$dst"
  else
    cp "$REPO_DIR/$src" "$dst"
  fi
  log "Installed $label"
}

should_install() {
  local module="$1"
  if [ "$MODULES" = "all" ]; then
    return 0
  fi
  echo ",$MODULES," | grep -q ",$module,"
}

info "Installing modules (mode: $MODE)..."

if should_install "commands"; then
  install_module "commands" "$CLAUDE_DIR/commands" "commands"
fi

if should_install "agents"; then
  # Install core agents
  mkdir -p "$CLAUDE_DIR/agents" 2>/dev/null || true
  install_module "agents/core" "$CLAUDE_DIR/agents" "core agents"
fi

if should_install "hooks"; then
  install_module "hooks" "$CLAUDE_DIR/hooks" "hooks"
fi

if should_install "rules"; then
  install_module "rules" "$CLAUDE_DIR/rules" "rules"
fi

if should_install "skills"; then
  install_module "skills" "$CLAUDE_DIR/skills" "skills"
fi

if should_install "agent_docs"; then
  install_module "agent_docs" "$CLAUDE_DIR/agent_docs" "agent_docs"
fi

if should_install "config"; then
  # Install config files individually (not the whole directory)
  install_file "config/settings.json" "$CLAUDE_DIR/settings.json" "settings.json"
  install_file "config/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"
  install_file "config/.mcp.json" "$CLAUDE_DIR/.mcp.json" ".mcp.json"
  install_file "config/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh" "statusline-command.sh"

  # Stack templates
  mkdir -p "$CLAUDE_DIR/config/stacks" 2>/dev/null || true
  install_module "config/stacks" "$CLAUDE_DIR/config/stacks" "stack templates"
fi

# Step 6: Set up user override files (if they don't exist)
if [ ! -f "$CLAUDE_DIR/settings.local.json" ]; then
  if $DRY_RUN; then
    dry "Create settings.local.json from template"
  else
    cp "$REPO_DIR/user-overrides/settings.local.json.template" "$CLAUDE_DIR/settings.local.json"
    log "Created settings.local.json from template"
  fi
fi

# Step 7: Make hooks executable
if $DRY_RUN; then
  dry "chmod +x hooks/*.sh"
else
  chmod +x "$CLAUDE_DIR/hooks/"*.sh 2>/dev/null || true
  chmod +x "$CLAUDE_DIR/statusline-command.sh" 2>/dev/null || true
  log "Made hooks executable"
fi

# Step 8: Health check
info "Running health check..."
HEALTH_ERRORS=0

check_exists() {
  local path="$1"
  local label="$2"
  if [ -e "$path" ] || [ -L "$path" ]; then
    return 0
  else
    warn "Missing: $label ($path)"
    HEALTH_ERRORS=$((HEALTH_ERRORS + 1))
    return 1
  fi
}

if ! $DRY_RUN; then
  check_exists "$CLAUDE_DIR/commands" "commands"
  check_exists "$CLAUDE_DIR/hooks" "hooks"
  check_exists "$CLAUDE_DIR/rules" "rules"
  check_exists "$CLAUDE_DIR/settings.json" "settings.json"
  check_exists "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"

  # Verify settings.json is valid JSON
  if [ -f "$CLAUDE_DIR/settings.json" ]; then
    if jq empty "$CLAUDE_DIR/settings.json" 2>/dev/null; then
      log "settings.json is valid JSON"
    else
      warn "settings.json is not valid JSON"
      HEALTH_ERRORS=$((HEALTH_ERRORS + 1))
    fi
  fi

  # Count files
  CMD_COUNT=$(find "$CLAUDE_DIR/commands" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  HOOK_COUNT=$(find "$CLAUDE_DIR/hooks" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
  RULE_COUNT=$(find "$CLAUDE_DIR/rules" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$HEALTH_ERRORS" -eq 0 ]; then
    log "Health check passed"
  else
    warn "Health check completed with $HEALTH_ERRORS warning(s)"
  fi
fi

# Step 9: Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo ""
if ! $DRY_RUN; then
  echo "  Commands:  ${CMD_COUNT:-?}"
  echo "  Hooks:     ${HOOK_COUNT:-?}"
  echo "  Rules:     ${RULE_COUNT:-?}"
  echo "  Mode:      $MODE"
  echo "  Location:  $CLAUDE_DIR"
  echo "  Repo:      $REPO_DIR"
  echo ""
  echo "To update:   cd $REPO_DIR && git pull"
  echo "To uninstall: $REPO_DIR/uninstall.sh"
else
  echo "  (Dry run — no changes made)"
fi
echo ""
