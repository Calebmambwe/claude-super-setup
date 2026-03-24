#!/usr/bin/env bash
set -euo pipefail

# cursor-sync — Bridge Claude Code's super setup into Cursor IDE
# Usage: cursor-sync [global|project|rules|validate|all] [OPTIONS]

VERSION="1.0.0"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SUPER_SETUP_DIR="${SUPER_SETUP_DIR:-$HOME/.claude-super-setup}"
CURSOR_DIR="$HOME/.cursor"
# Check installed location first, fallback to repo location
if [[ -d "$CLAUDE_DIR/config/cursor-template" ]]; then
  CURSOR_TEMPLATE="$CLAUDE_DIR/config/cursor-template"
elif [[ -d "$SUPER_SETUP_DIR/config/cursor-template" ]]; then
  CURSOR_TEMPLATE="$SUPER_SETUP_DIR/config/cursor-template"
else
  # Try relative to script location (running from repo checkout)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CURSOR_TEMPLATE="$(dirname "$SCRIPT_DIR")/config/cursor-template"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Flags
DRY_RUN=false
FORCE=false
VERBOSE=false
QUIET=false
PROJECT_MCP_MODE="inherit-global"

usage() {
  cat <<USAGE
cursor-sync v${VERSION} — Bridge Claude Code into Cursor IDE

Usage: cursor-sync <command> [options]

Commands:
  global      Sync ~/.mcp.json → ~/.cursor/mcp.json
  project     Generate .cursor/ directory for current project
  rules       Generate .mdc rules from Claude Code skills + rules
  validate    Check all integrations are working
  all         Run global + project + rules + validate

Options:
  --dry-run   Show what would change without writing
  --force     Overwrite existing .cursor/ files
  --project-mcp-mode=MODE  Project MCP strategy: inherit-global|template
  --verbose   Show detailed output
  --quiet     Only show errors
  --help      Show this help

Examples:
  cursor-sync all                    # Full setup
  cursor-sync global --dry-run       # Preview MCP sync
  cursor-sync rules --force          # Regenerate all rules
  cursor-sync validate               # Check status
  cursor-sync project --project-mcp-mode=template
                                   # Write template servers to .cursor/mcp.json
USAGE
  exit 0
}

log() {
  [[ "$QUIET" == true ]] && return
  echo -e "$1"
}

log_verbose() {
  [[ "$VERBOSE" == true ]] && echo -e "${CYAN}[verbose]${NC} $1"
}

