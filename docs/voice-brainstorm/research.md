# Research Report: Voice Brainstorming via Telegram

**Date:** 2026-03-25
**Research Type:** Technical + User Experience
**Duration:** 30 minutes

## Executive Summary

We already have 80% of the infrastructure — Gemini transcription (`transcribe-voice.sh`), the `/voice-brief` and `/brainstorm` commands, and Telegram voice message handling via the plugin. The missing piece is the **iterative loop**: receive voice → transcribe → respond with brainstorming questions → receive more voice → refine → until a concrete brief emerges.

Key findings:
- Gemini 2.0 Flash is the best choice for transcription (free, supports OGG natively, fast)
- Gemini TTS can generate voice RESPONSES (speak back to user) — enabling true voice conversation
- The Telegram plugin already handles `attachment_file_id` for voice messages via `download_attachment`
- `/brainstorm` already has the 5-question conversation structure — just needs voice input/output wiring

## Research Questions

### Q1: What transcription infrastructure exists?
**Answer:** `scripts/transcribe-voice.sh` is a complete transcription pipeline.
- Supports Gemini (free) and OpenAI Whisper ($0.006/min) as providers
- Auto-selects Gemini first, falls back to Whisper
- Handles OGG → MP3 conversion via ffmpeg
- Both API keys are available on Mac and VPS
- Base64 encoding for Gemini, multipart form for Whisper

**Confidence:** High

### Q2: How does Telegram handle voice messages?
**Answer:** Telegram voice messages arrive as OGG Opus files.
- The Telegram plugin tags messages with `attachment_file_id` attribute
- `download_attachment` MCP tool fetches the file to a local path
- Files can be downloaded via `https://api.telegram.org/file/bot<token>/<file_path>`
- Download URLs expire after 60 minutes
- Max voice message: 50 MB
- The plugin already shows instructions: "If the tag has attachment_file_id, call download_attachment"

**Confidence:** High

### Q3: What brainstorming structure exists?
**Answer:** Two commands cover brainstorming:
- `/brainstorm` — 5-question iterative conversation: What? Who? Constraints? Out of scope? Why now? → produces feature brief
- `/voice-brief` — Takes raw transcription text → structures into brief (one-shot, not iterative)

**Gap:** Neither command has a voice input/output loop. `/brainstorm` is interactive but text-only. `/voice-brief` accepts voice transcription but isn't iterative.

**Confidence:** High

### Q4: What are the best transcription APIs?
**Answer:** Gemini 2.0 Flash is optimal for our use case.

| API | Cost | Accuracy | Speed | OGG Support | Key Available |
|-----|------|----------|-------|-------------|---------------|
| Gemini 2.0 Flash | Free tier / ~$0.001/min | High (tied with Whisper) | Very fast | Yes (native) | Yes |
| OpenAI Whisper | $0.006/min | High (gold standard) | Fast | Yes (via conversion) | Yes |
| GPT-4o Transcribe | $0.003/min | Higher | Fast | Yes | Yes |
| Gemini 2.5 Pro | ~$0.003/min | Highest | Slower | Yes | Yes |

**Recommendation:** Use Gemini 2.0 Flash as primary (free), Whisper as fallback.

**Confidence:** High

### Q5: Can we generate voice responses?
**Answer:** Yes — Gemini TTS can generate spoken responses.
- Text-to-speech via `generateContent` with speech config
- Controllable style, accent, pace, tone via natural language prompts
- Available through Gemini 2.5 Flash and Pro
- Max output: ~655 seconds of audio
- Can send voice responses back to user via Telegram `sendVoice`

**This enables true voice-to-voice brainstorming — user speaks, Claude responds with voice.**

**Confidence:** Medium (TTS is in Preview, may have latency)

### Q6: What's the implementation architecture?
**Answer:** The voice brainstorming loop should work as follows:

