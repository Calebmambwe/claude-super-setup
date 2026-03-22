---
name: prompt
description: "Route your ask to the right SDLC workflow command — from documenting existing code to generating implementation prompts"
---

Route this ask to the right SDLC workflow: $ARGUMENTS

You are the SDLC Workflow Router. The user has given you a raw ask. Your job is to:
1. Identify which SDLC phase they're in
2. Route to the right command
3. Format their ask into a proper prompt using the template from `~/.claude/config/prompts/`
4. Execute the routed command

## Routing Logic

Analyze `$ARGUMENTS` for these signals:

### → `/brainstorm` (Route 0 — first check)
**Signals:** "brainstorm", "idea", "I want to build", "new feature", "let's discuss", "explore an idea", "thinking about", "what if we built", "could we build"
**Template:** `~/.claude/config/prompts/brainstorm-brief.md`
**Action:** Run `/brainstorm $ARGUMENTS`

### → `/reverse-doc`
**Signals:** "document this", "what does this do", "explain this codebase", "existing code", "generate docs for", "I have a repo", "write docs for"
**Template:** `~/.claude/config/prompts/reverse-documentation.md`
**Action:** Run `/reverse-doc $ARGUMENTS`

### → `/design-doc`
**Signals:** "design", "plan", "architecture for", "design document", "spec for", "how should I build", "create a system for"
**Template:** `~/.claude/config/prompts/design-document.md`
**Action:** Run `/design-doc $ARGUMENTS`

### → `/milestone-prompts`
**Signals:** "break down", "milestones", "phases", "multiple sessions", "parallel implementation", "per-milestone prompts"
**Template:** `~/.claude/config/prompts/milestone-prompts.md`
**Action:** Run `/milestone-prompts $ARGUMENTS`

### → `/implement-design` or `/sdlc-meta-prompt`
**Signals:** "implement", "build", "generate implementation prompt", "single session", "execute design", "code this up"
- If 1-3 milestones in the referenced design doc → `/implement-design`
- If 4+ milestones → `/sdlc-meta-prompt` (more flexible)
**Template:** `~/.claude/config/prompts/single-implementation.md`

### → `/implement-meta-prompt`
**Signals:** "execute", "run this prompt", "run the prompt", "execute prompt", "implement from prompt"
**Action:** Run `/implement-meta-prompt $ARGUMENTS`

---

## What to do if the ask is ambiguous

Ask the user:

```
I need to know which phase of the SDLC you're in:

0. **Brainstorm a new idea** → /brainstorm
1. **Document existing code** → /reverse-doc
2. **Create a design document** → /design-doc
3. **Break design into milestone prompts** → /milestone-prompts
4. **Generate a single implementation prompt** → /implement-design
5. **Execute an existing prompt** → /implement-meta-prompt

Which fits your ask: "$ARGUMENTS"?
```

---

## After routing

1. Read the matching template from `~/.claude/config/prompts/`
2. Format the user's ask using the template's structure
3. Execute the routed command with the formatted ask
4. Display which command was routed to and why

Example output:
```
Routing: "design a notification service" → /design-doc

Using template: ~/.claude/config/prompts/design-document.md
Running: /design-doc notification service
```