log_ok() { log "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_dry() { log "${BLUE}[dry-run]${NC} $1"; }

# ── Global MCP Sync ──────────────────────────────────────────────────

sync_global_mcp() {
  log "${BLUE}Syncing global MCP config...${NC}"

  local src="$HOME/.mcp.json"
  local dst="$CURSOR_DIR/mcp.json"

  if [[ ! -f "$src" ]]; then
    log_fail "Source ~/.mcp.json not found"
    return 1
  fi

  # Convert absolute home paths to ${userHome} for Cursor variable interpolation
  local content
  content=$(sed "s|$HOME|\${userHome}|g" "$src")

  if [[ "$DRY_RUN" == true ]]; then
    log_dry "Would write $dst"
    log_verbose "Content:\n$content"
    return 0
  fi

  mkdir -p "$CURSOR_DIR"

  if [[ -f "$dst" ]] && [[ "$FORCE" != true ]]; then
    local existing
    existing=$(cat "$dst")
    if [[ "$existing" == "$content" ]]; then
      log_ok "Global MCP already in sync"
      return 0
    fi
  fi

  echo "$content" > "$dst"
  log_ok "Global MCP synced → $dst"
}

# ── Rule Generation ──────────────────────────────────────────────────

generate_mdc_rule() {
  local source_file="$1"
  local output_name="$2"
  local always_apply="$3"
  local globs="$4"  # JSON array string or empty

  if [[ ! -f "$source_file" ]]; then
    log_warn "Source not found: $source_file (skipping $output_name)"
    return 0
  fi

  # Extract description from frontmatter or first meaningful line
  local description=""
  if head -1 "$source_file" | grep -q "^---$"; then
    description=$(awk '/^---$/{if(++c==2)exit}c==1 && /description:/{sub(/.*description:\s*/, ""); gsub(/"/, ""); print}' "$source_file")
  fi
  if [[ -z "$description" ]]; then
    description=$(grep -m1 '^#' "$source_file" | sed 's/^#\+\s*//' | head -c 100)
  fi
  if [[ -z "$description" ]]; then
    description="Rules from $(basename "$source_file")"
  fi

  # Extract content (skip existing frontmatter)
  local content=""
  if head -1 "$source_file" | grep -q "^---$"; then
    content=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$source_file")
  else
    content=$(cat "$source_file")
  fi

  # Build frontmatter
  local frontmatter="---"
  frontmatter="$frontmatter
description: \"$description\""
  frontmatter="$frontmatter
alwaysApply: $always_apply"
  if [[ -n "$globs" ]]; then
    frontmatter="$frontmatter
globs: $globs"
  fi
  frontmatter="$frontmatter
---"

  local output_path=".cursor/rules/$output_name"

  if [[ "$DRY_RUN" == true ]]; then
    log_dry "Would write $output_path (from $source_file)"
    return 0
  fi

  mkdir -p ".cursor/rules"
  printf '%s\n\n%s\n' "$frontmatter" "$content" > "$output_path"
  log_verbose "Generated $output_path from $source_file"
}

generate_rules() {
  log "${BLUE}Generating Cursor rules from Claude Code skills + rules...${NC}"

  local count=0
  local skills_dir="$CLAUDE_DIR/skills"
  local rules_dir="$SUPER_SETUP_DIR/rules"

  # Skills → .mdc rules
  generate_mdc_rule "$skills_dir/design-system/SKILL.md" "design-system.mdc" "false" \
    '["**/*.tsx", "**/*.jsx", "**/*.css", "**/*.scss"]' && count=$((count + 1)) || true

  generate_mdc_rule "$skills_dir/backend-architecture/SKILL.md" "backend-architecture.mdc" "false" \
    '["**/*.ts", "**/*.py", "**/routes/**", "**/services/**"]' && count=$((count + 1)) || true

  generate_mdc_rule "$skills_dir/docker/SKILL.md" "docker.mdc" "false" \
    '["**/Dockerfile*", "**/docker-compose*", "**/.devcontainer/**"]' && count=$((count + 1)) || true

  # Rules → .mdc rules
  generate_mdc_rule "$rules_dir/git.md" "git-workflow.mdc" "true" "" && count=$((count + 1)) || true

  generate_mdc_rule "$rules_dir/consistency.md" "consistency.mdc" "true" "" && count=$((count + 1)) || true

  generate_mdc_rule "$rules_dir/typescript.md" "typescript.mdc" "false" \
    '["**/*.ts", "**/*.tsx"]' && count=$((count + 1)) || true

  generate_mdc_rule "$rules_dir/python.md" "python.mdc" "false" \
    '["**/*.py"]' && count=$((count + 1)) || true

  generate_mdc_rule "$rules_dir/security.md" "security.mdc" "true" "" && count=$((count + 1)) || true

  generate_mdc_rule "$rules_dir/testing.md" "testing.mdc" "false" \
    '["**/*.test.*", "**/*.spec.*", "**/tests/**"]' && count=$((count + 1)) || true

  generate_mdc_rule "$rules_dir/api.md" "api.mdc" "false" \
    '["**/routes/**", "**/api/**", "**/controllers/**", "**/endpoints/**"]' && count=$((count + 1)) || true

  # Pipeline workflow rules → .mdc (from cursor template)
  generate_mdc_rule "$CURSOR_TEMPLATE/rules/plan-workflow.mdc" "plan-workflow.mdc" "true" "" && count=$((count + 1)) || true

  generate_mdc_rule "$CURSOR_TEMPLATE/rules/build-workflow.mdc" "build-workflow.mdc" "true" "" && count=$((count + 1)) || true

  generate_mdc_rule "$CURSOR_TEMPLATE/rules/auto-plan-workflow.mdc" "auto-plan-workflow.mdc" "true" "" && count=$((count + 1)) || true

  generate_mdc_rule "$CURSOR_TEMPLATE/rules/auto-ship-workflow.mdc" "auto-ship-workflow.mdc" "true" "" && count=$((count + 1)) || true

  generate_mdc_rule "$CURSOR_TEMPLATE/rules/ghost-workflow.mdc" "ghost-workflow.mdc" "true" "" && count=$((count + 1)) || true

  generate_mdc_rule "$CURSOR_TEMPLATE/rules/ghost-run-workflow.mdc" "ghost-run-workflow.mdc" "true" "" && count=$((count + 1)) || true

  # Project CLAUDE.md → project-conventions.mdc (if exists)
  if [[ -f "CLAUDE.md" ]]; then
    generate_mdc_rule "CLAUDE.md" "project-conventions.mdc" "true" "" && count=$((count + 1)) || true
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_dry "Would generate $count rule files"
  else
    log_ok "Generated $count .mdc rule files in .cursor/rules/"
  fi
}

# ── Project Setup ────────────────────────────────────────────────────

setup_project() {
  log "${BLUE}Setting up project .cursor/ directory...${NC}"

  if [[ -d ".cursor" ]] && [[ "$FORCE" != true ]]; then
    log_warn ".cursor/ already exists. Use --force to overwrite."
  fi

  # Create project-level MCP config
  local project_mcp=".cursor/mcp.json"

  if [[ "$DRY_RUN" == true ]]; then
    log_dry "Would create $project_mcp"
    return 0
  fi

  mkdir -p ".cursor"

  # If a project .mcp.json exists, convert it for Cursor
  if [[ -f ".mcp.json" ]]; then
    sed "s|$HOME|\${userHome}|g" ".mcp.json" > "$project_mcp"
    log_ok "Project MCP config synced from .mcp.json → $project_mcp"
  elif [[ "$PROJECT_MCP_MODE" == "template" ]]; then
    if [[ -f "$CURSOR_TEMPLATE/mcp.json" ]]; then
      cp "$CURSOR_TEMPLATE/mcp.json" "$project_mcp"
      log_ok "Project MCP config created from template (project-mcp-mode=template)"
    else
      log_warn "Template MCP not found at $CURSOR_TEMPLATE/mcp.json; falling back to inherit-global mode"
      cat > "$project_mcp" <<'MCP_EOF'
{
  "mcpServers": {}
}
MCP_EOF
      log_ok "Created minimal project MCP config (inherits global)"
    fi
  else
    # Default strategy: keep project MCP minimal and inherit from global MCP.
    cat > "$project_mcp" <<'MCP_EOF'
{
  "mcpServers": {}
}
MCP_EOF
    log_ok "Created minimal project MCP config (inherits global; project-mcp-mode=inherit-global)"
  fi
}

# ── Validation ───────────────────────────────────────────────────────

validate_integration() {
  log "${BLUE}Validating Cursor integration...${NC}"
  log ""

  local errors=0
  local warnings=0

  # 1. Check Cursor installed
  if [[ -d "/Applications/Cursor.app" ]] || command -v cursor &>/dev/null; then
    log_ok "Cursor IDE installed"
  else
    log_warn "Cursor IDE not detected (configs can still be pre-generated)"
    ((warnings++))
  fi

  # 2. Check global MCP config
  if [[ -f "$CURSOR_DIR/mcp.json" ]]; then
    if jq . "$CURSOR_DIR/mcp.json" &>/dev/null; then
      log_ok "Global MCP config valid JSON"
    else
      log_fail "Global MCP config is invalid JSON"
      ((errors++))
    fi
  else
    log_fail "Global MCP config missing — run: cursor-sync global"
    ((errors++))
  fi

  # 3. Check MCP servers reachable
  if [[ -f "$CURSOR_DIR/mcp.json" ]]; then
    local total=0
    local reachable=0
    local servers
    servers=$(jq -r '.mcpServers // {} | keys[]' "$CURSOR_DIR/mcp.json" 2>/dev/null || true)
    for server in $servers; do
      ((total++))
      local cmd
      cmd=$(jq -r ".mcpServers.\"$server\".command" "$CURSOR_DIR/mcp.json" 2>/dev/null)
      # Resolve ${userHome} for check
      cmd="${cmd//\$\{userHome\}/$HOME}"
      if command -v "$cmd" &>/dev/null; then
        ((reachable++))
        log_verbose "MCP server '$server': command '$cmd' found"
      else
        log_warn "MCP server '$server': command '$cmd' not found in PATH"
        ((warnings++))
      fi
    done
    if [[ $total -gt 0 ]]; then
      log_ok "MCP servers: $reachable/$total commands reachable"
    fi
  fi

  # 4. Check project .cursor/rules
  if [[ -d ".cursor/rules" ]]; then
    local rule_count
    rule_count=$(find .cursor/rules -name "*.mdc" 2>/dev/null | wc -l | tr -d ' ')
    log_ok "Project rules: $rule_count .mdc files"

    # Validate frontmatter on each
    local invalid=0
    for f in .cursor/rules/*.mdc; do
      [[ -f "$f" ]] || continue
      if ! head -1 "$f" | grep -q "^---$"; then
        log_warn "Missing frontmatter: $f"
        ((invalid++))
      fi
    done
    if [[ $invalid -gt 0 ]]; then
      log_warn "$invalid rule(s) missing frontmatter"
      ((warnings++))
    fi
  else
    log_warn "No .cursor/rules/ in current project — run: cursor-sync project && cursor-sync rules"
    ((warnings++))
  fi

  # 4b. Check project MCP strategy/output
  if [[ -f ".cursor/mcp.json" ]]; then
    local project_server_count
    project_server_count=$(jq -r '.mcpServers // {} | length' ".cursor/mcp.json" 2>/dev/null || echo "invalid")
    if [[ "$project_server_count" == "invalid" ]]; then
      log_warn "Project MCP config is invalid JSON: .cursor/mcp.json"
      ((warnings++))
    elif [[ "$project_server_count" -eq 0 ]]; then
      log_ok "Project MCP mode appears to be inherit-global (0 project servers)"
    else
      log_ok "Project MCP mode appears to be template/explicit ($project_server_count project server(s))"
    fi
  else
    log_warn "No project MCP config found — run: cursor-sync project"
    ((warnings++))
  fi

  # 5. Check AGENTS.md
  if [[ -f "AGENTS.md" ]]; then
    log_ok "AGENTS.md present (shared between Claude Code + Cursor)"
  else
    log_warn "No AGENTS.md — run: /init-agents-md"
    ((warnings++))
  fi

  # 6. Check Claude Code extension in Cursor
  local ext_found=false
  if ls "$CURSOR_DIR/extensions/"*claude* &>/dev/null 2>&1; then
    ext_found=true
  elif ls "$HOME/.cursor/extensions/"*anthropic* &>/dev/null 2>&1; then
    ext_found=true
  fi
  if [[ "$ext_found" == true ]]; then
    log_ok "Claude Code extension installed in Cursor"
  else
    log_warn "Claude Code extension not detected in Cursor"
    log "     Install: Open Cursor → Extensions → Search 'Claude Code' → Install"
    ((warnings++))
  fi

  # 7. Check no hardcoded paths
  if [[ -f "$CURSOR_DIR/mcp.json" ]]; then
    if grep -q "$HOME" "$CURSOR_DIR/mcp.json" 2>/dev/null; then
      log_warn "Hardcoded home path found in $CURSOR_DIR/mcp.json"
      ((warnings++))
    else
      log_ok "No hardcoded paths in Cursor MCP config"
    fi
  fi

  # Summary
  log ""
  if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
    log "${GREEN}Integration status: READY${NC}"
  elif [[ $errors -eq 0 ]]; then
    log "${YELLOW}Integration status: READY ($warnings warning(s))${NC}"
  else
    log "${RED}Integration status: $errors error(s), $warnings warning(s)${NC}"
  fi

  return $errors
}

# ── Run All ──────────────────────────────────────────────────────────

run_all() {
  sync_global_mcp
  setup_project
  generate_rules
  log ""
  validate_integration
}

# ── Parse Arguments ──────────────────────────────────────────────────

COMMAND="${1:-}"
shift 2>/dev/null || true

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --force) FORCE=true ;;
    --project-mcp-mode=*)
      PROJECT_MCP_MODE="${arg#*=}"
      if [[ "$PROJECT_MCP_MODE" != "inherit-global" && "$PROJECT_MCP_MODE" != "template" ]]; then
        log_fail "Invalid project MCP mode: $PROJECT_MCP_MODE (expected inherit-global|template)"
        exit 1
      fi
      ;;
    --verbose) VERBOSE=true ;;
    --quiet) QUIET=true ;;
    --help) usage ;;
    *) log_fail "Unknown option: $arg"; usage ;;
  esac
done

case "$COMMAND" in
  global) sync_global_mcp ;;
  project) setup_project ;;
  rules) generate_rules ;;
  validate) validate_integration ;;
  all) run_all ;;
  --help) usage ;;
  "") usage ;;
  *) log_fail "Unknown command: $COMMAND"; usage ;;
esac
