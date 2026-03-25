#!/usr/bin/env bash
set -euo pipefail

# Transcribe a voice message (OGG/OGA) to text
# Uses Gemini (free) as primary, falls back to OpenAI Whisper ($0.006/min)
# Usage: bash scripts/transcribe-voice.sh <input-file> [--language en] [--provider gemini|whisper]
#
# Requires: GEMINI_API_KEY or OPENAI_API_KEY, ffmpeg, curl, base64
#
# Outputs the transcription text to stdout.
# Saves the transcription to a .txt file alongside the input.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

err() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log() { echo -e "${GREEN}[OK]${NC} $1" >&2; }

INPUT_FILE=""
LANGUAGE="en"
PROVIDER=""

# Parse all args (flags can appear in any order)
while [ $# -gt 0 ]; do
  case "$1" in
    --language)
      if [ $# -lt 2 ]; then
        err "--language requires a value (e.g. --language fr)"
        exit 1
      fi
      LANGUAGE="$2"; shift 2 ;;
    --provider)
      if [ $# -lt 2 ]; then
        err "--provider requires a value (gemini or whisper)"
        exit 1
      fi
      PROVIDER="$2"; shift 2 ;;
    --*) err "Unknown flag: $1"; exit 1 ;;
    *)
      if [ -n "$INPUT_FILE" ]; then
        err "Unexpected argument: $1 (input file already set to $INPUT_FILE)"
        exit 1
      fi
      INPUT_FILE="$1"; shift ;;
  esac
done

# Validate language is an ISO 639-1 code
if ! [[ "$LANGUAGE" =~ ^[a-z]{2,3}$ ]]; then
  err "Invalid language code: $LANGUAGE (expected ISO 639-1, e.g. en, fr, sw)"
  exit 1
fi

if [ -z "$INPUT_FILE" ]; then
  err "Usage: transcribe-voice.sh <input-file> [--language en]"
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  err "File not found: $INPUT_FILE"
  exit 1
fi

# Whisper API limit is 25 MB
FILE_SIZE=$(stat -f%z "$INPUT_FILE" 2>/dev/null || stat -c%s "$INPUT_FILE")
if [ "$FILE_SIZE" -gt 26214400 ]; then
  err "File too large ($(( FILE_SIZE / 1048576 ))MB). Whisper API limit is 25MB."
  exit 1
fi

# Check dependencies
if ! command -v ffmpeg &>/dev/null; then
  err "ffmpeg is required but not installed."
  echo "  macOS: brew install ffmpeg" >&2
  echo "  Ubuntu: sudo apt-get install -y ffmpeg" >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  err "curl is required but not installed."
  exit 1
fi

# Find API keys — try Gemini first (free), then Whisper (paid)
GEMINI_API_KEY="${GEMINI_API_KEY:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

# Load from .env.local or .env
for ENV_FILE in "$HOME/.claude/.env.local" "$HOME/.claude/.env"; do
  if [ -f "$ENV_FILE" ]; then
    [ -z "$GEMINI_API_KEY" ] && GEMINI_API_KEY=$(grep -s '^GEMINI_API_KEY=' "$ENV_FILE" | head -1 | sed 's/^GEMINI_API_KEY=//' | tr -d '[:space:]' || true)
    [ -z "$OPENAI_API_KEY" ] && OPENAI_API_KEY=$(grep -s '^OPENAI_API_KEY=' "$ENV_FILE" | head -1 | sed 's/^OPENAI_API_KEY=//' | tr -d '[:space:]' || true)
  fi
done

# Auto-select provider if not specified
if [ -z "$PROVIDER" ]; then
  if [ -n "$GEMINI_API_KEY" ]; then
    PROVIDER="gemini"
  elif [ -n "$OPENAI_API_KEY" ]; then
    PROVIDER="whisper"
  else
    err "No API key found. Set GEMINI_API_KEY (free) or OPENAI_API_KEY (paid)."
    echo "  Add to ~/.claude/.env.local:" >&2
    echo "  GEMINI_API_KEY=your-key-here" >&2
    exit 1
  fi
fi

log "Using provider: $PROVIDER"

