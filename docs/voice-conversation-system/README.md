# Voice Conversation System

Two-approach voice brainstorming with Claude that auto-feeds into the SDLC pipeline.

## Approaches

### A: Enhanced Telegram Voice Loop
Extends existing `/voice-brainstorm` — Claude responds with voice notes via Gemini TTS.

**Setup:**
1. Ensure `GEMINI_API_KEY` is set in `~/.claude/.env.local`
2. Use `/voice-brainstorm` on Telegram as before
3. Claude now responds with voice notes (TTS) + text
4. Say "ship it" to trigger the SDLC pipeline

**Scripts:**
- `scripts/gemini-tts.sh` — Text-to-speech via Gemini API
- `scripts/voice-session-manager.sh` — Session state management
- `scripts/voice-to-sdlc.sh` — Transcript → brief → auto-dev pipeline

### B: Real-Time Voice Web App
Dedicated web app with sub-second voice conversation latency.

**Setup:**
```bash
cd apps/voice-app
cp .env.example .env.local
# Fill in API keys: ANTHROPIC, DEEPGRAM, CARTESIA, LIVEKIT
pnpm install
pnpm dev
```

**Python Agent:**
```bash
cd apps/voice-app/agent
pip install -r requirements.txt
python voice-agent.py --room brainstorm-001
```

**API Keys Required:**

| Service | Env Var | Purpose | Cost |
|---------|---------|---------|------|
| Gemini | `GEMINI_API_KEY` | STT + TTS (Approach A) | Free |
| Claude | `ANTHROPIC_API_KEY` | LLM conversation | Existing |
| Deepgram | `DEEPGRAM_API_KEY` | Streaming STT (Approach B) | $0.0043/min |
| Cartesia | `CARTESIA_API_KEY` | Streaming TTS (Approach B) | $0.042/1K chars |
| LiveKit | `LIVEKIT_API_KEY` + `SECRET` | Voice rooms (Approach B) | Self-hosted |

## SDLC Pipeline

```
Voice Session → "ship it" / "End & Build"
    → Transcript saved to docs/voice-sessions/
    → Brief generated via /brainstorm template
    → User reviews brief
    → /auto-dev triggers (plan → tasks → build → check → ship → PR)
```

## File Structure

```
scripts/
  gemini-tts.sh              # Gemini TTS generation
  voice-session-manager.sh   # Session CRUD
  voice-to-sdlc.sh          # Transcript → SDLC pipeline
  transcribe-voice.sh       # Existing STT (Gemini/Whisper)

apps/voice-app/
  src/lib/
    deepgram-stt.ts          # Streaming STT client
    cartesia-tts.ts          # Streaming TTS client
    claude-stream.ts         # Claude API streaming
    session-store.ts         # Session management
  src/components/
    VoiceSession.tsx         # Main conversation UI
    TranscriptSidebar.tsx    # Live transcript
    AudioVisualizer.tsx      # Audio waveform
    SessionControls.tsx      # Start/Stop/Ship buttons
  src/app/api/
    session/route.ts         # Session CRUD API
    sdlc/route.ts           # SDLC trigger API
  agent/
    voice-agent.py           # Pipecat voice pipeline

docs/voice-conversation-system/
  brief.md                   # Feature brief + PR/FAQ
  design-doc.md             # Architecture + milestones
  README.md                 # This file
```

## Troubleshooting

**Gemini TTS returns empty audio:**
- Check `GEMINI_API_KEY` is valid
- TTS preview model may have rate limits — wait and retry

**Deepgram WebSocket disconnects:**
- Client auto-reconnects (3 attempts)
- Check `DEEPGRAM_API_KEY` is valid and has credits

**Pipecat agent won't start:**
- Ensure Python 3.11+ and all deps installed
- Check LiveKit server is running at `LIVEKIT_URL`
- Verify all 4 API keys are set

**"ship it" not detected:**
- Speak clearly: "ship it", "build this", "done", "that's enough"
- Detection is in the transcribed text, so STT accuracy matters
