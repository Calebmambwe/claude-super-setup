---
name: budget-status
description: Show current token/tool-call budget usage for the active session
---

# /budget-status

Show current token/tool-call budget usage for the active session.

## What it does

Reads `~/.claude/budget-tracker.json` and prints a formatted summary:
- Tool calls used vs. the configured maximum
- Subagent calls used vs. the configured maximum
- Budget utilisation percentage for each counter
- Active session ID and duration since session start
- Last tool called and when the tracker was last updated

## Implementation

```bash
TRACKER="$HOME/.claude/budget-tracker.json"
MAX_CALLS="${TASK_MAX_TOOL_CALLS:-200}"
MAX_AGENTS="${TASK_MAX_SUBAGENTS:-20}"

if [ ! -f "$TRACKER" ]; then
  echo "No active budget tracking (tracker file not found: $TRACKER)"
  exit 0
fi

SESSION=$(jq -r '.session_id    // "unknown"' "$TRACKER")
STARTED=$(jq -r '.started_at   // "unknown"' "$TRACKER")
CALLS=$(jq -r   '.tool_calls   // 0'         "$TRACKER")
AGENTS=$(jq -r  '.subagent_calls // 0'       "$TRACKER")
LAST=$(jq -r    '.last_tool    // "unknown"' "$TRACKER")
UPDATED=$(jq -r '.last_updated // "unknown"' "$TRACKER")

# Compute percentages (integer arithmetic)
PCT_CALLS=$(( CALLS  * 100 / MAX_CALLS  ))
PCT_AGENTS=$(( AGENTS * 100 / MAX_AGENTS ))

# Compute session duration (macOS + Linux compatible)
if command -v python3 >/dev/null 2>&1 && [ "$STARTED" != "unknown" ]; then
  DURATION=$(python3 -c "
from datetime import datetime, timezone
fmt = '%Y-%m-%dT%H:%M:%SZ'
try:
    start = datetime.strptime('$STARTED', fmt).replace(tzinfo=timezone.utc)
    now   = datetime.now(timezone.utc)
    diff  = int((now - start).total_seconds())
    h, rem = divmod(diff, 3600)
    m, s   = divmod(rem, 60)
    print(f'{h}h {m}m {s}s')
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")
else
  DURATION="unknown"
fi

# Build a simple progress bar (20 chars wide)
bar() {
  local pct=$1 width=20
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  printf '%0.s#' $(seq 1 $filled 2>/dev/null || true)
  printf '%0.s-' $(seq 1 $empty  2>/dev/null || true)
}

CALLS_BAR=$(bar "$PCT_CALLS")
AGENTS_BAR=$(bar "$PCT_AGENTS")

# Colour codes (only when connected to a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; RESET='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; RESET=''
fi

colour_for() {
  local pct=$1
  if   [ "$pct" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$pct" -ge 70 ]; then printf '%s' "$YELLOW"
  else                          printf '%s' "$GREEN"
  fi
}

CALLS_CLR=$(colour_for "$PCT_CALLS")
AGENTS_CLR=$(colour_for "$PCT_AGENTS")

printf '\n'
printf '╔══════════════════════════════════════════╗\n'
printf '║         Budget Status — /budget-status   ║\n'
printf '╠══════════════════════════════════════════╣\n'
printf '║  Session   : %-28s║\n' "$SESSION"
printf '║  Duration  : %-28s║\n' "$DURATION"
printf '║  Last tool : %-28s║\n' "$LAST"
printf '║  Updated   : %-28s║\n' "$UPDATED"
printf '╠══════════════════════════════════════════╣\n'
printf "║  Tool calls: %b[%s]%b %d / %d (%d%%)\n" \
  "$CALLS_CLR" "$CALLS_BAR" "$RESET" "$CALLS" "$MAX_CALLS" "$PCT_CALLS"
printf "║  Subagents : %b[%s]%b %d / %d (%d%%)\n" \
  "$AGENTS_CLR" "$AGENTS_BAR" "$RESET" "$AGENTS" "$MAX_AGENTS" "$PCT_AGENTS"
printf '╠══════════════════════════════════════════╣\n'

if [ "$PCT_CALLS" -ge 90 ] || [ "$PCT_AGENTS" -ge 90 ]; then
  printf '║  ⚠  WARNING: near budget limit!          ║\n'
  printf '║  Override: TASK_MAX_TOOL_CALLS=500        ║\n'
  printf '║            TASK_MAX_SUBAGENTS=50           ║\n'
elif [ "$PCT_CALLS" -ge 70 ] || [ "$PCT_AGENTS" -ge 70 ]; then
  printf '║  Note: approaching budget limit.          ║\n'
else
  printf '║  Budget healthy.                          ║\n'
fi

printf '╚══════════════════════════════════════════╝\n'
printf '\n'
printf 'Log: ~/.claude/logs/budget.log\n'
```

## Usage

```
/budget-status
```

No arguments. Run at any time to check how many tool calls the current session has consumed.

## Overriding limits

```bash
# Raise tool-call cap for this session
TASK_MAX_TOOL_CALLS=500 claude

# Raise subagent cap for this session
TASK_MAX_SUBAGENTS=50 claude
```

Both env vars are read by `hooks/budget-guard.sh` on every tool call.

## Related

- `hooks/budget-guard.sh` — the PostToolUse hook that enforces limits
- `~/.claude/budget-tracker.json` — the live tracker file
- `~/.claude/logs/budget.log` — log of milestone and block events
