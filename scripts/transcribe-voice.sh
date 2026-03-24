#!/usr/bin/env bash
set -euo pipefail

# Transcribe a voice message (OGG/OGA) to text via OpenAI Whisper API
# Usage: bash scripts/transcribe-voice.sh <input-file> [--language en]
#
# Requires: OPENAI_API_KEY environment variable, ffmpeg, curl
# Cost: ~$0.006 per minute of audio
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

# Parse all args (flags can appear in any order)
while [ $# -gt 0 ]; do
  case "$1" in
    --language)
      if [ $# -lt 2 ]; then
        err "--language requires a value (e.g. --language fr)"
        exit 1
      fi
      LANGUAGE="$2"; shift 2 ;;
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

# Find OPENAI_API_KEY
if [ -z "${OPENAI_API_KEY:-}" ]; then
  # Try loading from telegram .env
  TELEGRAM_ENV="$HOME/.claude/channels/telegram/.env"
  if [ -f "$TELEGRAM_ENV" ]; then
    OPENAI_API_KEY=$(grep -s '^OPENAI_API_KEY=' "$TELEGRAM_ENV" | head -1 | sed 's/^OPENAI_API_KEY=//' | sed 's/[[:space:]]*#.*//' | sed "s/^[\"']\(.*\)[\"']$/\1/" | tr -d '\r' || true)
  fi
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  err "OPENAI_API_KEY not found."
  echo "  Set it with: export OPENAI_API_KEY=your-key-here" >&2
  echo "  Or add to ~/.claude/channels/telegram/.env:" >&2
  echo "  OPENAI_API_KEY=your-key-here" >&2
  exit 1
fi

if ! [[ "$OPENAI_API_KEY" =~ ^[A-Za-z0-9_-]{10,}$ ]]; then
  err "OPENAI_API_KEY contains unexpected characters. Expected alphanumeric, hyphens, underscores."
  exit 1
fi

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
ffmpeg -i -- "$INPUT_FILE" -codec:a libmp3lame -qscale:a 4 -y "$MP3_FILE" 2>/dev/null

if [ ! -f "$MP3_FILE" ]; then
  err "ffmpeg conversion failed"
  exit 1
fi

# Call Whisper API (use curl config file to avoid exposing API key in process args)
log "Transcribing via Whisper API..."
CURL_CONFIG="$TMP_DIR/.curlrc"
printf 'header = "Authorization: Bearer %s"\n' "$OPENAI_API_KEY" > "$CURL_CONFIG"
chmod 600 "$CURL_CONFIG"
RESPONSE=$(curl -s --fail-with-body --config "$CURL_CONFIG" -X POST "https://api.openai.com/v1/audio/transcriptions" \
  -F "file=@$MP3_FILE" \
  -F "model=whisper-1" \
  -F "language=$LANGUAGE" \
  -F "response_format=text" 2>&1) || { err "Whisper API request failed (HTTP error). Re-run with VERBOSE=1 for details."; [ "${VERBOSE:-0}" = "1" ] && echo "$RESPONSE" >&2; exit 1; }

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
