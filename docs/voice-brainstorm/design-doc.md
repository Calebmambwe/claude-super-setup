# Design Document: Voice Brainstorming via Telegram

**Date:** 2026-03-25
**Status:** Ready for Implementation
**Feature:** `voice-brainstorm`
**Research:** [research.md](research.md)

---

## Problem

When you're away from your desk and have an idea, you want to brainstorm it via voice on Telegram and get back a structured feature brief. Currently:
- `/brainstorm` requires text input (typing on phone is slow)
- `/voice-brief` accepts transcription but is one-shot (no conversation)
- Voice messages arrive on Telegram but aren't auto-processed
- No iterative voice-to-voice brainstorming loop exists

## Solution

Build a **voice brainstorming loop** in Telegram:

```
You speak → Claude transcribes → Claude asks questions → You speak again
  → Claude refines → You speak more → Claude produces a brief
```

After 3-5 voice exchanges, Claude generates a structured `brief.md` and suggests next steps (`/design-doc` or `/auto-plan`).

## Architecture

### Flow Diagram

```
┌──────────────────────────────────────────────────────────┐
│ TELEGRAM (user's phone)                                   │
│                                                           │
│ [User sends voice note] ──────────────────────────────┐  │
│                                                        │  │
│ [User receives text reply + optional voice reply] ◄──┐│  │
└──────────────────────────────────────────────────────┼┼──┘
                                                       ││
                    Telegram Bot API                    ││
                                                       ││
┌──────────────────────────────────────────────────────┼┼──┐
│ CLAUDE CODE (VPS or Mac)                             ││  │
│                                                      ││  │
│ 1. Detect voice message (attachment_file_id)         ││  │
│ 2. download_attachment → local OGG file              ││  │
│ 3. transcribe-voice.sh → text                        ││  │
│ 4. Feed into brainstorm session state                ││  │
│ 5. Generate response (question/refinement/brief)     ││  │
│ 6. Reply via Telegram text                       ────┘│  │
│ 7. Optional: Gemini TTS → voice reply           ─────┘  │
│ 8. Wait for next voice note...                           │
│                                                          │
│ After 3-5 exchanges:                                     │
│ 9. Generate brief.md                                     │
│ 10. Notify user with summary + next steps                │
└──────────────────────────────────────────────────────────┘
```

### Components

#### 1. Voice Brainstorm Command (`commands/voice-brainstorm.md`)

New command that orchestrates the entire voice brainstorming flow. It:
- Detects when called with voice transcription vs text
- Maintains a brainstorm session with question tracking
- Knows which questions have been answered
- Produces a brief when enough info is gathered
- Works in both Telegram (voice) and terminal (text) mode

#### 2. Voice Auto-Detection Hook

Enhancement to the Telegram dispatch system. When a voice message arrives:
- If no active brainstorm session → start one with `/voice-brainstorm`
- If active brainstorm session → feed transcription into it
- If the message says "stop" or "that's enough" → finalize the brief

This is handled by the Telegram listener itself — Claude detects `attachment_file_id` in channel messages and processes accordingly.

#### 3. Transcription Pipeline (existing)

`scripts/transcribe-voice.sh` — already built, tested, works on both Mac and VPS.
- Primary: Gemini 2.0 Flash (free)
- Fallback: OpenAI Whisper ($0.006/min)
- Handles OGG → MP3 conversion via ffmpeg

#### 4. TTS Response Pipeline (new, optional)

`scripts/voice-respond.sh` — generates voice responses via Gemini TTS.
- Input: text response from Claude
- Output: OGG/MP3 audio file
- Send back via Telegram `sendVoice`
- Optional — text responses work fine for MVP

## Detailed Design

### The Brainstorm Session

A brainstorm session tracks the conversation state:

```json
{
  "session_id": "vb-20260325-1234",
  "feature_name": null,
  "started_at": "2026-03-25T16:00:00Z",
  "status": "active",
  "exchanges": 0,
  "questions_answered": {
    "what_to_build": null,
    "who_for": null,
    "core_constraint": null,
    "out_of_scope": null,
    "why_now": null
  },
  "raw_transcriptions": [],
  "chat_id": "8328233140"
}
```

Session file: `~/.claude/voice-brainstorm-session.json`

### The Command Flow

```markdown
/voice-brainstorm [transcribed text or raw text]

Step 1: Check for active session
  - Read ~/.claude/voice-brainstorm-session.json
  - If no session or expired (>1 hour): start new session
  - If active session: continue it

Step 2: Process input
  - If input is from voice transcription: clean up (add punctuation, fix grammar)
  - Extract any answerable information from the input
  - Update questions_answered in session

Step 3: Determine next action
  - If < 2 questions answered: ask the next unanswered question
  - If 2-4 questions answered: ask refinement questions
  - If all 5 answered: propose the brief
  - If user says "done"/"that's enough"/"ship it": generate brief immediately

Step 4: Respond
  - Reply with the next question or the generated brief
  - Keep responses SHORT and conversational (voice-friendly)
  - Use simple language (the user is speaking, not typing)

Step 5: If generating brief
  - Create docs/{feature-name}/brief.md
  - Send summary to Telegram
  - Suggest next steps: /design-doc or /auto-plan
  - Clear the session
```

### Voice Message Detection in Telegram

When a channel message arrives with voice content, Claude should:

```
1. Check if message has attachment_file_id attribute
2. Call download_attachment with the file_id
3. Read the returned file path — it's an OGG audio file
4. Run: bash scripts/transcribe-voice.sh <file_path>
5. Feed the transcription text into /voice-brainstorm
```

This happens naturally in the Claude session — the Telegram plugin instructions already say:
> "If the tag has attachment_file_id, call download_attachment with that file_id to fetch the file"

The enhancement is making Claude AUTO-DO this and feed into brainstorm, rather than waiting for manual instruction.

### Response Format (voice-optimized)

Responses should be:
- **Short** — 1-3 sentences max (voice-friendly)
- **One question at a time** — don't overwhelm
- **Conversational tone** — "Cool! So who's going to use this?" not "Please specify the target user demographic"
- **Acknowledge what was said** — "Got it, a habit tracker with streaks."
- **Progressive** — each response builds on the last

Example exchange:
```
User (voice): "I want to build something that helps people track their habits
               but not just checkboxes more like streaks and social stuff"

Claude: "Nice — a habit tracker with streaks and social accountability.
         Who are you building this for? Young adults? Fitness crowd? Everyone?"

User (voice): "Mainly Gen Z and millennials who are into self improvement
               but get bored of traditional habit apps"

Claude: "Got it — Gen Z/millennials who find traditional habit apps boring.
         What's your main constraint? Timeline, tech stack, team size?"

User (voice): "Just me building it need to ship in like 2 weeks using React Native"

Claude: "Solo dev, 2 weeks, React Native. What's explicitly NOT in v1?
         Like, no social features yet? No monetization?"

User (voice): "No monetization for now and maybe skip the social feed
               just do the streaks and basic sharing"

Claude: "Perfect. Here's what I've captured:

         Feature: habit-streaks
         Problem: Habit apps are boring for Gen Z/millennials
         Solution: Streak-based habit tracker with basic sharing
         Users: Gen Z/millennials into self-improvement
         Constraint: Solo dev, 2 weeks, React Native
         Out of scope: Monetization, social feed

         Generating brief... saved to docs/habit-streaks/brief.md

         Next: /design-doc habit-streaks or /auto-plan habit-streaks"
```

### TTS Response (Phase 2)

For voice-to-voice brainstorming, generate audio responses:

```bash
# scripts/voice-respond.sh
# Input: text response
# Output: OGG audio file path

GEMINI_API_KEY="..."
TEXT="$1"
OUTPUT_FILE="${2:-/tmp/voice-response.mp3}"

curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"contents\": [{\"parts\": [{\"text\": \"$TEXT\"}]}],
    \"generationConfig\": {
      \"response_modalities\": [\"AUDIO\"],
      \"speech_config\": {
        \"voice_config\": {
          \"prebuilt_voice_config\": {\"voice_name\": \"Kore\"}
        }
      }
    }
  }" | python3 -c "
import json, sys, base64
d = json.load(sys.stdin)
audio = d['candidates'][0]['content']['parts'][0]['inlineData']['data']
with open('$OUTPUT_FILE', 'wb') as f:
    f.write(base64.b64decode(audio))
print('$OUTPUT_FILE')
"
```

Then send via Telegram: `reply(chat_id, text, files=[output_file])`

## File Inventory

### New Files
| File | Purpose |
|------|---------|
| `commands/voice-brainstorm.md` | The voice brainstorming command |
| `scripts/voice-respond.sh` | Gemini TTS response generator (Phase 2) |

### Modified Files
| File | Change |
|------|--------|
| `commands/telegram-dispatch.md` | Add voice message auto-detection routing |

### Existing Files (reused)
| File | Role |
|------|------|
| `scripts/transcribe-voice.sh` | Transcription (Gemini/Whisper) |
| `commands/brainstorm.md` | Question structure reference |
| `commands/voice-brief.md` | Brief generation reference |

## Implementation Plan

### Phase 1: MVP (text response to voice input)
1. Create `commands/voice-brainstorm.md` with session tracking
2. Wire voice message detection into Telegram listener behavior
3. Test: send voice note → get text brainstorm response → iterate → get brief

### Phase 2: Voice Response (speak back)
4. Create `scripts/voice-respond.sh` with Gemini TTS
5. Integrate TTS into voice-brainstorm command
6. Test: send voice note → get VOICE brainstorm response

### Phase 3: Polish
7. Add session timeout (auto-finalize after 1 hour of inactivity)
8. Add "save progress" — don't lose brainstorm if session crashes
9. Add `/voice-brainstorm continue` to resume interrupted sessions
10. Auto-trigger `/design-doc` when brief is generated (optional)

## Acceptance Criteria

1. Send a voice note to Telegram → Claude auto-transcribes and starts brainstorming
2. Iterative conversation: 3-5 voice exchanges produce a structured brief
3. Brief saved to `docs/{feature-name}/brief.md`
4. Works on both Mac (@ghost_run_bot) and VPS (@ghost_run_remote_bot)
5. Gemini transcription (free) as primary, Whisper as fallback
6. Session state persists across messages
7. Conversational, voice-friendly responses (short, one question at a time)

## Verification

1. Send 5 voice notes with a feature idea → verify brief.md is generated
2. Send "stop" mid-brainstorm → verify partial brief is saved
3. Test with noisy audio → verify transcription handles it
4. Test session timeout → verify it auto-finalizes
5. Test on VPS via @ghost_run_remote_bot
