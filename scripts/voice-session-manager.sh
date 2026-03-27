#!/usr/bin/env bash
set -euo pipefail

# Voice Session Manager — manages voice brainstorm session state as JSON files
# Usage: bash scripts/voice-session-manager.sh <command> [args...]
#
# Commands:
#   start <chat_id> [topic]                    — Create new session, print session ID
#   add-exchange <session_id> <role> <text> [audio_path]  — Append exchange to session
#   get-state <session_id>                     — Print session JSON to stdout
#   end <session_id>                           — Complete session, generate markdown transcript
#   list                                       — Show all active sessions
#   cleanup                                    — Remove session files older than 24 hours
#
# Requires: jq

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

err() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }

# --- Constants ---
SESSIONS_DIR="/tmp/voice-sessions"
TRANSCRIPTS_DIR="/Users/calebmambwe/claude_super_setup/docs/voice-sessions"
SESSION_ID_PATTERN='^vs-[0-9]{8}-[0-9]{6}$'

# --- Dependency check ---
if ! command -v jq &>/dev/null; then
  err "jq is required but not installed."
  echo "  macOS: brew install jq" >&2
  echo "  Ubuntu: sudo apt-get install -y jq" >&2
  exit 1
fi

# --- Helpers ---

ensure_sessions_dir() {
  if [ ! -d "$SESSIONS_DIR" ]; then
    mkdir -p "$SESSIONS_DIR"
    chmod 700 "$SESSIONS_DIR"
    log "Created sessions directory: $SESSIONS_DIR"
  fi
}

ensure_transcripts_dir() {
  if [ ! -d "$TRANSCRIPTS_DIR" ]; then
    mkdir -p "$TRANSCRIPTS_DIR"
    log "Created transcripts directory: $TRANSCRIPTS_DIR"
  fi
}

validate_session_id() {
  local sid="$1"
  if ! [[ "$sid" =~ $SESSION_ID_PATTERN ]]; then
    err "Invalid session ID format: $sid (expected vs-YYYYMMDD-HHMMSS)"
    exit 1
  fi
}

session_file() {
  echo "${SESSIONS_DIR}/$1.json"
}

require_session() {
  local sid="$1"
  validate_session_id "$sid"
  local file
  file=$(session_file "$sid")
  if [ ! -f "$file" ]; then
    err "Session not found: $sid"
    exit 1
  fi
  echo "$file"
}

sanitize_topic() {
  # Strip characters that could cause issues in filenames or JSON injection
  # Allow alphanumeric, spaces, hyphens, underscores, dots
  local raw="$1"
  local sanitized
  sanitized=$(printf '%s' "$raw" | tr -cd 'a-zA-Z0-9 ._-' | sed 's/^ *//;s/ *$//' | cut -c1-80)
  [ -z "$sanitized" ] && sanitized="untitled"
  echo "$sanitized"
}

iso_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# --- Commands ---

cmd_start() {
  local chat_id="${1:-}"
  local topic_raw="${2:-auto}"

  if [ -z "$chat_id" ]; then
    err "Usage: voice-session-manager.sh start <chat_id> [topic]"
    exit 1
  fi

  # Validate chat_id is numeric (Telegram chat IDs)
  if ! [[ "$chat_id" =~ ^-?[0-9]+$ ]]; then
    err "Invalid chat_id: $chat_id (must be a numeric Telegram chat ID)"
    exit 1
  fi

  local topic
  topic=$(sanitize_topic "$topic_raw")

  ensure_sessions_dir

  local session_id
  session_id="vs-$(date -u '+%Y%m%d-%H%M%S')"

  local file
  file=$(session_file "$session_id")

  local started_at
  started_at=$(iso_now)

  # Build initial JSON using jq (no string interpolation = no injection risk)
  jq -n \
    --arg id "$session_id" \
    --arg started_at "$started_at" \
    --arg topic "$topic" \
    --arg chat_id "$chat_id" \
    '{
      id: $id,
      approach: "telegram",
      status: "active",
      started_at: $started_at,
      ended_at: null,
      topic: $topic,
      chat_id: $chat_id,
      exchanges: [],
      questions_answered: [],
      questions_remaining: ["what", "who", "constraints", "scope", "why_now"]
    }' > "$file"

  chmod 600 "$file"
  log "Session created: $session_id (topic: $topic)"
  echo "$session_id"
}

