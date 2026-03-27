#!/usr/bin/env bash
set -euo pipefail

# Generate voice audio from text using Gemini TTS API
# Outputs an OGG file compatible with Telegram's sendVoice
# Usage: gemini-tts.sh "Text to speak" [output.ogg] [--voice Kore] [--language en]
#
# Requires: GEMINI_API_KEY, ffmpeg, curl, base64, python3
#
# Prints the output file path to stdout.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

err() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log() { echo -e "${GREEN}[OK]${NC} $1" >&2; }

INPUT_TEXT=""
OUTPUT_FILE=""
VOICE_NAME="Kore"
LANGUAGE="en"

# Parse all args (flags can appear in any order)
while [ $# -gt 0 ]; do
  case "$1" in
    --voice)
      if [ $# -lt 2 ]; then
        err "--voice requires a value (e.g. --voice Kore)"
        exit 1
      fi
      VOICE_NAME="$2"; shift 2 ;;
    --language)
      if [ $# -lt 2 ]; then
        err "--language requires a value (e.g. --language en)"
        exit 1
      fi
      LANGUAGE="$2"; shift 2 ;;
    --*) err "Unknown flag: $1"; exit 1 ;;
    *)
      if [ -z "$INPUT_TEXT" ]; then
        INPUT_TEXT="$1"; shift
      elif [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$1"; shift
      else
        err "Unexpected argument: $1"
        exit 1
      fi
      ;;
  esac
done

# Validate inputs
if [ -z "$INPUT_TEXT" ]; then
  err "Usage: gemini-tts.sh \"Text to speak\" [output.ogg] [--voice Kore] [--language en]"
  exit 1
fi

# Validate text is not a URL (security: prevent SSRF-style abuse)
if [[ "$INPUT_TEXT" =~ :// ]]; then
  err "Input text must be plain text, not a URL: $INPUT_TEXT"
  exit 1
fi

# Validate language is an ISO 639-1 code
if ! [[ "$LANGUAGE" =~ ^[a-z]{2,3}$ ]]; then
  err "Invalid language code: $LANGUAGE (expected ISO 639-1, e.g. en, fr, sw)"
  exit 1
fi

# Validate voice name is safe (alphanumeric only — prevent JSON injection)
if ! [[ "$VOICE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  err "Invalid voice name: $VOICE_NAME (expected alphanumeric, e.g. Kore, Charon, Fenrir)"
  exit 1
fi

# Default output path if not specified
if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="/tmp/tts-$(date +%s).ogg"
fi

# Validate output path is not a URL
if [[ "$OUTPUT_FILE" =~ :// ]]; then
  err "Output path must be a local path, not a URL: $OUTPUT_FILE"
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

if ! command -v python3 &>/dev/null; then
  err "python3 is required but not installed."
  exit 1
fi

# Load GEMINI_API_KEY — env var takes priority, then .env.local, then .env
GEMINI_API_KEY="${GEMINI_API_KEY:-}"

for ENV_FILE in "$HOME/.claude/.env.local" "$HOME/.claude/.env"; do
  if [ -f "$ENV_FILE" ]; then
    [ -z "$GEMINI_API_KEY" ] && GEMINI_API_KEY=$(grep -s '^GEMINI_API_KEY=' "$ENV_FILE" | head -1 | sed 's/^GEMINI_API_KEY=//' | tr -d '[:space:]' || true)
  fi
done

if [ -z "$GEMINI_API_KEY" ]; then
  err "No GEMINI_API_KEY found. Set the environment variable or add it to ~/.claude/.env.local"
  echo "  Add to ~/.claude/.env.local:" >&2
  echo "  GEMINI_API_KEY=your-key-here" >&2
  exit 1
fi

# Set up temp dir with restrictive permissions and cleanup trap
TMP_DIR=$(mktemp -d)
chmod 700 "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

RAW_AUDIO_FILE="$TMP_DIR/tts_raw_audio"

log "Calling Gemini TTS API (voice: $VOICE_NAME)..."

# Build request JSON via python3 to safely escape the text (prevents JSON injection)
REQUEST_JSON=$(python3 -c "
import json, sys
text = sys.argv[1]
voice = sys.argv[2]
payload = {
    'contents': [{'parts': [{'text': text}]}],
    'generationConfig': {
        'response_modalities': ['AUDIO'],
        'speech_config': {
            'voice_config': {
                'prebuilt_voice_config': {
                    'voice_name': voice
                }
            }
        }
    }
}
print(json.dumps(payload))
" "$INPUT_TEXT" "$VOICE_NAME") || {
  err "Failed to build request JSON"
  exit 1
}

GEMINI_RESPONSE=$(curl -s --fail-with-body \
  -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_JSON" 2>&1) || {
  err "Gemini API request failed (network error or non-2xx response)"
  exit 1
}

if [ -z "$GEMINI_RESPONSE" ]; then
  err "Gemini API returned an empty response"
  exit 1
fi

# Check for API-level error in the response body
if echo "$GEMINI_RESPONSE" | python3 -c "import json,sys; r=json.load(sys.stdin); sys.exit(0 if 'error' not in r else 1)" 2>/dev/null; then
  : # no error key — proceed
else
  API_ERROR=$(echo "$GEMINI_RESPONSE" | python3 -c "import json,sys; r=json.load(sys.stdin); print(r.get('error',{}).get('message','unknown error'))" 2>/dev/null || echo "unknown error")
  err "Gemini API returned an error: $API_ERROR"
  exit 1
fi

log "Decoding audio data..."

# Extract base64 audio and decode to raw file
python3 -c "
import json, sys, base64, os

response_text = sys.argv[1]
raw_path = sys.argv[2]

try:
    r = json.loads(response_text)
    b64_data = r['candidates'][0]['content']['parts'][0]['inline_data']['data']
except (KeyError, IndexError, TypeError) as e:
    print(f'ERROR: Unexpected response structure: {e}', file=sys.stderr)
    sys.exit(1)

if not b64_data:
    print('ERROR: Empty audio data in response', file=sys.stderr)
    sys.exit(1)

decoded = base64.b64decode(b64_data)
with open(raw_path, 'wb') as f:
    f.write(decoded)

print(f'Decoded {len(decoded)} bytes', file=sys.stderr)
" "$GEMINI_RESPONSE" "$RAW_AUDIO_FILE" || {
  err "Failed to decode audio from Gemini response"
  exit 1
}

if [ ! -f "$RAW_AUDIO_FILE" ] || [ ! -s "$RAW_AUDIO_FILE" ]; then
  err "Decoded audio file is missing or empty"
  exit 1
fi

log "Converting to OGG (libopus) for Telegram compatibility..."

# Ensure output directory exists
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
if [ ! -d "$OUTPUT_DIR" ]; then
  err "Output directory does not exist: $OUTPUT_DIR"
  exit 1
fi

ffmpeg -i "$RAW_AUDIO_FILE" -codec:a libopus -y "$OUTPUT_FILE" 2>/dev/null || {
  err "ffmpeg conversion to OGG failed"
  exit 1
}

# Validate output
if [ ! -f "$OUTPUT_FILE" ]; then
  err "Output file was not created: $OUTPUT_FILE"
  exit 1
fi

if [ ! -s "$OUTPUT_FILE" ]; then
  err "Output file is empty: $OUTPUT_FILE"
  exit 1
fi

log "TTS audio saved to: $OUTPUT_FILE"

# Print output path to stdout (for callers to capture)
echo "$OUTPUT_FILE"
