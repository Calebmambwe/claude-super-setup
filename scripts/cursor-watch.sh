#!/usr/bin/env bash
set -euo pipefail

# cursor-watch — Bidirectional sync between .cursor/rules/*.mdc and source skills/rules
# Usage: cursor-watch.sh [start|stop|status] [--rules-dir PATH] [--dry-run]

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SUPER_SETUP_DIR="${SUPER_SETUP_DIR:-$HOME/.claude-super-setup}"
CURSOR_TEMPLATE="$CLAUDE_DIR/config/cursor-template"
PID_FILE="$CLAUDE_DIR/cursor-watch.pid"
LOG_FILE="$CLAUDE_DIR/logs/cursor-watch.log"
WATCH_DIR=".cursor/rules"
DRY_RUN=false

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Mapping: .mdc filename → source file path
declare -A RULE_TO_SOURCE=(
  ["design-system.mdc"]="$CLAUDE_DIR/skills/design-system/SKILL.md"
  ["backend-architecture.mdc"]="$CLAUDE_DIR/skills/backend-architecture/SKILL.md"
  ["docker.mdc"]="$CLAUDE_DIR/skills/docker/SKILL.md"
  ["git-workflow.mdc"]="$SUPER_SETUP_DIR/rules/git.md"
  ["consistency.mdc"]="$SUPER_SETUP_DIR/rules/consistency.md"
  ["typescript.mdc"]="$SUPER_SETUP_DIR/rules/typescript.md"
  ["python.mdc"]="$SUPER_SETUP_DIR/rules/python.md"
  ["security.mdc"]="$SUPER_SETUP_DIR/rules/security.md"
  ["testing.mdc"]="$SUPER_SETUP_DIR/rules/testing.md"
  ["api.mdc"]="$SUPER_SETUP_DIR/rules/api.md"
  ["plan-workflow.mdc"]="$CURSOR_TEMPLATE/rules/plan-workflow.mdc"
  ["build-workflow.mdc"]="$CURSOR_TEMPLATE/rules/build-workflow.mdc"
  ["auto-plan-workflow.mdc"]="$CURSOR_TEMPLATE/rules/auto-plan-workflow.mdc"
  ["auto-ship-workflow.mdc"]="$CURSOR_TEMPLATE/rules/auto-ship-workflow.mdc"
  ["ghost-workflow.mdc"]="$CURSOR_TEMPLATE/rules/ghost-workflow.mdc"
  ["ghost-run-workflow.mdc"]="$CURSOR_TEMPLATE/rules/ghost-run-workflow.mdc"
)

# Files that should NEVER be synced back
SKIP_FILES=("project-conventions.mdc")

usage() {
  cat <<USAGE
cursor-watch — Bidirectional .mdc ↔ skill/rule sync

Usage: cursor-watch.sh <command> [options]

Commands:
  start       Start watching .cursor/rules/ for changes
  stop        Stop the watcher
  status      Check if watcher is running

Options:
  --rules-dir PATH   Directory to watch (default: .cursor/rules)
  --dry-run          Show what would sync without writing

Requires: fswatch (brew install fswatch)
USAGE
  exit 0
}

log_event() {
  local msg="$1"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  mkdir -p "$(dirname "$LOG_FILE")"
  echo "[$timestamp] $msg" >> "$LOG_FILE"
}

strip_frontmatter() {
  # Extract content after the second --- line
  awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$1"
}

sync_back() {
  local mdc_file="$1"
  local source_file="$2"
  local name
  name=$(basename "$mdc_file")

  # Safety: never sync skip files
  for skip in "${SKIP_FILES[@]}"; do
    if [[ "$name" == "$skip" ]]; then
      return 0
    fi
  done

  # Safety: source must be under CLAUDE_DIR or SUPER_SETUP_DIR
  if [[ "$source_file" != "$CLAUDE_DIR"* ]] && [[ "$source_file" != "$SUPER_SETUP_DIR"* ]]; then
    log_event "BLOCKED: $name → $source_file (path outside allowed directories)"
    return 0
  fi

  # Safety: source must exist
  if [[ ! -f "$source_file" ]]; then
    log_event "SKIP: $name → $source_file (source does not exist)"
    return 0
  fi

  # Extract content from the .mdc file
  local mdc_content
  mdc_content=$(strip_frontmatter "$mdc_file")

  if [[ -z "$mdc_content" ]]; then
    return 0
  fi

  # Determine if source is an .mdc file (pipeline rules) or .md file (skills/rules)
  if [[ "$source_file" == *.mdc ]]; then
    # Source is .mdc — write the full .mdc file back (including frontmatter)
    local current_source
    current_source=$(cat "$source_file")
    local current_mdc
    current_mdc=$(cat "$mdc_file")

    # Compare to avoid infinite loops
    if [[ "$current_source" == "$current_mdc" ]]; then
      return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
      echo -e "${BLUE}[dry-run]${NC} Would sync $name → $source_file (full .mdc)"
      return 0
    fi

    cp "$mdc_file" "$source_file"
    log_event "SYNCED: $name → $source_file (full .mdc)"
    echo -e "${GREEN}[synced]${NC} $name → $(basename "$source_file")"
  else
    # Source is .md — write just the content (stripped frontmatter)
    local current_content=""

    # If source has frontmatter, extract its content for comparison
    if head -1 "$source_file" | grep -q "^---$"; then
      current_content=$(strip_frontmatter "$source_file")
    else
      current_content=$(cat "$source_file")
    fi

    # Compare to avoid infinite loops
    if [[ "$current_content" == "$mdc_content" ]]; then
      return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
      echo -e "${BLUE}[dry-run]${NC} Would sync $name → $source_file (content only)"
      return 0
    fi

    # Preserve existing frontmatter in source, replace content
    if head -1 "$source_file" | grep -q "^---$"; then
      local frontmatter
      frontmatter=$(awk '/^---$/{if(++c==2){print; exit}}1' "$source_file")
      printf '%s\n%s\n' "$frontmatter" "$mdc_content" > "$source_file"
    else
      echo "$mdc_content" > "$source_file"
    fi

    log_event "SYNCED: $name → $source_file (content only)"
    echo -e "${GREEN}[synced]${NC} $name → $(basename "$source_file")"
  fi
}