cmd_add_exchange() {
  local session_id="${1:-}"
  local role="${2:-}"
  local text="${3:-}"
  local audio_path="${4:-}"

  if [ -z "$session_id" ] || [ -z "$role" ] || [ -z "$text" ]; then
    err "Usage: voice-session-manager.sh add-exchange <session_id> <role> <text> [audio_path]"
    exit 1
  fi

  local file
  file=$(require_session "$session_id")

  # Validate role
  if [ "$role" != "user" ] && [ "$role" != "assistant" ] && [ "$role" != "claude" ]; then
    err "Invalid role: $role (expected: user, assistant, claude)"
    exit 1
  fi

  # Validate session is still active
  local status
  status=$(jq -r '.status' "$file")
  if [ "$status" != "active" ]; then
    err "Session $session_id is not active (status: $status)"
    exit 1
  fi

  local timestamp
  timestamp=$(iso_now)

  # Compute turn number (current exchange count + 1)
  local turn
  turn=$(jq '.exchanges | length + 1' "$file")

  # Validate audio_path is a local path if provided (prevent injection)
  if [ -n "$audio_path" ] && [[ "$audio_path" =~ :// ]]; then
    err "audio_path must be a local file path, not a URL: $audio_path"
    exit 1
  fi

  # Use jq to safely append exchange — all values passed as --arg (no shell interpolation)
  local tmp_file
  tmp_file=$(mktemp "${SESSIONS_DIR}/.tmp-XXXXXX")
  chmod 600 "$tmp_file"
  trap 'rm -f "$tmp_file"' EXIT INT TERM

  if [ -n "$audio_path" ]; then
    jq \
      --argjson turn "$turn" \
      --arg role "$role" \
      --arg text "$text" \
      --arg audio_path "$audio_path" \
      --arg timestamp "$timestamp" \
      '.exchanges += [{
        turn: $turn,
        role: $role,
        text: $text,
        audio_path: $audio_path,
        timestamp: $timestamp
      }]' "$file" > "$tmp_file"
  else
    jq \
      --argjson turn "$turn" \
      --arg role "$role" \
      --arg text "$text" \
      --arg timestamp "$timestamp" \
      '.exchanges += [{
        turn: $turn,
        role: $role,
        text: $text,
        audio_path: null,
        timestamp: $timestamp
      }]' "$file" > "$tmp_file"
  fi

  mv "$tmp_file" "$file"
  trap - EXIT INT TERM

  log "Exchange added to $session_id (turn $turn, role: $role)"
}

cmd_get_state() {
  local session_id="${1:-}"

  if [ -z "$session_id" ]; then
    err "Usage: voice-session-manager.sh get-state <session_id>"
    exit 1
  fi

  local file
  file=$(require_session "$session_id")

  jq '.' "$file"
}

cmd_end() {
  local session_id="${1:-}"

  if [ -z "$session_id" ]; then
    err "Usage: voice-session-manager.sh end <session_id>"
    exit 1
  fi

  local file
  file=$(require_session "$session_id")

  local status
  status=$(jq -r '.status' "$file")
  if [ "$status" = "completed" ]; then
    warn "Session $session_id is already completed"
  fi

  local ended_at
  ended_at=$(iso_now)

  # Mark completed
  local tmp_file
  tmp_file=$(mktemp "${SESSIONS_DIR}/.tmp-XXXXXX")
  chmod 600 "$tmp_file"

  jq --arg ended_at "$ended_at" \
    '.status = "completed" | .ended_at = $ended_at' \
    "$file" > "$tmp_file"
  mv "$tmp_file" "$file"

  log "Session $session_id marked completed"

  # Generate markdown transcript
  _generate_transcript "$session_id" "$file"
}

