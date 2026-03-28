---
name: voice-chat
description: Unified voice conversation entry point — routes to Telegram voice brainstorm or opens web app based on context. Start a voice brainstorming session that transcribes and feeds into SDLC pipeline.
triggers:
  - /voice-chat
  - voice chat
  - voice conversation
  - talk to claude
  - speak to claude
---

# Voice Chat — Unified Entry Point

Start a voice brainstorming session with Claude. Detects your context and routes to the right approach.

## Behavior

### If invoked from Telegram (channel message detected)

Route to `/voice-brainstorm` — the enhanced Telegram voice loop with TTS responses.

Tell the user:
> "Starting voice brainstorm session. Send me a voice note with your idea and I'll respond with voice + text. Say 'ship it' when you're ready to build."

Then follow the `/voice-brainstorm` skill flow.

### If invoked from terminal (no Telegram context)

Provide web app instructions:

```
Voice Brainstorm Web App

Start the app:
  cd apps/voice-app && pnpm dev

Start the voice agent:
  cd apps/voice-app/agent && python voice-agent.py --room brainstorm-$(date +%s)

Then open: http://localhost:3000/session/new

Alternative: Use Telegram voice notes instead — send a voice note to your bot.
```

### Session end → SDLC pipeline

When the voice session ends (user says "ship it", "build this", "done"):

1. Save transcript to `docs/voice-sessions/YYYY-MM-DD-{topic}.md`
2. Generate structured brief from transcript
3. Show brief to user for review
4. On confirmation, trigger `/auto-dev {feature-name}`

### Scripts Reference

- `scripts/gemini-tts.sh "text" output.ogg` — Generate TTS audio
- `scripts/voice-session-manager.sh start|end|list|cleanup` — Manage sessions
- `scripts/voice-to-sdlc.sh <session-id> [--auto]` — Transcript → SDLC pipeline
