#!/usr/bin/env bash
set -euo pipefail

# Darwin Self-Healing — detects and fixes common platform failures
# Usage: bash scripts/darwin/self-heal.sh [--project-dir <path>] [--dry-run] [--output <path>]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

err() { echo -e "${RED}[DARWIN-HEAL]${NC} $1" >&2; }
log() { echo -e "${GREEN}[DARWIN-HEAL]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[DARWIN-HEAL]${NC} $1" >&2; }

# --- Parse args ---
PROJECT_DIR="${PWD}"
DRY_RUN=false
OUTPUT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    *) err "Unknown arg: $1"; exit 1 ;;
  esac
done

DARWIN_DIR="$HOME/.claude/darwin"
mkdir -p "$DARWIN_DIR/heal"

HEALED=()
SKIPPED=()
FAILED=()

heal_action() {
  local NAME="$1"
  local DESCRIPTION="$2"

  if $DRY_RUN; then
    warn "[DRY RUN] Would heal: $NAME — $DESCRIPTION"
    SKIPPED+=("{\"action\": \"$NAME\", \"reason\": \"dry_run\", \"description\": \"$DESCRIPTION\"}")
    return 1
  fi
  return 0
}

# --- Action 1: Kill orphaned screen sessions ---
log "Checking for orphaned screen sessions..."
ORPHAN_COUNT=0
if command -v screen &>/dev/null; then
  while IFS= read -r SESSION; do
    [ -z "$SESSION" ] && continue
    SESSION_NAME=$(echo "$SESSION" | awk '{print $1}')

    # Check telegram-sessions.json for sessions stuck > 2 hours
    SESSIONS_FILE="$HOME/.claude/telegram-sessions.json"
    if [ -f "$SESSIONS_FILE" ]; then
      STARTED=$(jq -r --arg name "$SESSION_NAME" '.[$name].started_at // empty' "$SESSIONS_FILE" 2>/dev/null || echo "")
      if [ -n "$STARTED" ]; then
        if [[ "$(uname)" == "Darwin" ]]; then
          STARTED_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${STARTED%%Z*}" +%s 2>/dev/null || echo 0)
        else
          STARTED_EPOCH=$(date -d "$STARTED" +%s 2>/dev/null || echo 0)
        fi
        NOW_EPOCH=$(date +%s)
        AGE=$(( NOW_EPOCH - STARTED_EPOCH ))

        if [ "$AGE" -gt 7200 ]; then
          if heal_action "kill_orphan_session" "Screen session $SESSION_NAME running for $(( AGE / 3600 ))h"; then
            screen -X -S "$SESSION_NAME" quit 2>/dev/null && {
              log "Killed orphaned session: $SESSION_NAME (age: $(( AGE / 3600 ))h)"
              # Update session status
              if [ -f "$SESSIONS_FILE" ]; then
                jq --arg name "$SESSION_NAME" '.[$name].status = "killed_by_darwin"' "$SESSIONS_FILE" > /tmp/sessions-healed.json 2>/dev/null && \
                  mv /tmp/sessions-healed.json "$SESSIONS_FILE"
              fi
              HEALED+=("{\"action\": \"kill_orphan_session\", \"target\": \"$SESSION_NAME\", \"age_hours\": $(( AGE / 3600 ))}")
              ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
            } || {
              FAILED+=("{\"action\": \"kill_orphan_session\", \"target\": \"$SESSION_NAME\", \"error\": \"screen quit failed\"}")
            }
          fi
        fi
      fi
    fi
  done < <(screen -ls 2>/dev/null | grep -E "dispatch-|darwin-" | grep -v "ghost-" || true)
fi
log "Orphaned sessions cleaned: $ORPHAN_COUNT"

# --- Action 2: Resurrect dead ghost watchdog ---
log "Checking ghost watchdog health..."
GHOST_CONFIG="$HOME/.claude/ghost-config.json"
if [ -f "$GHOST_CONFIG" ]; then
  GHOST_STATUS=$(jq -r '.status // "unknown"' "$GHOST_CONFIG" 2>/dev/null)
  if [ "$GHOST_STATUS" = "running" ]; then
    if ! pgrep -f "ghost-watchdog" &>/dev/null; then
      if heal_action "resurrect_ghost_watchdog" "Ghost config says running but no watchdog process found"; then
        WATCHDOG_SCRIPT="$HOME/.claude/hooks/ghost-watchdog.sh"
        if [ -f "$WATCHDOG_SCRIPT" ]; then
          bash "$WATCHDOG_SCRIPT" &
          log "Resurrected ghost watchdog"
          HEALED+=('{"action": "resurrect_ghost_watchdog", "status": "restarted"}')
        else
          WATCHDOG_SCRIPT="$PROJECT_DIR/hooks/ghost-watchdog.sh"
          if [ -f "$WATCHDOG_SCRIPT" ]; then
            bash "$WATCHDOG_SCRIPT" &
            log "Resurrected ghost watchdog from project dir"
            HEALED+=('{"action": "resurrect_ghost_watchdog", "status": "restarted_from_project"}')
          else
            FAILED+=('{"action": "resurrect_ghost_watchdog", "error": "ghost-watchdog.sh not found"}')
          fi
        fi
      fi
    else
      log "Ghost watchdog is running normally"
    fi
  fi
else
  log "No ghost config found — skipping watchdog check"
fi

