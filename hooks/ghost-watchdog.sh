#!/bin/bash

# Ghost Mode — Process supervisor daemon
# Runs in a screen session, manages Claude process lifecycle with restart support.
# Usage: ghost-watchdog.sh [--inner-loop]

set -euo pipefail

CONFIG_FILE="$HOME/.claude/ghost-config.json"
STOP_FILE="$HOME/.claude/ghost-stop"
PID_FILE="$HOME/.claude/ghost-watchdog.pid"
LOG_DIR="$HOME/.claude/logs"
NOTIFY="bash $HOME/.claude/hooks/ghost-notify.sh"

mkdir -p "$LOG_DIR"

# ─── Config loading ───────────────────────────────────────────────────────────

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: ghost-config.json not found" >&2
    exit 1
  fi
  FEATURE=$(jq -r '.feature' "$CONFIG_FILE")
  TRUST=$(jq -r '.trust // "conservative"' "$CONFIG_FILE")
  BUDGET=$(jq -r '.budget_usd // 20' "$CONFIG_FILE")
  MAX_HOURS=$(jq -r '.max_hours // 8' "$CONFIG_FILE")
  MAX_TASKS=$(jq -r '.max_tasks // 10' "$CONFIG_FILE")
  PROJECT_DIR=$(jq -r '.project_dir' "$CONFIG_FILE")
  BRANCH=$(jq -r '.branch' "$CONFIG_FILE")
  STARTED=$(jq -r '.started' "$CONFIG_FILE")
  SESSION_ID=$(jq -r '.session_id // ""' "$CONFIG_FILE")
  TELEGRAM_ENABLED=$(jq -r '.telegram_enabled // "false"' "$CONFIG_FILE")
  LOG_FILE="$LOG_DIR/ghost-$(date +%Y%m%d-%H%M%S).log"
}

update_config_field() {
  local field="$1"
  local value="$2"
  local tmp
  tmp=$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")
  jq --arg f "$field" --arg v "$value" '.[$f] = $v' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE" || rm -f "$tmp"
}

# ─── Dry-run mode ─────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "Ghost Watchdog — Dry Run"
  echo "========================"
  load_config
  echo "Feature:     $FEATURE"
  echo "Trust:       $TRUST"
  echo "Budget:      \$$BUDGET"
  echo "Max Hours:   $MAX_HOURS"
  echo "Max Tasks:   $MAX_TASKS"
  echo "Project:     $PROJECT_DIR"
  echo "Branch:      $BRANCH"
  echo "Started:     $STARTED"
  echo ""
  echo "Would launch screen session: ghost-$(basename "$PROJECT_DIR")"
  echo "Would start caffeinate for $((MAX_HOURS * 3600)) seconds"
  echo "Would run claude -p in $PROJECT_DIR"
  echo ""
  echo "Pre-flight checks:"
  command -v screen >/dev/null 2>&1 && echo "  screen: OK" || echo "  screen: NOT FOUND"
  command -v caffeinate >/dev/null 2>&1 && echo "  caffeinate: OK" || echo "  caffeinate: NOT FOUND"
  command -v claude >/dev/null 2>&1 && echo "  claude: OK" || echo "  claude: NOT FOUND"
  command -v jq >/dev/null 2>&1 && echo "  jq: OK" || echo "  jq: NOT FOUND"
  [[ ! -f "$STOP_FILE" ]] && echo "  ghost-stop: clear" || echo "  ghost-stop: EXISTS (would abort)"
  exit 0
fi

# ─── Screen launcher (outer invocation) ───────────────────────────────────────

if [[ "${1:-}" != "--inner-loop" ]]; then
  load_config
  SCREEN_NAME="ghost-$(basename "$PROJECT_DIR")"

  # Check for existing ghost session
  if screen -ls 2>/dev/null | grep -q "$SCREEN_NAME"; then
    echo "ERROR: Ghost session '$SCREEN_NAME' already running."
    echo "Attach with: screen -r $SCREEN_NAME"
    echo "Kill with:   touch ~/.claude/ghost-stop"
    exit 1
  fi

  # Launch self in screen
  screen -dmS "$SCREEN_NAME" bash "$0" --inner-loop
  echo "Ghost watchdog launched in screen session: $SCREEN_NAME"
  echo "Attach with:  screen -r $SCREEN_NAME"
  echo "Stop with:    touch ~/.claude/ghost-stop"
  exit 0
fi

# ─── Inner loop (runs inside screen) ─────────────────────────────────────────

load_config

# Write PID file
echo $$ > "$PID_FILE"

