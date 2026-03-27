#!/usr/bin/env bash
set -euo pipefail

# Voice-to-SDLC Pipeline
# Takes a completed voice session transcript and generates a feature brief,
# then optionally triggers /auto-dev.
#
# Usage: voice-to-sdlc.sh <session_id|transcript_path> [--auto] [--feature-name name]
#
# Requires: jq, voice-session-manager.sh (for session IDs)
#
# Outputs:
#   - Cleaned transcript saved to docs/voice-sessions/
#   - Feature brief saved to docs/{feature-name}/brief.md
#   - Updated docs/FEATURES.md registry

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

err() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
info() { echo -e "${CYAN}[INFO]${NC} $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SESSION_MGR="$SCRIPT_DIR/voice-session-manager.sh"

INPUT=""
AUTO_DEV=false
FEATURE_NAME=""

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --auto) AUTO_DEV=true; shift ;;
    --feature-name)
      if [ $# -lt 2 ]; then err "--feature-name requires a value"; exit 1; fi
      FEATURE_NAME="$2"; shift 2 ;;
    --*) err "Unknown flag: $1"; exit 1 ;;
    *)
      if [ -n "$INPUT" ]; then err "Unexpected argument: $1"; exit 1; fi
      INPUT="$1"; shift ;;
  esac
done

if [ -z "$INPUT" ]; then
  err "Usage: voice-to-sdlc.sh <session_id|transcript_path> [--auto] [--feature-name name]"
  exit 1
fi

# Check dependencies
for cmd in jq; do
  if ! command -v "$cmd" &>/dev/null; then
    err "$cmd is required but not installed."
    exit 1
  fi
done

# Determine if input is a session ID or transcript path
SESSION_JSON=""
TRANSCRIPT_TEXT=""

