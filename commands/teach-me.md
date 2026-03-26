---
name: teach-me
description: Self-teaching pipeline — research unknown tools/processes, create skills, then execute the task autonomously
---

Self-teaching pipeline: $ARGUMENTS

## Overview

This command activates the TeachMe agent — a fully autonomous pipeline that:
1. Identifies knowledge gaps for the requested task
2. Deeply researches the unknown tool/process/technology
3. Creates permanent SKILL.md skills and optionally agents/commands
4. Plans and executes the original task using the new knowledge

**The system gets permanently smarter with every invocation.**

## Process

### Step 1: Parse the Request

Extract from $ARGUMENTS:
- **Target**: The tool, framework, process, or technology to learn
- **Task**: What needs to be done with it (optional — can be "just learn it")
- **Scope**: Any constraints (e.g., "for our Next.js project", "using Python")

If $ARGUMENTS is empty, ask:
> "What would you like me to learn? Provide a tool/technology and optionally a task."
> Examples:
> - "Hono framework and build an API"
> - "Terraform for our AWS infrastructure"
> - "Stripe subscriptions"
> - "Redis caching patterns"

### Step 2: Launch TeachMe Agent

Spawn the teach-me agent (Opus) with the full context:

```
Use the Agent tool with subagent_type="general-purpose" and model="opus":

Prompt: |
  You are the TeachMe agent. Read your full instructions from agents/core/teach-me.md first.

  TASK: {$ARGUMENTS}

  Execute the full 5-phase pipeline:
  Phase 1: Gap Analysis — check existing skills, agents, commands, knowledge base
  Phase 2: Deep Research — Context7, WebSearch, WebFetch, codebase scan
  Phase 3: Skill Creation — write SKILL.md, optionally agent/command
  Phase 4: Brainstorm & Plan — design the implementation approach
  Phase 5: Execute — implement the task using new knowledge

  Save research to: docs/teach-me/{tool-name}-research.md
  Save skills to: ~/.claude/skills/{tool-name}/SKILL.md

  Report progress after each phase.
```

### Step 3: Monitor Progress

The TeachMe agent reports after each phase. If invoked from Telegram, forward phase updates to the user.

Phase checkpoints:
- Phase 1 complete → "Gap identified: {description}"
- Phase 2 complete → "Research complete: {sources consulted}, confidence: {level}"
- Phase 3 complete → "Skills created: {list}"
- Phase 4 complete → "Plan ready: {file count} files, {approach summary}"
- Phase 5 complete → "Implementation done: {summary}"

### Step 4: Final Report

After TeachMe completes, summarize:

```
TeachMe Complete!

Learned: {tool/process name}
Research: docs/teach-me/{name}-research.md
Skills added: {count} — {list}
Agents added: {count} — {list}
Commands added: {count} — {list}
Task completed: {yes/no + summary}
System is now permanently capable of: {capability description}
```

## Telegram Dispatch

When routed via NLP patterns ("teach me...", "learn...", "figure out..."):
- Send initial acknowledgment: "Starting TeachMe pipeline for: {target}"
- Forward phase updates as they complete
- Send final summary with counts

## Rules

- ALWAYS use Opus model for the TeachMe agent — it needs deep reasoning for research
- ALWAYS save research briefs to docs/teach-me/ — they're reference material
- ALWAYS create at least one SKILL.md — one-off knowledge is waste
- NEVER skip the research phase — even if you think you know the tool
- NEVER guess API signatures — use Context7 or official docs
- If research reveals the task is more complex than expected, report back before Phase 5
- If a skill already exists for the target tool, skip to Phase 4 (plan) and Phase 5 (execute)
- Keep skills focused — one tool per SKILL.md, not kitchen-sink files
