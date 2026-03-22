---
name: auto-plan
description: Plan + decompose into tasks — chains /plan → /auto-tasks
---

Plan and decompose into tasks: $ARGUMENTS

## What This Does

Chains `/plan` → `/auto-tasks` into a single command. First runs `/plan` for strategic
analysis (research, routing, architecture), then feeds the output into `/auto-tasks` for
tactical decomposition into `tasks.json`.

## Process

### Step 1: Strategic Planning via /plan

Run `/plan` with $ARGUMENTS. This gives you:
- Research Gate (Context7 verification for all libraries/APIs)
- 3-tier routing based on scope:
  - **Quick Plan** — task is clear, just need to map files and dependencies
  - **Feature Spec** — scope is unclear, needs /spec workflow
  - **Full Pipeline** — major feature, needs BMAD method (PRD → architecture → spec)
- RAG query (knowledge-rag MCP for existing design decisions in docs/)
- Mermaid architecture diagrams
- VS Code plan review (editable markdown in editor)

**Human gate:** After /plan completes, the user reviews the plan in VS Code.
Only proceed to Step 2 after user approval.

### Step 2: Tactical Decomposition via /auto-tasks

Run `/auto-tasks` with the artifacts /plan just created as input:
- If /plan created a spec → pass the spec path
- If /plan created a design doc → pass the design doc path
- If /plan created PRD + architecture (Full Pipeline) → pass the architecture doc

/auto-tasks will:
- Run its own Source Discovery (Step 1) using the /plan artifacts
- Run Research Gate if needed (safety net — usually skipped since /plan already researched)
- Launch architect agent to extract file-level details
- Decompose into dependency-ordered tasks (1-3 files each)
- Show human approval gate before writing tasks.json

### Step 3: Report

```
## Auto-Plan Complete

Planning: /plan route = {Quick Plan / Feature Spec / Full Pipeline}
Research: {conducted / not needed}
Artifacts: {list of files /plan created}
Tasks: {count} tasks in tasks.json

Next:
- Run /auto-build to implement one task at a time
- Run /auto-build-all to implement all tasks autonomously
- Run /auto-ship to build + check + ship in one pass
```

## Rules

- ALWAYS run /plan before /auto-tasks — never skip strategic planning
- ALWAYS pause between /plan and /auto-tasks for human review of the plan
- If /plan routes to Full Pipeline (BMAD), each BMAD phase pauses for human review
- If $ARGUMENTS is empty, ask the user what to plan
- Pass /plan artifacts as explicit file paths to /auto-tasks
