# Design Document: Voice Conversation System

**Date:** 2026-03-26
**Status:** Ready for Implementation
**Feature:** `voice-conversation-system`
**Brief:** [brief.md](brief.md)
**Prior Art:** [voice-brainstorm research](../voice-brainstorm/research.md), [voice-brainstorm design-doc](../voice-brainstorm/design-doc.md)

---

## Problem

Brainstorming by typing is slow and unnatural. The existing `/voice-brainstorm` works but is text-response only. We need:
1. **True voice conversation** — Claude speaks back (TTS) on Telegram
2. **Real-time voice app** — sub-second latency desktop conversations via web app
3. **SDLC auto-trigger** — voice session → transcript → brief → `/auto-dev` → PR

## Solution Overview

Two complementary approaches shipping in 4 phases:

```
Approach A: Enhanced Telegram Voice Loop (Phase 1-2)
  - Extends existing /voice-brainstorm skill
  - Adds Gemini TTS voice responses (free)
  - Adds session state persistence
  - Adds SDLC pipeline trigger ("ship it" command)

Approach B: Real-Time Voice Web App (Phase 3-4)
  - New Next.js web app with LiveKit/Pipecat backend
  - Deepgram Nova-2 STT (streaming WebSocket)
  - Cartesia Sonic TTS (lowest latency)
  - Claude API streaming for LLM
  - Live transcript sidebar + "End & Build" button
```

## Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    VOICE CONVERSATION SYSTEM                     │
├─────────────────────────────┬───────────────────────────────────┤
│   APPROACH A: TELEGRAM      │   APPROACH B: WEB APP              │
│                             │                                    │
│  ┌─────────┐  voice note   │  ┌─────────┐  audio stream        │
│  │ Phone   │──────────────┐│  │ Browser │──────────────┐       │
│  │ (TG)    │◄─voice note──┐││  │ (React) │◄─audio stream─┐│      │
│  └─────────┘              │││  └─────────┘              ││       │
│                           │││                           ││       │
│  ┌────────────────────┐   │││  ┌────────────────────┐   ││       │
│  │ Telegram Bot API   │◄──┘││  │ LiveKit Server     │◄──┘│       │
│  │ (download_attach)  │    ││  │ (WebSocket rooms)  │    │       │
│  └────────┬───────────┘    ││  └────────┬───────────┘    │       │
│           │ OGG file       ││           │ audio frames   │       │
│           ▼                ││           ▼                │       │
│  ┌────────────────────┐   ││  ┌────────────────────┐    │       │
│  │ transcribe-voice.sh│   ││  │ Deepgram Nova-2    │    │       │
│  │ (Gemini 2.0 Flash) │   ││  │ (streaming STT)    │    │       │
│  └────────┬───────────┘   ││  └────────┬───────────┘    │       │
│           │ text           ││           │ text chunks    │       │
│           ▼                ││           ▼                │       │
│  ┌─────────────────────────┴┴───────────────────────────┐│       │
│  │              SHARED CONVERSATION ENGINE               ││       │
│  │                                                       ││       │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ ││       │
│  │  │ Session Mgr  │  │ Claude API   │  │ Transcript │ ││       │
│  │  │ (state.json) │  │ (streaming)  │  │ Logger     │ ││       │
│  │  └──────────────┘  └──────┬───────┘  └────────────┘ ││       │
│  │                           │ response text            ││       │
│  └───────────────────────────┼──────────────────────────┘│       │
│           │                  │                  │        │       │
│           ▼                  │                  ▼        │       │
│  ┌────────────────────┐      │      ┌────────────────┐   │       │
│  │ Gemini TTS         │      │      │ Cartesia Sonic │   │       │
│  │ (generate voice)   │      │      │ (stream TTS)   │───┘       │
│  └────────┬───────────┘      │      └────────────────┘           │
│           │ OGG audio        │                                   │
│           ▼                  │                                   │
│  ┌────────────────────┐      │                                   │
│  │ Telegram sendVoice │      │                                   │
│  └────────────────────┘      │                                   │
│                              │                                   │
├──────────────────────────────┴───────────────────────────────────┤
│                     SDLC INTEGRATION PIPELINE                    │
│                                                                  │
│  Session End ("ship it" / "End & Build" button)                  │
│       │                                                          │
│       ▼                                                          │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐         │
│  │ Transcript   │──▶│ Claude       │──▶│ Feature      │         │
│  │ Cleanup      │   │ /brainstorm  │   │ Brief        │         │
│  │ (filler rm)  │   │ (structured) │   │ (brief.md)   │         │
│  └──────────────┘   └──────────────┘   └──────┬───────┘         │
│                                                │                 │
│                                    User confirms? ──── No ──▶ Save draft │
│                                                │                 │
│                                               Yes                │
│                                                │                 │
│                                                ▼                 │
│                                       ┌──────────────┐           │
│                                       │ /auto-dev    │           │
│                                       │ (plan→build  │           │
│                                       │  →check→ship)│           │
│                                       └──────────────┘           │
└──────────────────────────────────────────────────────────────────┘
```

## Data Structures

### Voice Session State (`/tmp/voice-sessions/{session-id}.json`)

```json
{
  "id": "vs-20260326-143022",
  "approach": "telegram|web",
  "status": "active|paused|completed|shipped",
  "started_at": "2026-03-26T14:30:22Z",
  "ended_at": null,
  "topic": "auto-detected or user-provided",
  "chat_id": "123456789",
  "exchanges": [
    {
      "turn": 1,
      "role": "user",
      "text": "I want to build a feature that...",
      "audio_path": "/tmp/voice-dl-abc123.ogg",
      "timestamp": "2026-03-26T14:30:22Z"
    },
    {
      "turn": 2,
      "role": "assistant",
      "text": "Interesting! Who is the primary user for this?",
      "audio_path": "/tmp/tts-response-1.ogg",
      "timestamp": "2026-03-26T14:30:28Z"
    }
  ],
  "questions_answered": ["what", "who"],
  "questions_remaining": ["constraints", "scope", "why_now"],
  "transcript_path": null,
  "brief_path": null
}
```

### Transcript Format (`docs/voice-sessions/YYYY-MM-DD-{topic}.md`)

```markdown
# Voice Session: {topic}

