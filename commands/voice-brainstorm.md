---
name: voice-brainstorm
description: "Voice brainstorming via Telegram — iterative voice conversation that produces a structured feature brief. Send voice notes, get questions back, refine your idea."
---

Voice brainstorm session: $ARGUMENTS

## What This Does

`/voice-brainstorm` is the voice-first brainstorming loop. You speak scattered ideas via Telegram voice notes, Claude asks targeted questions, and after 3-5 exchanges you get a structured feature brief. Works with both voice input (auto-transcribed) and text input.

```
Send voice note → Claude transcribes + asks a question → Send another voice note
  → Claude refines → Send more → Claude produces docs/{feature}/brief.md
```

## Process

### Step 1: Detect Input Type

Check if this was triggered by a voice message or text:

**If called from Telegram with a voice message:**
1. The channel message will have an `attachment_file_id` attribute
2. Call `download_attachment` with the `file_id` to get the local OGG file
3. Read the downloaded file path
4. Transcribe using: `bash scripts/transcribe-voice.sh <file_path>`
5. Use the transcription as the input text

**If called with text ($ARGUMENTS is not empty):**
- Use $ARGUMENTS directly as input text

**If called with no input:**
- Reply: "Send me a voice note with your idea — or type it out. I'll help you brainstorm it into a structured brief."
- If on Telegram, add: "Just record a voice note and send it. I'll transcribe and start brainstorming."

### Step 2: Load or Create Session

Read session state:
```bash
cat ~/.claude/voice-brainstorm-session.json 2>/dev/null || echo '{}'
```

**If no session or session is older than 1 hour:**
- Create new session
- Set `status: "active"`, `exchanges: 0`
- Initialize all questions as `null`

**If active session exists:**
- Continue it
- Increment `exchanges`

**Session structure:**
```json
{
  "session_id": "vb-TIMESTAMP",
  "feature_name": null,
  "started_at": "ISO-8601",
  "status": "active",
  "exchanges": 0,
  "answers": {
    "what_to_build": null,
    "who_for": null,
    "core_constraint": null,
    "out_of_scope": null,
    "why_now": null
  },
  "raw_inputs": [],
  "chat_id": null
}
```

### Step 3: Process Input

Take the transcription/text and:

1. **Clean up** — Add punctuation if needed, fix obvious speech-to-text errors
2. **Extract information** — Identify which brainstorm questions this input answers
3. **Update session** — Fill in answered questions, append to `raw_inputs`
4. **Save session** — Write updated state to `~/.claude/voice-brainstorm-session.json`

**Information extraction rules:**
- If input mentions WHAT to build → fill `what_to_build`
- If input mentions WHO uses it → fill `who_for`
- If input mentions constraints (time, tech, team) → fill `core_constraint`
- If input mentions what NOT to build → fill `out_of_scope`
- If input mentions motivation/timing → fill `why_now`
- A single voice note can answer multiple questions

### Step 4: Determine Response

Count how many questions are answered (non-null):

**0-1 answered:** Ask the most important unanswered question first
- Priority: what_to_build > who_for > core_constraint > out_of_scope > why_now

**2-3 answered:** Ask refinement questions
- "You mentioned X — can you be more specific about Y?"
- Fill in gaps with follow-up questions

**4-5 answered:** Propose the brief
- Summarize what you've captured
- Ask: "Does this capture your idea? Say 'yes' to generate the brief, or tell me what to change."

**User says "done"/"ship it"/"that's enough"/"yes"/"generate it":**
- Skip remaining questions
- Generate the brief immediately

### Step 5: Reply

**CRITICAL: Keep responses voice-friendly:**
- Maximum 2-3 sentences
- One question at a time
- Conversational tone ("Cool! So..." not "Please specify...")
- Acknowledge what the user said before asking the next question
- Use simple words (this will be read on a phone screen while walking)

**Response format:**
```
[Brief acknowledgment of what you heard]
[One follow-up question]
```

**Example responses:**

First exchange (got what_to_build):
> "Got it — a habit tracker with streaks and social features. Who's the main user? Fitness crowd, students, everyone?"

Second exchange (got who_for):
> "Gen Z self-improvement crowd, nice. What's your constraint — timeline, tech stack, team size?"

Third exchange (got core_constraint):
> "Solo dev, 2 weeks, React Native. What's NOT in v1? Like, skip social features? No payments?"

Fourth exchange (got out_of_scope):
> "OK — no monetization, no social feed, just streaks and basic sharing. What triggered this idea? Anything specific or just been thinking about it?"

