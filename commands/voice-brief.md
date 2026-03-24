---
name: voice-brief
description: "Transcribe voice thoughts into a structured feature brief — speak scattered ideas, get organized requirements"
---

Structure this into a feature brief: $ARGUMENTS

## What This Does

`/voice-brief` takes raw, unstructured text (typically from a voice transcription or a brain dump) and transforms it into a structured feature brief. This is the voice-first entry point into the SDLC pipeline.

```
/voice-brief "I was thinking about building something that helps people track their habits but like not just checkboxes you know more like streaks and maybe some kind of social accountability thing where you can share your progress with friends"
  ├── Parse raw text
  ├── Extract key ideas
  ├── Structure into brief format
  ├── Save to docs/{feature}/brief.md
  └── Suggest next steps
```

## When to Use

- After sending a voice note via Telegram (the transcription becomes $ARGUMENTS)
- When you have scattered thoughts you want to organize quickly
- As a faster alternative to `/brainstorm` when you already know what you want
- Before `/design-doc` or `/auto-plan` to create the required input brief

## Process

### Step 1: Parse Input

Accept the text from $ARGUMENTS. This text may be:
- A Whisper transcription (raw, no punctuation, stream of consciousness)
- A typed brain dump (informal, scattered ideas)
- A pasted conversation snippet

If $ARGUMENTS is empty, ask: "Share your idea — type it out or send a voice note. I'll structure it into a feature brief."

### Step 2: Extract Key Elements

Analyze the raw text to identify:
1. **Core problem** — What pain point or need is being addressed?
2. **Proposed solution** — What should be built?
3. **Target users** — Who benefits from this?
4. **Key features** — What specific capabilities are mentioned?
5. **Constraints** — Any mentioned limitations (time, tech, team)?
6. **Out of scope** — Anything explicitly excluded?
7. **Motivation** — Why now? What triggered this idea?

### Step 3: Generate Feature Name

Derive a kebab-case feature name from the core idea:
- 2-4 words, descriptive
- Examples: `habit-tracker`, `voice-brainstorm`, `social-accountability`

### Step 4: Write Brief

Generate a structured brief using this format:

```markdown
# Feature Brief: {Feature Name}

**Created:** {date}
**Status:** Draft
**Source:** Voice transcription / Brain dump

---

## Problem

{1-3 sentences describing the core problem or need}

---

## Proposed Solution

{2-5 sentences describing what should be built}

---

## Target Users

**Primary:** {who benefits most}

**Secondary:** {other beneficiaries, if any}

---

## Key Features

1. {Feature 1} — {one-line description}
2. {Feature 2} — {one-line description}
3. {Feature 3} — {one-line description}
{... up to 7 features}

---

## Constraints

| Constraint | Detail |
|------------|--------|
| {Type} | {Detail} |

---

## Out of Scope

- {Thing explicitly not being built}

---

## Notes

{Any additional context, open questions, or ideas mentioned in the original voice note}

---

## Original Transcription

> {The raw input text, preserved for reference}
```

### Step 5: Save Brief

Save to `docs/{feature-name}/brief.md`:
```bash
mkdir -p docs/{feature-name}/
```

### Step 6: Reply

Show a summary of the structured brief:

```
## Voice Brief Created

Feature: {feature-name}
Saved: docs/{feature-name}/brief.md
Problem: {one-line problem statement}
Solution: {one-line solution summary}
Features: {count} key features identified

Next steps:
- Review and edit the brief: docs/{feature-name}/brief.md
- Generate a design doc: /design-doc {feature-name}
- Jump to planning: /auto-plan
- Full pipeline: /auto-dev {feature-name}
```

If in Telegram context:
1. Send the summary as a reply
2. React with a clipboard emoji to the original voice message (if applicable)

## Rules

- ALWAYS preserve the original transcription in the brief — it's valuable context
- NEVER ask clarifying questions for a voice brief — just structure what was given and note gaps as "Open Questions"
- ALWAYS derive the feature name automatically — don't ask the user to name it
- Keep the brief concise — if the voice note was 30 seconds, the brief should be ~1 page
- If the input is clearly NOT a feature idea (e.g., a question, a greeting), respond conversationally instead of forcing a brief
- Save the file even if the input is sparse — a thin brief is better than no brief
- In Telegram context, ALWAYS send the summary as a new reply (not an edit) for push notification