# Start caffeinate to prevent macOS sleep (macOS only)
TIMEOUT_SECS=$((MAX_HOURS * 3600))
CAFFEINATE_PID=""
if command -v caffeinate &>/dev/null; then
  caffeinate -dims -t "$TIMEOUT_SECS" &
  CAFFEINATE_PID=$!
fi

# Calculate deadline
DEADLINE=$(($(date +%s) + TIMEOUT_SECS))

# Cleanup function
cleanup() {
  [[ -n "$CAFFEINATE_PID" ]] && kill "$CAFFEINATE_PID" 2>/dev/null || true
  rm -f "$PID_FILE"
  rm -f "$STOP_FILE"
  update_config_field "status" "stopped"
}
trap cleanup EXIT

$NOTIFY start "Ghost Mode started: $FEATURE (trust=$TRUST, budget=\$$BUDGET, max=${MAX_HOURS}h)"
update_config_field "status" "running"

# ─── Git recovery ─────────────────────────────────────────────────────────────

check_git_state() {
  cd "$PROJECT_DIR"

  # Fetch latest
  git fetch origin 2>/dev/null || true

  # Check if we're on the right branch
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
    git checkout "$BRANCH" 2>/dev/null || {
      $NOTIFY warning "Git: failed to checkout $BRANCH"
      return 1
    }
  fi

  # Check if behind remote and auto-rebase
  BEHIND=$(git rev-list --count HEAD..origin/"$BRANCH" 2>/dev/null || echo "0")
  if [[ "$BEHIND" -gt 0 ]]; then
    # Abort any in-progress rebase
    git rebase --abort 2>/dev/null || true
    git rebase origin/"$BRANCH" 2>/dev/null || {
      git rebase --abort 2>/dev/null || true
      $NOTIFY warning "Git: rebase failed, continuing with current state"
    }
  fi

  return 0
}

# ─── Pipeline completion check ────────────────────────────────────────────────