Final (all answered):
> "Here's what I've got:
>
> **habit-streaks** — Streak-based habit tracker for Gen Z
> - Problem: Traditional habit apps are boring
> - Users: Gen Z/millennials into self-improvement
> - Constraint: Solo dev, 2 weeks, React Native
> - Out of scope: Monetization, social feed
> - Trigger: Personal frustration with existing apps
>
> Say 'yes' to generate the brief, or tell me what to change."

### Step 6: Generate Brief

When the user confirms (or after all questions answered + confirmation):

1. **Derive feature name** — kebab-case, 2-4 words from the core idea
2. **Create directory** — `docs/{feature-name}/`
3. **Write brief.md** using the standard brief template:

```markdown
# Feature Brief: {Feature Name}

**Created:** {date}
**Status:** Draft
**Source:** Voice brainstorm session {session_id}

---

## Problem

{What pain point or need was described}

---

## Proposed Solution

{What the user wants to build, in 2-3 sentences}

---

## Target Users

**Primary:** {who_for answer}

---

## Constraints

| Constraint | Detail |
|------------|--------|
| {constraint_type} | {constraint_detail} |

---

## Scope

### In Scope
{List of features/capabilities mentioned}

### Out of Scope
{out_of_scope answer}

---

## Why Now

{why_now answer, or "User-initiated brainstorm"}

---

## Raw Voice Transcriptions

{All raw_inputs from session, for reference}

---

*Generated from voice brainstorm session {session_id}*
*{exchanges} voice exchanges over {duration}*
```

4. **Notify user:**
```
Brief generated: docs/{feature-name}/brief.md

Next steps:
- /design-doc {feature-name} → full design document
- /auto-plan {feature-name} → plan + task decomposition
- /auto-dev {feature-name} → fully autonomous implementation
```

5. **Clear session** — delete `~/.claude/voice-brainstorm-session.json`

### Step 7: Handle Edge Cases

**Session timeout (>1 hour):**
- Auto-generate a partial brief from whatever was captured
- Notify: "Your brainstorm session timed out. I saved what we had to docs/{feature}/brief.md"

**User says "cancel"/"nevermind"/"forget it":**
- Clear session without generating brief
- Reply: "Cancelled. Send another voice note anytime to start fresh."

**User sends a non-voice text message during a voice brainstorm:**
- Treat it as text input (same as transcription)
- Continue the session normally

**Multiple rapid voice notes:**
- Concatenate transcriptions
- Treat as one long input

## Voice Response (TTS — Active)

After generating the text response, also send a voice note back:

```bash
# Generate voice response via Gemini TTS (free)
bash scripts/gemini-tts.sh "response text" /tmp/tts-response-$(date +%s).ogg
```

Then send both text AND voice via Telegram:
```
reply(chat_id, "response text", files=["/tmp/tts-response-TIMESTAMP.ogg"])
```

If TTS fails (script exits non-zero), fall back to text-only — never block the conversation on TTS failure.

## Session Manager Integration

Instead of the simple JSON file at `~/.claude/voice-brainstorm-session.json`, use the session manager:

```bash
# Start session
SESSION_ID=$(bash scripts/voice-session-manager.sh start "$CHAT_ID" "$TOPIC")

# Add exchange
bash scripts/voice-session-manager.sh add-exchange "$SESSION_ID" user "$TRANSCRIPTION"
bash scripts/voice-session-manager.sh add-exchange "$SESSION_ID" assistant "$RESPONSE"

# End session (saves transcript to docs/voice-sessions/)
bash scripts/voice-session-manager.sh end "$SESSION_ID"
```

Both the old JSON approach and new session manager are compatible — the session manager stores richer state in `/tmp/voice-sessions/`.

## Ship-It → SDLC Pipeline

When the user says **"ship it"**, **"build this"**, **"build it"**, **"done"**, or **"that's enough"**:

1. End the session: `bash scripts/voice-session-manager.sh end "$SESSION_ID"`
2. Run the SDLC pipeline: `bash scripts/voice-to-sdlc.sh "$SESSION_ID" --feature-name "$FEATURE_NAME"`
3. Show the generated brief to the user for confirmation
4. If user confirms → trigger `/auto-dev $FEATURE_NAME`

This completes the full loop: **speak → brainstorm → brief → auto-dev → PR**

The voice-to-sdlc.sh script handles: transcript cleanup, brief generation, FEATURES.md update, and optional auto-dev trigger.
