---
name: auto-dev
description: Fully autonomous pipeline — idea to PR in one command (plan → tasks → build → check → ship)
---

Autonomous end-to-end pipeline: $ARGUMENTS

## What This Does

Single command that chains the entire SDLC: `/auto-plan` → `/auto-ship` → `/reflect`.
Two human gates: plan approval and task approval. Everything else is autonomous.

Full chain:
```
/auto-dev "feature description"
  ├── Phase A: /auto-plan (strategic plan + tactical task decomposition)
  │   ├── /plan (research gate, BMAD routing, architecture)
  │   ├── Human gate: review plan
  │   ├── /auto-tasks (decompose into tasks.json)
  │   └── Human gate: approve tasks
  ├── Phase B: /auto-ship (build + check + ship)
  │   ├── /auto-build-all (Ralph Loop per task)
  │   ├── Coverage gate (80% for new code)
  │   ├── Direct verification (test + lint + typecheck)
  │   ├── Visual verification pipeline (if UI changes):
  │   │   ├── /visual-verify (console errors, network, layout)
  │   │   ├── /visual-regression (3-viewport screenshot diff)
  │   │   └── visual-tester agent (interactive UI flows)
  │   ├── /check (code review + security + quality)
  │   ├── /ship (commit + PR)
  │   └── Self-review (PR review comments)
  └── Phase C: /reflect (capture learnings)
```

## Process

### Phase 0: Resource Audit (Non-Negotiable)

Before planning, complete the Resource Audit from `rules/consistency.md`:
- Check if a matching stack template exists in `~/.claude/config/stacks/`
- Check if relevant skills apply (design-system, backend-architecture, docker)
- Read AGENTS.md if present in the project
- Search the project for existing components/patterns to reuse

Do NOT proceed to planning until the audit is complete. Autonomous does not mean reckless.

### Phase A: Plan + Decompose

Run `/auto-plan` with $ARGUMENTS.

This executes:
1. `/plan` — research gate, 3-tier routing (Quick Plan / Feature Spec / Full Pipeline), RAG query, Mermaid diagrams
2. **Human gate** — user reviews the plan
3. `/auto-tasks` — architect agent decomposes into dependency-ordered tasks.json
4. **Human gate** — user approves task list

**Notify user between phases:**
```bash
osascript -e 'display notification "Plan complete. Review and approve to continue." with title "Auto-Dev" sound name "Glass"' 2>/dev/null
```

### Phase B: Build + Check + Ship

Run `/auto-ship` with $ARGUMENTS as context.

This executes the full build pipeline autonomously:
1. Pre-flight (branch safety, tasks.json validation)
2. Build all tasks (Ralph Loop: plan → implement → verify → fix)
3. Coverage gate (80% threshold for new code)
4. Direct verification (pnpm test && lint && typecheck)
5. Visual verification pipeline (mandatory if .tsx/.jsx/.css files changed):
     a. `/visual-verify` — console errors, network failures, layout checks
     b. `/visual-regression` — screenshot comparison at 3 viewports
     c. `visual-tester` agent — deep interactive UI verification
6. Check gate (code review + security audit)
7. Ship (conventional commit + PR)
8. Self-review (PR review toolkit posts comments)

**Notify user on completion:**
```bash
osascript -e 'display notification "Build + Ship complete. PR created." with title "Auto-Dev" sound name "Purr"' 2>/dev/null
```

### Phase C: Reflect

Run `/reflect` to capture session learnings.

### Final Report

```
## Auto-Dev Complete

Feature: $ARGUMENTS
Planning: /plan route = {Quick Plan / Feature Spec / Full Pipeline}
Tasks: {completed}/{total} ({blocked} blocked)
Check: {PASS/FAIL}
PR: {url}

Pipeline trace:
  /plan           {duration}  ✓
  /auto-tasks     {duration}  ✓
  /auto-build-all {duration}  {completed}/{total} tasks
  /check          {duration}  {verdict}
  /ship           {duration}  PR #{number}
  /reflect        {duration}  {n} learnings

Total: {total duration}
```

## Rules

- If $ARGUMENTS is empty, ask the user what to build
- ALWAYS pause for human approval after /plan and after /auto-tasks
- NEVER skip the check gate — quality is non-negotiable
- If /auto-ship fails, report clearly and stop — don't restart from scratch
- Visual verification (all 3 tools: /visual-verify + /visual-regression + visual-tester agent) is MANDATORY if any .tsx/.jsx/.css/.html files were changed
- This command is a pipeline orchestrator — it NEVER duplicates logic from sub-commands