do_start() {
  if ! command -v fswatch &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} fswatch is required but not found."
    echo "Install: brew install fswatch"
    exit 1
  fi

  if [[ ! -d "$WATCH_DIR" ]]; then
    echo -e "${RED}[ERROR]${NC} Watch directory not found: $WATCH_DIR"
    echo "Run cursor-sync rules first."
    exit 1
  fi

  # Check if already running
  if [[ -f "$PID_FILE" ]]; then
    local existing_pid
    existing_pid=$(cat "$PID_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
      echo -e "${YELLOW}[WARN]${NC} Watcher already running (PID $existing_pid)"
      echo "Run: cursor-watch.sh stop"
      exit 0
    else
      rm -f "$PID_FILE"
    fi
  fi

  echo -e "${BLUE}Starting bidirectional sync watcher...${NC}"
  echo "  Watching: $WATCH_DIR"
  echo "  Log: $LOG_FILE"

  log_event "STARTED: watching $WATCH_DIR"

  # Start fswatch in background
  fswatch -o "$WATCH_DIR" | while read -r _; do
    for f in "$WATCH_DIR"/*.mdc; do
      [[ -f "$f" ]] || continue
      local name
      name=$(basename "$f")
      local source="${RULE_TO_SOURCE[$name]:-}"
      [[ -n "$source" ]] || continue
      sync_back "$f" "$source"
    done
  done &

  local watcher_pid=$!
  echo "$watcher_pid" > "$PID_FILE"
  echo -e "${GREEN}[OK]${NC} Watcher started (PID $watcher_pid)"
  echo ""
  echo "Edit .cursor/rules/*.mdc in Cursor — changes sync back to source skills/rules."
  echo "Stop: cursor-watch.sh stop"
}

do_stop() {
  if [[ ! -f "$PID_FILE" ]]; then
    echo -e "${YELLOW}[WARN]${NC} No watcher PID file found. Not running?"
    return 0
  fi

  local pid
  pid=$(cat "$PID_FILE")

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    # Also kill any child fswatch processes
    pkill -P "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    log_event "STOPPED"
    echo -e "${GREEN}[OK]${NC} Watcher stopped (was PID $pid)"
  else
    rm -f "$PID_FILE"
    echo -e "${YELLOW}[WARN]${NC} Watcher was not running (stale PID $pid removed)"
  fi
}

do_status() {
  if [[ ! -f "$PID_FILE" ]]; then
    echo "Watcher: not running"
    return 0
  fi

  local pid
  pid=$(cat "$PID_FILE")

  if kill -0 "$pid" 2>/dev/null; then
    echo -e "${GREEN}Watcher: running${NC} (PID $pid)"
    echo "  Watch dir: $WATCH_DIR"
    echo "  Log: $LOG_FILE"
    if [[ -f "$LOG_FILE" ]]; then
      echo "  Last events:"
      tail -5 "$LOG_FILE" | sed 's/^/    /'
    fi
  else
    echo "Watcher: not running (stale PID file)"
    rm -f "$PID_FILE"
  fi
}

# Parse arguments
COMMAND="${1:-}"
shift 2>/dev/null || true

for arg in "$@"; do
  case "$arg" in
    --rules-dir=*) WATCH_DIR="${arg#*=}" ;;
    --dry-run) DRY_RUN=true ;;
    --help) usage ;;
  esac
done

case "$COMMAND" in
  start) do_start ;;
  stop) do_stop ;;
  status) do_status ;;
  --help) usage ;;
  "") usage ;;
  *) echo -e "${RED}Unknown command: $COMMAND${NC}"; usage ;;
esac