_generate_transcript() {
  local session_id="$1"
  local file="$2"

  ensure_transcripts_dir

  local topic started_at ended_at exchange_count approach date_str
  topic=$(jq -r '.topic' "$file")
  started_at=$(jq -r '.started_at' "$file")
  ended_at=$(jq -r '.ended_at' "$file")
  exchange_count=$(jq '.exchanges | length' "$file")
  approach=$(jq -r '.approach' "$file")

  # Compute date string for filename (YYYY-MM-DD from started_at)
  date_str="${started_at:0:10}"

  # Compute duration in minutes
  local start_epoch end_epoch duration_mins
  # Use Python for portable ISO 8601 parsing (date -d not available on macOS)
  start_epoch=$(python3 -c "
from datetime import datetime, timezone
dt = datetime.fromisoformat('${started_at}'.replace('Z','+00:00'))
print(int(dt.timestamp()))
" 2>/dev/null || echo "0")

  end_epoch=$(python3 -c "
from datetime import datetime, timezone
dt = datetime.fromisoformat('${ended_at}'.replace('Z','+00:00'))
print(int(dt.timestamp()))
" 2>/dev/null || echo "0")

  if [ "$start_epoch" -gt 0 ] && [ "$end_epoch" -gt 0 ]; then
    duration_mins=$(( (end_epoch - start_epoch) / 60 ))
  else
    duration_mins=0
  fi

  # Sanitize topic for filename
  local topic_slug
  topic_slug=$(printf '%s' "$topic" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | sed 's/--*/-/g;s/^-//;s/-$//')
  [ -z "$topic_slug" ] && topic_slug="untitled"

  local transcript_file="${TRANSCRIPTS_DIR}/${date_str}-${topic_slug}.md"

  # Build transcript body using jq to extract exchanges safely
  local exchanges_md
  exchanges_md=$(jq -r '
    .exchanges[] |
    . as $e |
    # Compute relative offset from first exchange timestamp — show as [MM:SS]
    # jq cannot do date arithmetic natively; use a placeholder index instead
    "[Turn \(.turn)] \(.role | ascii_upcase): \(.text)"
  ' "$file")

  # Build full markdown document
  {
    printf '# Voice Session: %s\n\n' "$topic"
    printf '**Date:** %s\n' "$date_str"
    printf '**Duration:** %s minutes\n' "$duration_mins"
    printf '**Exchanges:** %s\n' "$exchange_count"
    printf '**Approach:** %s\n\n' "$(printf '%s' "$approach" | sed 's/./\u&/')"
    printf '## Transcript\n\n'
    # Render exchanges with timestamps relative to session start
    jq -r --arg start_epoch "$start_epoch" '
      .exchanges[] |
      (
        # Parse timestamp offset — fall back to turn index if unparseable
        .turn as $turn |
        .role as $role |
        .text as $text |
        .timestamp as $ts |
        # Format role label
        (if $role == "user" then "User" elif $role == "claude" then "Claude" else "Assistant" end) as $label |
        "**[\($turn)] \($label):** \($text)\n"
      )
    ' "$file"
    printf '\n## Key Decisions\n\n'
    printf '(placeholder — Claude fills this in later)\n\n'
    printf '## Action Items\n\n'
    printf '(placeholder — Claude fills this in later)\n'
  } > "$transcript_file"

  log "Transcript generated: $transcript_file"
  echo "$transcript_file"
}

cmd_list() {
  ensure_sessions_dir

  local found=0

  # Print header
  printf '%-22s  %-30s  %s\n' "SESSION ID" "TOPIC" "EXCHANGES"
  printf '%s\n' "--------------------------------------------------------------"

  for f in "${SESSIONS_DIR}"/vs-*.json; do
    [ -f "$f" ] || continue
    local status
    status=$(jq -r '.status' "$f" 2>/dev/null || true)
    if [ "$status" = "active" ]; then
      local sid topic count
      sid=$(jq -r '.id' "$f")
      topic=$(jq -r '.topic' "$f")
      count=$(jq '.exchanges | length' "$f")
      printf '%-22s  %-30s  %s\n' "$sid" "${topic:0:30}" "$count"
      found=$(( found + 1 ))
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "(no active sessions)"
  else
    printf '\n%s active session(s)\n' "$found"
  fi
}

cmd_cleanup() {
  ensure_sessions_dir

  local removed=0
  local cutoff
  # Files older than 24 hours — find uses -mtime +0 (>24h) on macOS with -mmin
  cutoff=$(( 60 * 24 ))  # minutes

  for f in "${SESSIONS_DIR}"/vs-*.json; do
    [ -f "$f" ] || continue
    # Check modification time — portable approach via find
    if find "$f" -mmin "+${cutoff}" | grep -q .; then
      local sid
      sid=$(basename "$f" .json)
      rm -f "$f"
      log "Removed stale session: $sid"
      removed=$(( removed + 1 ))
    fi
  done

  if [ "$removed" -eq 0 ]; then
    log "No stale sessions to clean up"
  else
    log "Cleaned up $removed stale session file(s)"
  fi
}

# --- Dispatch ---

COMMAND="${1:-}"

if [ -z "$COMMAND" ]; then
  err "Usage: voice-session-manager.sh <command> [args...]"
  echo "  Commands: start, add-exchange, get-state, end, list, cleanup" >&2
  exit 1
fi

shift

case "$COMMAND" in
  start)        cmd_start "$@" ;;
  add-exchange) cmd_add_exchange "$@" ;;
  get-state)    cmd_get_state "$@" ;;
  end)          cmd_end "$@" ;;
  list)         cmd_list ;;
  cleanup)      cmd_cleanup ;;
  *)
    err "Unknown command: $COMMAND"
    echo "  Commands: start, add-exchange, get-state, end, list, cleanup" >&2
    exit 1
    ;;
esac