**Date:** {date}
**Duration:** {minutes} minutes
**Exchanges:** {count}
**Approach:** Telegram / Web App

## Transcript

**[00:00] Caleb:** I want to build a feature that lets users...

**[00:15] Claude:** That's interesting. Who is the primary user?

**[00:32] Caleb:** Solo developers who want to...

**[01:05] Claude:** What constraints should we keep in mind?

...

## Key Decisions
- {extracted decision 1}
- {extracted decision 2}

## Action Items
- {extracted action 1}
- {extracted action 2}

## Generated Brief
→ [brief.md](../../{feature-name}/brief.md)
```

## Component Details

### Component 1: Enhanced Voice Brainstorm Skill (Approach A)

**File:** `~/.claude/skills/voice-brainstorm/SKILL.md` (update existing)

Changes to existing skill:
1. **TTS Response Generation** — After generating text response, call Gemini TTS to create audio, send via `sendVoice`
2. **Session State** — Persist conversation state to JSON file between voice notes
3. **"Ship It" Trigger** — When user says "ship it", "build this", or "that's enough":
   - Save transcript to `docs/voice-sessions/`
   - Generate structured brief via `/brainstorm` logic
   - Show brief to user for confirmation
   - On "yes" → trigger `/auto-dev`

**New script:** `scripts/gemini-tts.sh`
```bash
#!/usr/bin/env bash
# Generate TTS audio from text using Gemini 2.5 Flash
# Usage: gemini-tts.sh "Text to speak" output.ogg
# Returns: path to generated OGG audio file
```

### Component 2: Gemini TTS Script

**File:** `scripts/gemini-tts.sh`

```
Input: text string, output file path
Process:
  1. Call Gemini API with speech config
  2. Decode base64 audio response
  3. Convert to OGG (Telegram-compatible) via ffmpeg
  4. Return output path
Output: OGG audio file
```

API call structure:
- Model: `gemini-2.5-flash-preview-tts`
- Config: `response_modalities: ["AUDIO"]`, `speech_config.voice_config.prebuilt_voice_config.voice_name: "Kore"` (or similar)
- Response: base64-encoded audio in `inline_data`

### Component 3: Session Manager

**File:** `scripts/voice-session-manager.sh`

```
Commands:
  start <chat_id> [topic]     → Create new session JSON
  add-exchange <session_id> <role> <text> [audio_path]  → Append exchange
  get-state <session_id>      → Return current session state
  end <session_id>            → Finalize, generate transcript
  list                        → Show active sessions
  cleanup                     → Remove sessions older than 24h