# Convert OGG/OGA to MP3 (Whisper API accepts mp3, mp4, mpeg, mpga, m4a, wav, webm)
# Validate input is a local file path, not a URL (prevent ffmpeg SSRF)
if [[ "$INPUT_FILE" =~ :// ]]; then
  err "Input file must be a local path, not a URL: $INPUT_FILE"
  exit 1
fi

# Validate file extension
case "${INPUT_FILE##*.}" in
  ogg|oga|mp3|mp4|m4a|wav|webm|mpga|mpeg) ;;
  *) err "Unsupported file type: ${INPUT_FILE##*.}. Expected: ogg, oga, mp3, m4a, wav, webm"; exit 1 ;;
esac

BASENAME=$(basename "$INPUT_FILE")
BASENAME_NO_EXT="${BASENAME%.*}"
# Sanitize basename to prevent ffmpeg flag injection from filenames starting with -
BASENAME_NO_EXT=$(echo "$BASENAME_NO_EXT" | tr -cd 'a-zA-Z0-9._-' | sed 's/^-//')
[ -z "$BASENAME_NO_EXT" ] && BASENAME_NO_EXT="voice-note"
TMP_DIR=$(mktemp -d)
chmod 700 "$TMP_DIR"  # enforce restrictive permissions regardless of umask
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
MP3_FILE="$TMP_DIR/${BASENAME_NO_EXT}.mp3"

log "Converting to MP3..."
ffmpeg -i "$INPUT_FILE" -codec:a libmp3lame -qscale:a 4 -y "$MP3_FILE" 2>/dev/null

if [ ! -f "$MP3_FILE" ]; then
  err "ffmpeg conversion failed"
  exit 1
fi

# Transcribe based on provider
RESPONSE=""

if [ "$PROVIDER" = "gemini" ]; then
  log "Transcribing via Gemini (free)..."
  AUDIO_B64=$(base64 -i "$MP3_FILE" 2>/dev/null || base64 "$MP3_FILE" 2>/dev/null)

  GEMINI_RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"contents\": [{
        \"parts\": [
          {\"text\": \"Transcribe this audio exactly as spoken. Return ONLY the transcription text, no commentary, no formatting, no quotes.\"},
          {\"inline_data\": {\"mime_type\": \"audio/mp3\", \"data\": \"${AUDIO_B64}\"}}
        ]
      }]
    }" 2>&1)

  RESPONSE=$(echo "$GEMINI_RESPONSE" | python3 -c "
import json, sys
try:
    r = json.load(sys.stdin)
    text = r['candidates'][0]['content']['parts'][0]['text']
    print(text.strip())
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1) || {
    err "Gemini transcription failed. Falling back to Whisper..."
    PROVIDER="whisper"
  }
fi

if [ "$PROVIDER" = "whisper" ]; then
  if [ -z "$OPENAI_API_KEY" ]; then
    err "Whisper fallback failed — no OPENAI_API_KEY set."
    exit 1
  fi
  log "Transcribing via Whisper API..."
  CURL_CONFIG="$TMP_DIR/.curlrc"
  printf 'header = "Authorization: Bearer %s"\n' "$OPENAI_API_KEY" > "$CURL_CONFIG"
  chmod 600 "$CURL_CONFIG"
  RESPONSE=$(curl -s --fail-with-body --config "$CURL_CONFIG" -X POST "https://api.openai.com/v1/audio/transcriptions" \
    -F "file=@$MP3_FILE" \
    -F "model=whisper-1" \
    -F "language=$LANGUAGE" \
    -F "response_format=text" 2>&1) || { err "Whisper API request failed."; exit 1; }
fi

if [ -z "$RESPONSE" ]; then
  err "Whisper API returned empty response"
  exit 1
fi

# Save transcription alongside the original file (restrict to same directory)
# Use portable path resolution (realpath not available on all macOS versions)
RESOLVED_FILE=$(cd "$(dirname "$INPUT_FILE")" && pwd)/$(basename "$INPUT_FILE")
INPUT_DIR=$(dirname "$RESOLVED_FILE")
INPUT_BASE=$(basename "${RESOLVED_FILE%.*}")
TRANSCRIPT_FILE="$INPUT_DIR/${INPUT_BASE}.txt"
umask 077
echo "$RESPONSE" > "$TRANSCRIPT_FILE"
log "Transcription saved to: $TRANSCRIPT_FILE"

# Output the transcription to stdout
echo "$RESPONSE"