# --- Action 3: Rotate oversized logs ---
log "Checking log sizes..."
for LOG_FILE in "$HOME/.claude/logs/alerts.jsonl" "$HOME/.claude/logs/telemetry.jsonl" "$HOME/.claude/logs/auto-learn.log"; do
  if [ -f "$LOG_FILE" ]; then
    FILE_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$FILE_SIZE" -gt 52428800 ]; then
      if heal_action "rotate_log" "$(basename "$LOG_FILE") is $(( FILE_SIZE / 1048576 ))MB (>50MB)"; then
        BACKUP="${LOG_FILE}.$(date +%Y%m%d)"
        mv "$LOG_FILE" "$BACKUP"
        touch "$LOG_FILE"
        log "Rotated $(basename "$LOG_FILE") ($(( FILE_SIZE / 1048576 ))MB)"
        HEALED+=("{\"action\": \"rotate_log\", \"file\": \"$(basename "$LOG_FILE")\", \"size_mb\": $(( FILE_SIZE / 1048576 ))}")
      fi
    fi
  fi
done

# --- Action 4: Mark stale queue entries as failed ---
log "Checking telegram queue for stale entries..."
QUEUE_FILE="$HOME/.claude/telegram-queue.json"
if [ -f "$QUEUE_FILE" ]; then
  STALE_COUNT=$(jq '[(.queue // [])[] | select(.status == "running")] | length' "$QUEUE_FILE" 2>/dev/null || echo 0)
  if [ "$STALE_COUNT" -gt 0 ]; then
    # Check each running entry
    HEALED_QUEUE=0
    TEMP_QUEUE=$(mktemp)
    if [[ "$(uname)" == "Darwin" ]]; then
      CUTOFF_TS=$(date -v-24H -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
    else
      CUTOFF_TS=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
    fi

    if heal_action "cleanup_stale_queue" "$STALE_COUNT entries stuck in 'running' state"; then
      jq --arg cutoff "$CUTOFF_TS" '
        .queue = [.queue[] |
          if .status == "running" and (.started_at // "" ) < $cutoff then
            .status = "failed" | .failed_reason = "stale_killed_by_darwin"
          else . end
        ]
      ' "$QUEUE_FILE" > "$TEMP_QUEUE" 2>/dev/null && mv "$TEMP_QUEUE" "$QUEUE_FILE" && {
        log "Cleaned stale queue entries"
        HEALED+=("{\"action\": \"cleanup_stale_queue\", \"entries_cleaned\": $STALE_COUNT}")
      } || {
        rm -f "$TEMP_QUEUE"
        FAILED+=('{"action": "cleanup_stale_queue", "error": "jq transform failed"}')
      }
    fi
  else
    log "Queue is clean — no stale entries"
  fi
fi

# --- Action 5: Restart Telegram systemd service (VPS only) ---
if command -v systemctl &>/dev/null; then
  log "Checking Telegram systemd service..."
  SERVICE="claude-telegram@${USER}.service"
  if ! systemctl --user is-active --quiet "$SERVICE" 2>/dev/null; then
    if heal_action "restart_telegram_service" "$SERVICE is not active"; then
      systemctl --user reset-failed "$SERVICE" 2>/dev/null || true
      if systemctl --user start "$SERVICE" 2>/dev/null; then
        log "Restarted $SERVICE"
        HEALED+=("{\"action\": \"restart_telegram_service\", \"service\": \"$SERVICE\"}")
      else
        # Try system-level
        if sudo systemctl start "$SERVICE" 2>/dev/null; then
          log "Restarted $SERVICE (system-level)"
          HEALED+=("{\"action\": \"restart_telegram_service\", \"service\": \"$SERVICE\", \"level\": \"system\"}")
        else
          FAILED+=("{\"action\": \"restart_telegram_service\", \"error\": \"could not start $SERVICE\"}")
        fi
      fi
    fi
  else
    log "Telegram service is healthy"
  fi
else
  log "Not on systemd — skipping service check"
fi

# --- Compile output ---
if [ ${#HEALED[@]} -gt 0 ]; then
  HEALED_JSON=$(printf '%s\n' "${HEALED[@]}" | jq -s '.' 2>/dev/null || echo "[]")
else
  HEALED_JSON="[]"
fi
if [ ${#SKIPPED[@]} -gt 0 ]; then
  SKIPPED_JSON=$(printf '%s\n' "${SKIPPED[@]}" | jq -s '.' 2>/dev/null || echo "[]")
else
  SKIPPED_JSON="[]"
fi
if [ ${#FAILED[@]} -gt 0 ]; then
  FAILED_JSON=$(printf '%s\n' "${FAILED[@]}" | jq -s '.' 2>/dev/null || echo "[]")
else
  FAILED_JSON="[]"
fi

OUTPUT=$(jq -n \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson dry_run "$( $DRY_RUN && echo true || echo false )" \
  --argjson healed "$HEALED_JSON" \
  --argjson skipped "$SKIPPED_JSON" \
  --argjson failed "$FAILED_JSON" \
  '{
    timestamp: $ts,
    dry_run: $dry_run,
    healed: $healed,
    skipped: $skipped,
    failed: $failed,
    summary: {
      healed_count: ($healed | length),
      skipped_count: ($skipped | length),
      failed_count: ($failed | length)
    }
  }')

# --- Save output ---
DEFAULT_OUTPUT="$DARWIN_DIR/heal/$(date +%Y%m%d).json"
OUTPUT_FILE="${OUTPUT_FILE:-$DEFAULT_OUTPUT}"
mkdir -p "$(dirname "$OUTPUT_FILE")"
echo "$OUTPUT" > "$OUTPUT_FILE"
log "Healing report saved to $OUTPUT_FILE"

echo "$OUTPUT"