```

### Component 4: SDLC Pipeline Trigger

**File:** `scripts/voice-to-sdlc.sh`

```
Input: session_id or transcript path
Process:
  1. Load transcript from session
  2. Clean transcript (remove filler words, structure into topics)
  3. Extract: topic, key decisions, constraints, scope
  4. Generate feature brief using /brainstorm template
  5. Save brief to docs/{feature-name}/brief.md
  6. Prompt user for confirmation
  7. On confirm: execute /auto-dev {feature-name}
Output: Feature brief + optional auto-dev trigger
```

### Component 5: Real-Time Voice Web App (Approach B)

**Stack:** Next.js 15 + LiveKit + Deepgram + Cartesia + Claude API

**Directory:** `apps/voice-app/` (new project)

```
apps/voice-app/
├── package.json
├── next.config.ts
├── .env.example
├── src/
│   ├── app/
│   │   ├── layout.tsx
│   │   ├── page.tsx              # Landing / session list
│   │   └── session/
│   │       └── [id]/
│   │           └── page.tsx      # Active voice session
│   ├── components/
│   │   ├── VoiceSession.tsx      # Main voice conversation UI
│   │   ├── TranscriptSidebar.tsx # Live transcript display
│   │   ├── AudioVisualizer.tsx   # Waveform visualization
│   │   ├── SessionControls.tsx   # Start/Stop/Ship buttons
│   │   └── SessionHistory.tsx    # Past session browser
│   ├── lib/
│   │   ├── livekit-agent.ts      # LiveKit agent configuration
│   │   ├── deepgram-stt.ts       # Deepgram streaming STT
│   │   ├── cartesia-tts.ts       # Cartesia streaming TTS
│   │   ├── claude-stream.ts      # Claude API streaming
│   │   ├── session-store.ts      # Session state management
│   │   └── sdlc-trigger.ts       # SDLC pipeline trigger
│   └── server/
│       ├── voice-pipeline.ts     # Server-side voice pipeline
│       └── api/
│           ├── session/route.ts  # Session CRUD
│           └── sdlc/route.ts     # SDLC trigger endpoint
├── agent/
│   └── voice-agent.py            # Pipecat/LiveKit agent (Python)
└── tests/
    ├── voice-pipeline.test.ts
    ├── session-store.test.ts
    └── sdlc-trigger.test.ts
```

**Voice Pipeline (server-side):**

```
Browser mic → WebSocket → LiveKit Room
                              │
                    ┌─────────┴─────────┐
                    │  Voice Agent (Py)  │
                    │                    │
                    │  Silero VAD        │ ← detects speech end
                    │       │            │
                    │  Deepgram STT      │ ← streaming transcription
                    │       │            │
                    │  Claude API        │ ← streaming LLM response
                    │       │            │
                    │  Cartesia TTS      │ ← streaming audio synthesis
                    │       │            │
                    └───────┼────────────┘
                            │
                    Audio back to browser
