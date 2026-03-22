---
description: Automated learning capture and retrieval across sessions
globs: ["**/*"]
---

# Self-Learning Behavior Rules

These rules govern how Claude automatically captures and applies learnings from the ledger.

## Session Start

At the start of every session, retrieve relevant past learnings by calling the `search_learnings` MCP tool with the current project directory. Example:

```
search_learnings(query="", project_dir="/path/to/current/project", top_k=5)
```

Also call `get_project_learnings` to surface project-specific patterns:

```
get_project_learnings(project_dir="/path/to/current/project", limit=5)
```

If any learnings are returned, acknowledge them briefly (1–2 sentences) before starting work — do NOT list them all verbatim. Only surface ones directly relevant to the task at hand.

## During the Session

**On user correction** — when the user says "no, do X instead", "actually...", "never use...", "always use...", or similar:
1. Record it immediately using the `record_learning` MCP tool
2. Type: `correction`, confidence: 0.9
3. Include the current project_dir

**On explicit praise** — when the user says "perfect", "exactly", "yes that's right", "works great":
1. Record the preceding approach using `record_learning`
2. Type: `success`, confidence: 0.75

**On repeated mistakes** — if you catch yourself making the same mistake twice in a session:
1. Record the pattern as a `correction` with confidence: 0.85
2. Surface it to the user: "I've recorded this pattern to avoid repeating it."

## Session End

Before ending, summarize any new learnings recorded this session in a single line:
> "Recorded N learning(s) this session: [brief summary]."

If no learnings were recorded: no summary needed.

## Anti-patterns to avoid

- Do NOT flood the user with ledger results at session start — surface only relevant ones
- Do NOT record every message as a learning — only corrections, explicit praise, and repeated patterns
- Do NOT call `record_learning` more than 10 times per session (prevents noise)
