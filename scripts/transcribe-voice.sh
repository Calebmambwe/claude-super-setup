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

INPUT_FILE="${1:-}"
LANGUAGE="en"

# Parse optional args
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --language) LANGUAGE="${2:-en}"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$INPUT_FILE" ]; then
  err "Usage: transcribe-voice.sh <input-file> [--language en]"
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  err "File not found: $INPUT_FILE"
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
    OPENAI_API_KEY=$(grep -s '^OPENAI_API_KEY=' "$TELEGRAM_ENV" | sed 's/^OPENAI_API_KEY=//' | sed 's/[[:space:]]*#.*//' | sed "s/^[\"']\(.*\)[\"']$/\1/" | tr -d '\r' || true)
  fi
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  err "OPENAI_API_KEY not found."
  echo "  Set it with: export OPENAI_API_KEY=your-key-here" >&2
  echo "  Or add to ~/.claude/channels/telegram/.env:" >&2
  echo "  OPENAI_API_KEY=your-key-here" >&2
  exit 1
fi

# Convert OGG/OGA to MP3 (Whisper API accepts mp3, mp4, mpeg, mpga, m4a, wav, webm)
BASENAME=$(basename "$INPUT_FILE")
BASENAME_NO_EXT="${BASENAME%.*}"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM
MP3_FILE="$TMP_DIR/${BASENAME_NO_EXT}.mp3"

log "Converting to MP3..."
ffmpeg -i "$INPUT_FILE" -codec:a libmp3lame -qscale:a 4 -y "$MP3_FILE" 2>/dev/null

if [ ! -f "$MP3_FILE" ]; then
  err "ffmpeg conversion failed"
  exit 1
fi

# Call Whisper API
log "Transcribing via Whisper API..."
RESPONSE=$(curl -s --fail -X POST "https://api.openai.com/v1/audio/transcriptions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "file=@$MP3_FILE" \
  -F "model=whisper-1" \
  -F "language=$LANGUAGE" \
  -F "response_format=text") || { err "Whisper API request failed"; exit 1; }

if [ -z "$RESPONSE" ]; then
  err "Whisper API returned empty response"
  exit 1
fi

# Save transcription alongside the original file (restrict to same directory)
INPUT_DIR=$(dirname "$(realpath "$INPUT_FILE")")
INPUT_BASE=$(basename "${INPUT_FILE%.*}")
TRANSCRIPT_FILE="$INPUT_DIR/${INPUT_BASE}.txt"
echo "$RESPONSE" > "$TRANSCRIPT_FILE"
log "Transcription saved to: $TRANSCRIPT_FILE"

# Output the transcription to stdout
echo "$RESPONSE"
