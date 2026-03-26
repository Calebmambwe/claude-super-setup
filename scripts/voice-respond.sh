#!/usr/bin/env bash
set -euo pipefail

# Generate a voice response using Gemini TTS
# Usage: bash scripts/voice-respond.sh "text to speak" [output-file.mp3]
#
# Requires: GEMINI_API_KEY, curl, python3
# Output: MP3/WAV audio file

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

err() { echo -e "${RED}[TTS]${NC} $1" >&2; }
log() { echo -e "${GREEN}[TTS]${NC} $1" >&2; }

TEXT="${1:-}"
OUTPUT_FILE="${2:-/tmp/voice-response.wav}"

if [ -z "$TEXT" ]; then
  err "Usage: voice-respond.sh 'text to speak' [output-file]"
  exit 1
fi

# Truncate very long text (TTS has a limit)
if [ "${#TEXT}" -gt 4000 ]; then
  TEXT="${TEXT:0:4000}..."
  log "Text truncated to 4000 chars"
fi

# Load API key
GEMINI_API_KEY="${GEMINI_API_KEY:-}"
for ENV_FILE in "$HOME/.claude/.env.local" "$HOME/.claude/.env"; do
  if [ -f "$ENV_FILE" ] && [ -z "$GEMINI_API_KEY" ]; then
    GEMINI_API_KEY=$(grep -s '^GEMINI_API_KEY=' "$ENV_FILE" | head -1 | sed 's/^GEMINI_API_KEY=//' | tr -d '[:space:]' || true)
  fi
done

if [ -z "$GEMINI_API_KEY" ]; then
  err "No GEMINI_API_KEY found. Set it in ~/.claude/.env.local"
  exit 1
fi

log "Generating voice response (${#TEXT} chars)..."

# Escape text for JSON
ESCAPED_TEXT=$(printf '%s' "$TEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null)

# Call Gemini TTS
RESPONSE=$(curl -s --max-time 30 -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"contents\": [{\"parts\": [{\"text\": $ESCAPED_TEXT}]}],
    \"generationConfig\": {
      \"response_modalities\": [\"AUDIO\"],
      \"speech_config\": {
        \"voice_config\": {
          \"prebuilt_voice_config\": {\"voice_name\": \"Kore\"}
        }
      }
    }
  }" 2>&1)

# Extract audio data
python3 -c "
import json, sys, base64

try:
    d = json.loads('''$RESPONSE''')
except:
    # Try reading from a temp file if inline fails
    import os
    with open('/tmp/gemini-tts-response.json', 'w') as f:
        f.write('''$RESPONSE''')
    with open('/tmp/gemini-tts-response.json') as f:
        d = json.load(f)

candidates = d.get('candidates', [])
if not candidates:
    error = d.get('error', {}).get('message', 'Unknown error')
    print(f'Error: {error}', file=sys.stderr)
    sys.exit(1)

parts = candidates[0].get('content', {}).get('parts', [])
for part in parts:
    if 'inlineData' in part:
        audio_data = base64.b64decode(part['inlineData']['data'])
        with open('$OUTPUT_FILE', 'wb') as f:
            f.write(audio_data)
        print('$OUTPUT_FILE')
        sys.exit(0)

print('No audio data in response', file=sys.stderr)
sys.exit(1)
" 2>/dev/null

if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
  log "Voice response saved: $OUTPUT_FILE ($(wc -c < "$OUTPUT_FILE" | tr -d ' ') bytes)"
  echo "$OUTPUT_FILE"
else
  err "Failed to generate voice response"
  exit 1
fi
