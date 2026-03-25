#!/bin/bash

# Telegram Dispatch Runner — Spawns a headless Claude session for a dispatched command
# Usage: telegram-dispatch-runner.sh <command> <args> <project_dir> <session_name>
#
# Spawns a screen session running claude -p with the given command.
# Logs output to ~/.claude/logs/dispatch-<session_name>.log
# Updates ~/.claude/telegram-sessions.json on completion.
#
# CRITICAL: Does NOT use --channels (avoids 409 Telegram Bot API conflict).
# CRITICAL: Does NOT pipe stdout through tee (breaks TTY detection).

set -euo pipefail

COMMAND="${1:?Usage: telegram-dispatch-runner.sh <command> <args> <project_dir> <session_name>}"
ARGS="${2:-}"
PROJECT_DIR="${3:?Missing project_dir}"
SESSION_NAME="${4:?Missing session_name}"
CHAT_ID="${5:-}"

# Security: validate SESSION_NAME — alphanumeric, hyphens, underscores only
if [[ ! "$SESSION_NAME" =~ ^[a-zA-Z0-9_-]{1,64}$ ]]; then
  echo "BLOCKED: SESSION_NAME contains illegal characters: $SESSION_NAME" >&2
  exit 1
fi

# Security: validate PROJECT_DIR — must be a real path under $HOME
# Use cd+pwd instead of realpath -e (not available on macOS)
REAL_PROJECT_DIR=$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P) || { echo "BLOCKED: invalid project dir: $PROJECT_DIR" >&2; exit 1; }
if [[ "$REAL_PROJECT_DIR" != "$HOME"* ]]; then
  echo "BLOCKED: project dir outside \$HOME: $REAL_PROJECT_DIR" >&2
  exit 1
fi
PROJECT_DIR="$REAL_PROJECT_DIR"

# Security: validate command against allowlist to prevent arbitrary execution
ALLOWED_COMMANDS="ghost auto-ship auto-build auto-build-all auto-dev auto-plan check ship reflect pipeline-status ghost-status plan build dev spec code-review security-check generate-tests next-task darwin"
if ! echo "$ALLOWED_COMMANDS" | tr ' ' '\n' | grep -qx "$COMMAND"; then
  echo "BLOCKED: /$COMMAND is not in the dispatch allowlist" >&2
  exit 1
fi

# Security: validate ARGS — block shell metacharacters, allow natural language (max 300 chars)
# This is the primary injection boundary for NLP-routed natural language input.
# Allowed: alphanumeric, spaces, common punctuation for natural language (!?(),'".:-_/@#=+)
# Blocked: shell metacharacters (;|&$`\{}[]<>~^)
ARGS_BLOCK_PATTERN='[;|&$`\\{}<>~^]'
if [[ -n "$ARGS" ]]; then
  if [[ ${#ARGS} -gt 300 ]]; then
    echo "BLOCKED: ARGS exceeds 300 chars" >&2
    exit 1
  fi
  # Block control characters (newlines, carriage returns, null bytes) — prevents prompt injection
  if [[ "$ARGS" == *$'\n'* ]] || [[ "$ARGS" == *$'\r'* ]] || [[ "$ARGS" == *$'\0'* ]]; then
    echo "BLOCKED: ARGS contains control characters" >&2
    exit 1
  fi
  if [[ "$ARGS" =~ $ARGS_BLOCK_PATTERN ]]; then
    echo "BLOCKED: ARGS contains shell metacharacters" >&2
    exit 1
  fi
fi

LOG_DIR="$HOME/.claude/logs"
SESSION_FILE="$HOME/.claude/telegram-sessions.json"
QUEUE_FILE="$HOME/.claude/telegram-queue.json"
LOG_FILE="$LOG_DIR/dispatch-${SESSION_NAME}.log"

mkdir -p "$LOG_DIR"

# ─── Initialize session registry if absent ────────────────────────────────────

init_session_file() {
  if [[ ! -f "$SESSION_FILE" ]]; then
    echo '{"sessions":[]}' > "$SESSION_FILE"
  fi
}

# ─── Register session ─────────────────────────────────────────────────────────

register_session() {
  init_session_file
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  local tmp
  tmp=$(mktemp "${SESSION_FILE}.tmp.XXXXXX")
  jq --arg name "$SESSION_NAME" \
     --arg screen "$SESSION_NAME" \
     --arg cmd "$COMMAND" \
     --arg args "$ARGS" \
     --arg chat "$CHAT_ID" \
     --arg dir "$PROJECT_DIR" \
     --arg started "$now" \
     --arg log "$LOG_FILE" \
     '.sessions += [{
       session_name: $name,
       screen_name: $screen,
       command: $cmd,
       args: $args,
       chat_id: $chat,
       project_dir: $dir,
       started_at: $started,
       completed_at: null,
       exit_code: null,
       log_file: $log
     }]' "$SESSION_FILE" > "$tmp" && mv "$tmp" "$SESSION_FILE" || rm -f "$tmp"
}

# ─── Mark session complete ────────────────────────────────────────────────────

complete_session() {
  local exit_code="$1"
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  local tmp
  tmp=$(mktemp "${SESSION_FILE}.tmp.XXXXXX")
  jq --arg name "$SESSION_NAME" \
     --arg completed "$now" \
     --argjson code "$exit_code" \
     '(.sessions[] | select(.session_name == $name)) |= . + {
       completed_at: $completed,
       exit_code: $code
     }' "$SESSION_FILE" > "$tmp" && mv "$tmp" "$SESSION_FILE" || rm -f "$tmp"
}