pipeline_is_done() {
  # Check if checkpoint file is gone (deleted on successful completion by auto-ship)
  # BUT only consider it "done" if a PR URL exists — otherwise the pipeline never started
  local checkpoint="$PROJECT_DIR/.claude/pipeline-checkpoint.json"
  if [[ ! -f "$checkpoint" ]]; then
    local pr_url
    pr_url=$(jq -r '.pr_url // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
    if [[ -n "$pr_url" && "$pr_url" != "null" ]]; then
      return 0  # checkpoint gone + PR exists = genuinely complete
    fi
    return 1  # checkpoint gone + no PR = never started
  fi

  # Check if checkpoint shows phase 4+ (ship complete)
  local phase
  phase=$(jq -r '.phase // 0' "$checkpoint" 2>/dev/null || echo "0")
  # Use integer comparison — phase 4 = ship, 5 = post-ship
  if [[ "$phase" =~ ^[0-9]+$ ]] && (( phase >= 4 )); then
    return 0
  fi

  return 1
}

# ─── Restart loop ─────────────────────────────────────────────────────────────

MAX_ATTEMPTS=3
ATTEMPT=0
BACKOFF=15

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
  ATTEMPT=$((ATTEMPT + 1))

  # Check emergency stop
  if [[ -f "$STOP_FILE" ]]; then
    $NOTIFY warning "Emergency stop file detected. Shutting down."
    update_config_field "status" "stopped_emergency"
    exit 0
  fi

  # Check wall-clock timeout
  NOW=$(date +%s)
  if [[ $NOW -ge $DEADLINE ]]; then
    $NOTIFY warning "Wall-clock timeout reached (${MAX_HOURS}h). Shutting down."
    update_config_field "status" "timeout"
    exit 0
  fi

  # Git recovery
  check_git_state || true

  # Check if pipeline already completed (from a previous run)
  if pipeline_is_done; then
    # Look for PR URL in config
    PR_URL=$(jq -r '.pr_url // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
    $NOTIFY success "Pipeline already complete!" "$PR_URL"
    update_config_field "status" "complete"
    exit 0
  fi

  update_config_field "status" "running_attempt_${ATTEMPT}"
  $NOTIFY phase "Starting attempt $ATTEMPT/$MAX_ATTEMPTS"

  # Build claude command
  START_TIME=$(date +%s)

  cd "$PROJECT_DIR"

  # Conditionally add --channels for Telegram bidirectional communication
  # WARNING: Only one bot poller per token allowed. If the persistent
  # telegram listener (start-telegram-server.sh) is running, do NOT
  # enable --channels here — stop the listener first.
  CHANNELS_FLAG=""
  if [[ "$TELEGRAM_ENABLED" == "true" ]]; then
    CHANNELS_FLAG="--channels plugin:telegram@claude-plugins-official"
  fi

  # IMPORTANT: Do NOT pipe stdout through tee — piping breaks TTY detection.
  # Use >> redirect instead. Same constraint as start-telegram-server.sh.
  # NOTE: --output-format text suppresses telemetry JSON in stdout.
  # NOTE: CHANNELS_FLAG must be word-split (no quotes) when non-empty.

  # Build the prompt and write to temp file to avoid shell quoting issues
  # with special characters (em-dashes, parentheses, etc.)
  PROMPT_FILE="$(mktemp)"
  if [[ $ATTEMPT -eq 1 ]] && [[ -z "$SESSION_ID" || "$SESSION_ID" == "null" ]]; then
    printf '%s' "/ghost-run ${FEATURE}" > "$PROMPT_FILE"
  elif [[ -n "$SESSION_ID" && "$SESSION_ID" != "null" ]]; then
    printf '%s' "/auto-ship" > "$PROMPT_FILE"
  else
    printf '%s' "/auto-ship ${FEATURE}" > "$PROMPT_FILE"
  fi

  echo "[$(date)] Running claude -p with prompt from $PROMPT_FILE" >> "$LOG_FILE"
  echo "[$(date)] Prompt: $(cat "$PROMPT_FILE")" >> "$LOG_FILE"

  # Feed prompt via stdin from file — avoids all shell quoting issues
  # Use array to prevent word-splitting issues with argument values
  CLAUDE_ARGS=("--dangerously-skip-permissions" "--output-format" "text" "--max-budget-usd" "$BUDGET")
  if [[ -n "$CHANNELS_FLAG" ]]; then
    CLAUDE_ARGS+=("--channels" "plugin:telegram@claude-plugins-official")
  fi
  if [[ -n "$SESSION_ID" && "$SESSION_ID" != "null" && $ATTEMPT -gt 1 ]]; then
    CLAUDE_ARGS+=("--resume" "$SESSION_ID")
  fi

  claude -p "${CLAUDE_ARGS[@]}" < "$PROMPT_FILE" >> "$LOG_FILE" 2>&1 || true
  rm -f "$PROMPT_FILE"

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  # Extract session ID from log if available (for resume on restart)
  CAPTURED_SESSION=$(grep -o 'session_id=[^ ]*' "$LOG_FILE" 2>/dev/null | tail -1 | cut -d= -f2 || echo "")
  if [[ -n "$CAPTURED_SESSION" ]]; then
    update_config_field "session_id" "$CAPTURED_SESSION"
    SESSION_ID="$CAPTURED_SESSION"
  fi

  # Check if pipeline completed
  if pipeline_is_done; then
    PR_URL=$(jq -r '.pr_url // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
    # Also try to find PR URL in the log
    if [[ -z "$PR_URL" || "$PR_URL" == "null" ]]; then
      PR_URL=$(grep -oE 'https://github\.com/[^ ]+/pull/[0-9]+' "$LOG_FILE" 2>/dev/null | tail -1 || echo "")
      if [[ -n "$PR_URL" ]]; then
        update_config_field "pr_url" "$PR_URL"
      fi
    fi
    $NOTIFY success "Pipeline complete! PR ready for review." "$PR_URL"
    update_config_field "status" "complete"
    exit 0
  fi

  # Check for guardrail block
  STATUS=$(jq -r '.status // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
  if [[ "$STATUS" == "blocked_guardrail" ]]; then
    $NOTIFY failure "Guardrail blocked the pipeline. Manual review required."
    exit 1
  fi

  # Check for budget exhaustion
  if grep -qi "budget" "$LOG_FILE" 2>/dev/null && [[ $DURATION -lt 120 ]]; then
    $NOTIFY failure "Budget likely exhausted. Pipeline stopped."
    update_config_field "status" "budget_exhausted"
    exit 1
  fi

  # Rate limit detection: if Claude exited in < 60s, likely a 429 storm
  if [[ $DURATION -lt 60 ]]; then
    BACKOFF=300
    $NOTIFY warning "Rapid exit detected (${DURATION}s). Backing off 5 minutes before retry."
    sleep $BACKOFF
  else
    # Normal backoff between restarts
    $NOTIFY warning "Claude exited after ${DURATION}s. Restarting in ${BACKOFF}s (attempt $((ATTEMPT+1))/$MAX_ATTEMPTS)."
    sleep $BACKOFF
    BACKOFF=$((BACKOFF * 2))  # Exponential backoff: 30, 60, 120, 240
  fi
done

# Exhausted all attempts
$NOTIFY failure "Ghost Mode exhausted all $MAX_ATTEMPTS restart attempts."
update_config_field "status" "exhausted"
exit 1