if [[ "$INPUT" =~ ^vs-[0-9]{8}-[0-9]{6}$ ]]; then
  # It's a session ID — load from session manager
  info "Loading session: $INPUT"
  SESSION_FILE="/tmp/voice-sessions/${INPUT}.json"
  if [ ! -f "$SESSION_FILE" ]; then
    err "Session file not found: $SESSION_FILE"
    exit 1
  fi
  SESSION_JSON=$(cat "$SESSION_FILE")

  # Check session is completed
  STATUS=$(echo "$SESSION_JSON" | jq -r '.status')
  if [ "$STATUS" = "active" ]; then
    info "Session is still active. Ending it first..."
    bash "$SESSION_MGR" end "$INPUT" 2>/dev/null || true
    SESSION_JSON=$(cat "$SESSION_FILE")
  fi

  # Build transcript text from exchanges
  TRANSCRIPT_TEXT=$(echo "$SESSION_JSON" | jq -r '
    .exchanges[] |
    "[" + .timestamp + "] " +
    (if .role == "user" then "User" else "Claude" end) +
    ": " + .text
  ')

  # Extract topic
  if [ -z "$FEATURE_NAME" ]; then
    FEATURE_NAME=$(echo "$SESSION_JSON" | jq -r '.topic // "untitled"')
  fi

elif [ -f "$INPUT" ]; then
  # It's a transcript file path
  info "Loading transcript: $INPUT"
  TRANSCRIPT_TEXT=$(cat "$INPUT")

  if [ -z "$FEATURE_NAME" ]; then
    # Try to extract name from filename
    FEATURE_NAME=$(basename "$INPUT" .md | sed 's/^[0-9-]*//' | sed 's/^-//')
    [ -z "$FEATURE_NAME" ] && FEATURE_NAME="untitled"
  fi
else
  err "Input not found: $INPUT (expected session ID or file path)"
  exit 1
fi

if [ -z "$TRANSCRIPT_TEXT" ]; then
  err "Transcript is empty. Nothing to process."
  exit 1
fi

# Sanitize feature name to kebab-case
FEATURE_NAME=$(echo "$FEATURE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | tr -cd 'a-z0-9-' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
[ -z "$FEATURE_NAME" ] && FEATURE_NAME="voice-feature-$(date +%s)"

info "Feature name: $FEATURE_NAME"
info "Transcript length: $(echo "$TRANSCRIPT_TEXT" | wc -l | tr -d ' ') lines"

# Create feature directory
FEATURE_DIR="$PROJECT_DIR/docs/$FEATURE_NAME"
mkdir -p "$FEATURE_DIR"

# Save raw transcript
TRANSCRIPT_DATE=$(date +%Y-%m-%d)
TRANSCRIPT_FILE="$PROJECT_DIR/docs/voice-sessions/${TRANSCRIPT_DATE}-${FEATURE_NAME}.md"
mkdir -p "$PROJECT_DIR/docs/voice-sessions"

EXCHANGE_COUNT=0
DURATION="unknown"
if [ -n "$SESSION_JSON" ]; then
  EXCHANGE_COUNT=$(echo "$SESSION_JSON" | jq '.exchanges | length')
  START=$(echo "$SESSION_JSON" | jq -r '.started_at // empty')
  END=$(echo "$SESSION_JSON" | jq -r '.ended_at // empty')
  if [ -n "$START" ] && [ -n "$END" ]; then
    # Calculate duration in minutes (portable)
    START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$START" +%s 2>/dev/null || date -d "$START" +%s 2>/dev/null || echo "0")
    END_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$END" +%s 2>/dev/null || date -d "$END" +%s 2>/dev/null || echo "0")
    if [ "$START_EPOCH" -gt 0 ] && [ "$END_EPOCH" -gt 0 ]; then
      DURATION=$(( (END_EPOCH - START_EPOCH) / 60 ))
    fi
  fi
fi

cat > "$TRANSCRIPT_FILE" << TRANSCRIPT_EOF
# Voice Session: ${FEATURE_NAME}

**Date:** ${TRANSCRIPT_DATE}
**Duration:** ${DURATION} minutes
**Exchanges:** ${EXCHANGE_COUNT}
**Approach:** $(echo "$SESSION_JSON" | jq -r '.approach // "unknown"')

## Transcript

${TRANSCRIPT_TEXT}

## Key Decisions
_(To be extracted by Claude during brief generation)_

## Action Items
_(To be extracted by Claude during brief generation)_
TRANSCRIPT_EOF

log "Transcript saved: $TRANSCRIPT_FILE"

# Generate feature brief
BRIEF_FILE="$FEATURE_DIR/brief.md"

cat > "$BRIEF_FILE" << BRIEF_EOF
# Feature Brief: ${FEATURE_NAME}

**Date:** ${TRANSCRIPT_DATE}
**Status:** Draft (from voice session)
**Source:** Voice brainstorm session (${EXCHANGE_COUNT} exchanges, ${DURATION} min)
**Transcript:** [${TRANSCRIPT_DATE}-${FEATURE_NAME}.md](../voice-sessions/${TRANSCRIPT_DATE}-${FEATURE_NAME}.md)

---

## Voice Session Summary

The following brief was generated from a voice brainstorming session. Review and refine before triggering /auto-dev.

## Raw Transcript

\`\`\`
${TRANSCRIPT_TEXT}
\`\`\`

---

_This brief needs Claude to process the transcript into structured sections._
_Run: claude "Read $BRIEF_FILE and $TRANSCRIPT_FILE, then rewrite the brief with structured Problem, Solution, Target User, Constraints, Out of Scope, and Success Metrics sections extracted from the transcript."_

BRIEF_EOF

log "Brief saved: $BRIEF_FILE"

# Update FEATURES.md registry
FEATURES_FILE="$PROJECT_DIR/docs/FEATURES.md"
if [ -f "$FEATURES_FILE" ]; then
  # Check if feature already exists
  if ! grep -q "\[${FEATURE_NAME}\]" "$FEATURES_FILE"; then
    echo "| [${FEATURE_NAME}](${FEATURE_NAME}/brief.md) | 📝 Brief | [brief.md](${FEATURE_NAME}/brief.md) | — | Generated from voice session (${TRANSCRIPT_DATE}) |" >> "$FEATURES_FILE"
    log "Registry updated: $FEATURES_FILE"
  else
    warn "Feature already in registry: $FEATURE_NAME"
  fi
else
  warn "FEATURES.md not found. Skipping registry update."
fi

# Output summary
echo ""
echo -e "${GREEN}━━━ Voice-to-SDLC Pipeline Complete ━━━${NC}"
echo ""
echo -e "  Transcript: ${CYAN}$TRANSCRIPT_FILE${NC}"
echo -e "  Brief:      ${CYAN}$BRIEF_FILE${NC}"
echo -e "  Feature:    ${CYAN}$FEATURE_NAME${NC}"
echo ""

if [ "$AUTO_DEV" = true ]; then
  echo -e "${YELLOW}Auto-dev mode: triggering /auto-dev for $FEATURE_NAME${NC}"
  echo ""
  echo "SDLC_TRIGGER=auto-dev"
  echo "FEATURE_NAME=$FEATURE_NAME"
  echo "BRIEF_PATH=$BRIEF_FILE"
  echo "TRANSCRIPT_PATH=$TRANSCRIPT_FILE"
else
  echo -e "  Next steps:"
  echo -e "    1. Review and refine the brief: ${CYAN}$BRIEF_FILE${NC}"
  echo -e "    2. Run: ${CYAN}/auto-dev $FEATURE_NAME${NC}"
  echo ""
  echo -e "  Or re-run with --auto to trigger immediately:"
  echo -e "    ${CYAN}bash $0 $INPUT --auto${NC}"
fi