```
User sends voice note on Telegram
  → Telegram plugin receives message with attachment_file_id
  → Claude detects voice message, calls download_attachment
  → Read the downloaded OGG file
  → Call transcribe-voice.sh (Gemini) to get text
  → Feed transcription into /brainstorm conversation state
  → Generate brainstorming response (text)
  → Optionally: generate TTS audio via Gemini and send as voice reply
  → Send text response via Telegram reply tool
  → Wait for next voice note...
  → After 3-5 exchanges, produce structured brief
```

**Confidence:** High

### Q7: What's the conversation state management approach?
**Answer:** Claude Code's channel messages are pushed into the active session. The conversation context IS the state — no external DB needed. The `/brainstorm` command already manages a multi-turn conversation. The voice loop just wraps it with transcription on input and optional TTS on output.

**Confidence:** High

## Key Insights

### Insight 1: We're 80% there — just need the glue
**Finding:** All components exist (transcription, brainstorm command, Telegram plugin). Missing: automatic detection of voice messages + transcription + feeding into brainstorm flow.
**Recommendation:** Build a hook/command that auto-detects voice messages and enters brainstorm mode.
**Priority:** High

### Insight 2: Gemini gives us voice IN and voice OUT for free
**Finding:** Gemini 2.0 Flash handles transcription (STT) and TTS generation. Both are free tier or near-free. This enables true voice conversation, not just voice-to-text.
**Recommendation:** Implement bidirectional voice — user speaks, Claude speaks back via Gemini TTS + Telegram sendVoice.
**Priority:** Medium (text responses work fine; voice responses are a nice-to-have)

### Insight 3: The brainstorm flow needs a "session" concept
**Finding:** Current `/brainstorm` is a single-session text conversation. For voice, we need to maintain state across multiple voice messages, track which questions have been answered, and know when we have enough to produce a brief.
**Recommendation:** Add a brainstorm session tracker (JSON file) that persists question state.
**Priority:** High

### Insight 4: Voice messages should auto-trigger brainstorm mode
**Finding:** Currently, voice messages arrive as channel messages with `attachment_file_id`. Claude needs to be told to download and transcribe them. This should be automatic.
**Recommendation:** Add voice detection to the Telegram dispatch logic — when a voice message arrives, auto-transcribe and route to `/voice-brainstorm`.
**Priority:** High

## Recommendations

### Immediate Actions
1. Build `/voice-brainstorm` command that wraps `/brainstorm` with voice I/O
2. Add voice message auto-detection to the Telegram listener
3. Use Gemini 2.0 Flash for transcription (already working in `transcribe-voice.sh`)

### Short-term
4. Add Gemini TTS for voice responses (bidirectional voice conversation)
5. Add session persistence so brainstorm state survives across messages

### Long-term
6. Multi-modal brainstorming (voice + images + links)
7. Auto-generate a brief.md at the end and kick off `/design-doc`

## Sources

- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Gemini Audio Understanding](https://ai.google.dev/gemini-api/docs/audio)
- [Gemini TTS](https://ai.google.dev/gemini-api/docs/speech-generation)
- [Best Speech Recognition Models 2026](https://aiportalx.com/blog/best-speech-recognition-models-2026-whisper-v3-gemini-audio)
- [Cheapest AI Transcription: Gemini Flash vs Whisper](https://www.arsturn.com/blog/cheapest-ai-transcription-models-is-gemini-flash-the-best)
- [AI Voice Chat in Telegram: MEETNEURA](https://blog.meetneura.ai/ai-voice-chat-in-telegram-speak-listen-remember-brainstorm-with-neura-ai/)
- [n8n Telegram Voice Bot Template](https://n8n.io/workflows/4696-conversational-telegram-bot-with-gpt-5gpt-4o-for-text-and-voice-messages/)
- [OpenAI Transcription Pricing](https://costgoat.com/pricing/openai-transcription)

---

*Generated by BMAD Method v6 - Creative Intelligence*
*Sources Consulted: 8*
