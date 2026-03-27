# Feature Brief: Voice Conversation System

**Date:** 2026-03-26
**Status:** Brief
**Author:** Caleb Mambwe
**Feature Name:** `voice-conversation-system`
**Extends:** `voice-brainstorm` (existing Telegram voice loop)

---

## Problem

Brainstorming ideas by typing is slow and unnatural. The existing `/voice-brainstorm` skill accepts voice notes on Telegram but is limited to a one-directional flow (you speak, Claude responds with text). There's no true back-and-forth voice conversation where Claude speaks back to you, and no dedicated real-time voice interface for when you're at your desk.

The gap: **Ideas live in your head as spoken thoughts, but the SDLC pipeline only accepts structured text.** The bridge between "shower thought" and "shipped PR" requires too much manual typing.

## Solution

Build a **two-approach voice conversation system** that lets you brainstorm with Claude via real-time voice, then automatically feeds the transcript into the SDLC pipeline.

### Approach A: Enhanced Telegram Voice Loop (v1 — 1-2 days)

Extend the existing `/voice-brainstorm` skill to support:
- **Claude voice responses** — TTS voice notes sent back via Telegram (not just text)
- **Multi-turn conversation state** — maintains context across 5-15 voice exchanges
- **Session management** — start/stop/resume voice sessions
- **Transcript export** — full conversation saved to `docs/voice-sessions/`
- **SDLC trigger** — "ship it" command feeds transcript into `/brainstorm` brief → `/auto-dev`

### Approach B: Dedicated Voice Web App (v2 — 4-6 days)

Real-time voice conversation app with sub-500ms latency:
- **LiveKit Agents / Pipecat** backend for real-time audio streaming
- **Deepgram Nova-2** for STT (~300ms streaming)
- **Cartesia Sonic / ElevenLabs** for TTS (~100-200ms)
- **Claude API streaming** for LLM responses
- **Live transcript sidebar** showing conversation as it happens
- **"End & Build" button** that triggers the SDLC pipeline
- **Session history** — browse, replay, re-trigger past sessions

### SDLC Integration Pipeline

```
Voice Session Ends (user says "ship it" or clicks "End & Build")
       |
       v
Transcript saved: docs/voice-sessions/YYYY-MM-DD-{topic}.md
       |
       v
Transcript cleanup (Claude removes filler, structures into topics)
       |
       v
/brainstorm brief generation (structured feature brief)
       |
       v
Brief shown to user for confirmation
       |
       v
User approves --> /auto-dev (plan --> tasks --> build --> check --> ship)
       |
       v
PR Ready for Review
```

## Target User

Caleb (solo developer) — brainstorming features while walking, driving, or away from desk (Telegram) and while at desk wanting faster ideation flow (web app).

## Core Constraints

- **Latency budget:** Telegram approach ~5-10s round-trip (acceptable for voice notes), Web app <1.5s round-trip (natural conversation)
- **Cost:** Must stay under $5/day for STT+TTS at moderate usage (10-20 sessions/day)
- **Integration:** Must work with existing Telegram bot infrastructure and Claude Code SDLC pipeline
- **Privacy:** Audio never stored permanently — only transcripts kept. Audio deleted after transcription.

## Tech Stack

| Component | Telegram (A) | Web App (B) |
|-----------|-------------|-------------|
| STT | Whisper (existing) or Deepgram | Deepgram Nova-2 (WebSocket streaming) |
| TTS | ElevenLabs API or Deepgram Aura | Cartesia Sonic (lowest latency) |
| LLM | Claude API (existing Telegram flow) | Claude API streaming |
| Voice Pipeline | Telegram Bot API + shell scripts | LiveKit Agents or Pipecat |
| Frontend | Telegram (no UI needed) | Next.js / React web app |
| Transport | Telegram Bot API | WebSocket (LiveKit) |
| Session State | File-based (JSON in /tmp) | Redis or in-memory |

## Out of Scope (v1)

- Multi-user voice rooms (just you + Claude)
- Phone call integration (Twilio/PSTN)
- Voice cloning / custom Claude voice personality
- Video or screen sharing during brainstorm
- Mobile native app (web app is mobile-responsive instead)
- Offline mode / local-only processing
- Voice authentication / speaker verification

## Success Metrics

- Voice-to-brief time < 5 minutes (vs ~15 min typing)
- SDLC pipeline auto-triggered from 80%+ of voice sessions
- Round-trip latency: Telegram <10s, Web app <1.5s
- Session completion rate > 70% (sessions that produce a usable brief)

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| STT accuracy on technical terms | Medium | High | Custom vocabulary/prompt engineering for Deepgram |
| TTS latency spikes | Low | Medium | Fallback to text-only response |
| Cost overrun on API calls | Low | Medium | Usage caps, session time limits |
| LiveKit complexity for solo dev | Medium | Medium | Start with Pipecat (simpler), migrate if needed |
| Claude API rate limits during streaming | Low | High | Queue management, graceful degradation |