```

**Frontend UI:**

```
┌──────────────────────────────────────────────────┐
│  Voice Brainstorm                    [End & Build]│
├──────────────────────┬───────────────────────────┤
│                      │                           │
│                      │  TRANSCRIPT                │
│                      │                           │
│    ┌──────────┐      │  [00:00] You:             │
│    │  ◉ ◉ ◉   │      │  I want to build...       │
│    │ Listening │      │                           │
│    │          │      │  [00:15] Claude:           │
│    └──────────┘      │  Who is the primary user?  │
│                      │                           │
│   [🎤 Speaking...]   │  [00:32] You:             │
│                      │  Solo developers who...    │
│   Audio Visualizer   │                           │
│   ▁▂▃▅▇▅▃▂▁        │  [01:05] Claude:           │
│                      │  What constraints?         │
│                      │                           │
│   Session: 3:42      │  ─────────────────────    │
│   Exchanges: 6       │  Key Decisions:           │
│                      │  • Use Gemini for STT     │
│  [⏸ Pause] [⏹ Stop] │  • Mobile-first approach  │
│                      │                           │
├──────────────────────┴───────────────────────────┤
│  Past Sessions: voice-auth (Mar 25) | voice-ui   │
└──────────────────────────────────────────────────┘
```

## Milestones

### Milestone 1: Gemini TTS + Enhanced Telegram Loop (Days 1-2)

**Goal:** Claude responds with voice notes on Telegram during brainstorming

**Deliverables:**
1. `scripts/gemini-tts.sh` — Gemini TTS audio generation
2. `scripts/voice-session-manager.sh` — Session state management
3. Updated `/voice-brainstorm` skill with TTS output + session state
4. Tests for TTS script and session manager

**Acceptance Criteria:**
- [ ] Send voice note on Telegram → receive voice note response from Claude
- [ ] Session state persists across voice exchanges
- [ ] Conversation flows naturally with 3-5 brainstorming questions
- [ ] Session can be paused and resumed

### Milestone 2: SDLC Integration Pipeline (Days 3-4)

**Goal:** "Ship it" triggers the full SDLC pipeline from voice transcript

**Deliverables:**
1. `scripts/voice-to-sdlc.sh` — Transcript → brief → auto-dev pipeline
2. Transcript cleanup and structuring logic
3. "Ship it" / "build this" trigger detection in voice-brainstorm
4. Transcript storage in `docs/voice-sessions/`
5. Updated FEATURES.md registry integration

**Acceptance Criteria:**
- [ ] Say "ship it" → transcript saved → brief generated → shown for approval
- [ ] Brief follows standard brainstorm-brief template
- [ ] On approval, `/auto-dev` fires with the feature brief as input
- [ ] Transcript includes timestamps, key decisions, action items

### Milestone 3: LiveKit/Pipecat Voice Web App (Days 5-8)

**Goal:** Real-time voice conversation in the browser with <1.5s round-trip

**Deliverables:**
1. `apps/voice-app/` — Next.js web application
2. `apps/voice-app/agent/voice-agent.py` — Pipecat voice pipeline agent
3. Deepgram STT integration (streaming WebSocket)
4. Cartesia TTS integration (streaming)
5. Claude API streaming integration
6. Live transcript sidebar component
7. Audio visualizer component
8. Session management UI

**Acceptance Criteria:**
- [ ] Voice-to-voice round-trip < 1.5 seconds
- [ ] Live transcript updates in real-time as conversation progresses
- [ ] Audio visualizer shows active speaking states
- [ ] "End & Build" button triggers SDLC pipeline
- [ ] Responsive design works on mobile (375px+)

### Milestone 4: Polish + Session History (Days 9-10)

**Goal:** Production-ready with session management and history

**Deliverables:**
1. Session history browser (list past sessions, replay transcripts)
2. Re-trigger SDLC from any past session
3. Unified session storage (both Telegram and web sessions in same format)
4. Error handling, retry logic, graceful degradation
5. Documentation (README, API docs)

**Acceptance Criteria:**
- [ ] Can browse and search past voice sessions
- [ ] Can re-trigger SDLC from any completed session
- [ ] Both approaches share the same session format
- [ ] Handles network errors, API failures gracefully
- [ ] Documentation covers setup, usage, and troubleshooting

## API Keys Required

| Service | Env Var | Purpose | Cost |
|---------|---------|---------|------|
| Gemini | `GEMINI_API_KEY` | STT + TTS (Approach A) | Free tier |
| Claude | `ANTHROPIC_API_KEY` | LLM conversation | Existing |
| Deepgram | `DEEPGRAM_API_KEY` | Streaming STT (Approach B) | $0.0043/min |
| Cartesia | `CARTESIA_API_KEY` | Streaming TTS (Approach B) | $0.042/1K chars |
| LiveKit | `LIVEKIT_API_KEY` + `LIVEKIT_API_SECRET` | Voice rooms (Approach B) | Self-hosted or cloud |

## Security Considerations

- Audio files deleted after transcription (never persisted)
- Transcripts stored locally only (not uploaded to cloud)
- API keys stored in `.env` (never committed)
- Telegram allowlist controls who can use voice brainstorming
- Web app requires local access only (no public deployment in v1)
- SDLC trigger requires explicit user confirmation before `/auto-dev`

## Dependencies

- `ffmpeg` — audio format conversion (already installed)
- `jq` — JSON processing for session state (already installed)
- `curl` — API calls (already installed)
- `node` 20+ — web app runtime
- `python` 3.11+ — Pipecat voice agent
- `pnpm` — package management

---

*Generated by BMAD Method v6 — System Architect*