# ─── Update queue status ─────────────────────────────────────────────────────

update_queue_status() {
  local status="$1"
  if [[ -f "$QUEUE_FILE" ]]; then
    local tmp
    tmp=$(mktemp "${QUEUE_FILE}.tmp.XXXXXX")
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq --arg name "$SESSION_NAME" \
       --arg status "$status" \
       --arg now "$now" \
       '(.queue[] | select(.screen_name == $name)) |= . + {
         status: $status,
         finished_at: (if $status == "completed" or $status == "failed" then $now else .finished_at end)
       }' "$QUEUE_FILE" > "$tmp" && mv "$tmp" "$QUEUE_FILE" 2>/dev/null || { rm -f "$tmp"; true; }
  fi
}

# ─── Send Telegram notification on completion ─────────────────────────────────

notify_telegram() {
  local exit_code="$1"
  local telegram_env="$HOME/.claude/channels/telegram/.env"
  local telegram_token=""

  if [[ -f "$telegram_env" ]]; then
    telegram_token=$(grep -m1 '^TELEGRAM_BOT_TOKEN=' "$telegram_env" 2>/dev/null | sed 's/^TELEGRAM_BOT_TOKEN=//; s/[[:space:]]*#.*//; s/[[:space:]]*$//' || echo "")
  fi

  if [[ -z "$telegram_token" ]] || [[ -z "$CHAT_ID" ]]; then
    return 0
  fi

  local emoji="✅"
  local status_text="completed"
  if [[ "$exit_code" -ne 0 ]]; then
    emoji="❌"
    status_text="failed (exit $exit_code)"
  fi

  # Get last 10 lines of log for context
  local log_tail=""
  if [[ -f "$LOG_FILE" ]]; then
    log_tail=$(tail -10 "$LOG_FILE" 2>/dev/null | head -c 2000 || echo "")
  fi

  # Sanitize ARGS for Telegram Markdown display (escape backticks)
  local safe_args
  safe_args=$(printf '%s' "$ARGS" | tr '`' "'")
  local tg_text="${emoji} *Task ${status_text}*\n\nCommand: \`/${COMMAND} ${safe_args}\`\nSession: \`${SESSION_NAME}\`"
  if [[ -n "$log_tail" ]]; then
    tg_text="${tg_text}\n\n\`\`\`\n${log_tail}\n\`\`\`"
  fi

  curl -s -o /dev/null -X POST \
    "https://api.telegram.org/bot${telegram_token}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=$(printf '%s' "$tg_text")" \
    --data-urlencode "parse_mode=Markdown" \
    --data-urlencode "disable_web_page_preview=true" \
    2>/dev/null || true
}

# ─── Main: spawn or execute ──────────────────────────────────────────────────

if [[ "${6:-}" == "--inner" ]]; then
  # Running inside screen session — execute the command
  register_session
  update_queue_status "running"

  echo "=== Dispatch Runner ===" >> "$LOG_FILE"
  echo "Command: /$COMMAND $ARGS" >> "$LOG_FILE"
  echo "Project: $PROJECT_DIR" >> "$LOG_FILE"
  echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG_FILE"
  echo "========================" >> "$LOG_FILE"

  cd "$PROJECT_DIR"

  EXIT_CODE=0
  claude -p \
    --dangerously-skip-permissions \
    "/$COMMAND $ARGS" \
    >> "$LOG_FILE" 2>&1 || EXIT_CODE=$?

  echo "" >> "$LOG_FILE"
  echo "=== Completed with exit code: $EXIT_CODE ===" >> "$LOG_FILE"
  echo "Finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG_FILE"

  complete_session "$EXIT_CODE"

  if [[ "$EXIT_CODE" -eq 0 ]]; then
    update_queue_status "completed"
  else
    update_queue_status "failed"
  fi

  # Send completion notification directly via Bot API
  notify_telegram "$EXIT_CODE"

  exit "$EXIT_CODE"
else
  # Outer invocation — spawn a screen session
  SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  screen -dmS "$SESSION_NAME" bash "$SCRIPT_PATH" "$COMMAND" "$ARGS" "$PROJECT_DIR" "$SESSION_NAME" "$CHAT_ID" --inner
  echo "Dispatched: screen session '$SESSION_NAME' started"
  echo "Log: $LOG_FILE"
fi