## Implementation Order

1. **Phase 1 (Days 1-2):** Approach A — Enhanced Telegram voice loop with TTS responses
2. **Phase 2 (Days 3-4):** SDLC integration pipeline (transcript → brief → auto-dev)
3. **Phase 3 (Days 5-8):** Approach B — LiveKit/Pipecat web app with real-time voice
4. **Phase 4 (Days 9-10):** Polish, session history, replay, unified session management

---

## PR/FAQ: Voice Conversation System

### Press Release

**LUSAKA, March 2026** — Twendai Software today announced Voice Conversation System, a new voice-first brainstorming tool that enables solo developers to speak their ideas aloud and have them automatically transformed into shipped code. Starting immediately, developers can brainstorm with their AI agent via natural voice conversation on Telegram or a dedicated web app.

Every developer has had the experience: you're walking, driving, or in the shower when the perfect feature idea hits you. By the time you sit down at your desk and type it out, half the nuance is gone. The current workflow — open terminal, type out requirements, structure a brief, plan tasks, write code — takes 30+ minutes from idea to first line of code. Most ideas die in the gap between thought and keyboard.

"I used to lose three out of four ideas because I couldn't type fast enough on my phone," said a solo developer testing the system. "Now I just talk to Claude while walking my dog. By the time I get home, there's a PR waiting for my review."

Voice Conversation System works in two modes: a Telegram voice loop for on-the-go brainstorming (Claude responds with voice notes), and a dedicated web app for desk sessions with sub-second response times. Both modes save a full transcript and, when the developer says "ship it," automatically feed the conversation into the development pipeline — generating a structured brief, decomposing it into tasks, implementing the code, running quality checks, and creating a pull request. The entire journey from spoken idea to reviewable PR happens without touching a keyboard.

Unlike voice transcription tools that just convert speech to text, Voice Conversation System is a true two-way conversation. Claude asks clarifying questions, pushes back on vague requirements, and helps refine the idea before any code is written. The brainstorming conversation IS the requirements gathering — there's no separate documentation step.

To get started, send a voice note to your Telegram bot with the command "brainstorm" or visit the web app and click "Start Session."

### Frequently Asked Questions

**Customer FAQs:**

**Q: Who is this for?**
A: Solo developers and small teams who want to brainstorm features faster. Particularly useful for mobile-first developers who are often away from their desk when ideas strike.

**Q: How is this different from just using voice-to-text and typing into ChatGPT?**
A: Three key differences: (1) Claude talks back with voice, making it a real conversation, not dictation. (2) The transcript automatically feeds into a full development pipeline — brief, tasks, code, tests, PR. (3) Session state is maintained so Claude remembers context across exchanges and asks targeted follow-up questions.

**Q: What does it cost?**
A: STT costs ~$0.004/minute (Deepgram), TTS ~$0.01-0.30/1K characters depending on provider. A typical 5-minute session costs $0.05-0.50. Free with existing Claude API subscription for the LLM portion.

**Q: What if the transcription gets my technical terms wrong?**
A: Deepgram supports custom vocabulary and the system includes a transcript cleanup step where Claude corrects technical terms before generating the brief. You can also review and edit the transcript before triggering the SDLC pipeline.

**Q: When will it be available?**
A: Approach A (Telegram voice loop) ships within 2 days. Approach B (web app) ships within 8 days.

**Internal/Technical FAQs:**

**Q: How long will this take to build?**
A: 4 phases over ~10 days. Phase 1 (Telegram, 2 days) and Phase 2 (SDLC integration, 2 days) deliver core value. Phase 3-4 (web app + polish) add the premium experience.

**Q: What are the biggest risks?**
A: (1) LiveKit/Pipecat complexity for the real-time web app — mitigated by shipping Telegram first to validate the workflow. (2) STT accuracy on technical jargon — mitigated by custom vocabulary and Claude-powered cleanup. (3) TTS latency making conversations feel sluggish — mitigated by streaming TTS and text fallback.

**Q: What are we NOT building?**
A: No multi-user rooms, no phone/PSTN integration, no voice cloning, no video, no native mobile app (web app is responsive), no offline mode.

**Q: How will we measure success?**
A: (1) Voice-to-brief time < 5 minutes (vs 15 min typing). (2) 80%+ of voice sessions trigger the SDLC pipeline. (3) Web app round-trip latency < 1.5 seconds. (4) Session completion rate > 70%.

**Q: What's the rollback plan?**
A: Both approaches are additive — they don't modify existing functionality. The existing `/voice-brainstorm` and `/brainstorm` skills remain unchanged. If Approach A fails, voice notes still work as before. If Approach B fails, Telegram remains the voice interface. Feature flags control each approach independently.
