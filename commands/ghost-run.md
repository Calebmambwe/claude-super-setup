---
name: ghost-run
description: Gate-free auto-dev pipeline for Ghost Mode (internal — called by watchdog)
---

Gate-free autonomous pipeline for: $ARGUMENTS

## What This Does

This is the INTERNAL command that runs inside Claude's session during Ghost Mode. It replaces `/auto-dev` by removing both human gates and substituting programmatic guardrail checks.

**Do NOT call this directly.** Use `/ghost` instead.

## Process

### Step 1: Load Ghost Config

Read `~/.claude/ghost-config.json` and extract:
- `feature` — what to build
- `trust` — `conservative`, `balanced`, or `aggressive`
- `max_tasks` — task count limit
- `project_dir` — working directory

If config is missing or invalid, exit with error.

### Step 1.5: Resource Audit (Non-Negotiable)

Before planning, complete the Resource Audit from `rules/consistency.md`:
- Check if a matching stack template exists in `~/.claude/config/stacks/`
- Check if relevant skills apply (design-system, backend-architecture, docker)
- Read AGENTS.md if present in the project
- Search the project for existing components/patterns to reuse

Ghost mode is NOT exempt from consistency checks.

### Step 2: Run /plan

Run `/plan` with $ARGUMENTS.

This produces either a Quick Plan, Feature Spec, or Full Pipeline route.

### Step 3: Gate 1 — Auto-approve Plan (replaces human gate)

After `/plan` completes, evaluate the plan against trust-level guardrails:

**Conservative trust:**
- AUTO-APPROVE if: Quick Plan or Feature Spec route, AND estimated tasks <= `max_tasks`, AND no external API changes detected
- BLOCK if: Full Pipeline route, OR task estimate > `max_tasks`

**Balanced trust:**
- AUTO-APPROVE if: any route except Full Pipeline with estimated tasks > `max_tasks * 1.5`
- BLOCK if: Full Pipeline AND estimated tasks > `max_tasks * 1.5`

**Aggressive trust:**
- AUTO-APPROVE: always (log warning for Full Pipeline)
- BLOCK: only if estimated tasks > `max_tasks * 2` (absolute safety limit)

**On guardrail block:**
1. Update `~/.claude/ghost-config.json` — set `"status": "blocked_guardrail"`
2. Run: `bash ~/.claude/hooks/ghost-notify.sh failure "Ghost Mode blocked: plan exceeded guardrails (trust=$TRUST). Review required."`
3. Report why the guardrail blocked and exit non-zero

**On auto-approve:**
- Log: "Gate 1 auto-approved: [reason] (trust=$TRUST)"
- Continue to Step 4

### Step 4: Run /auto-tasks

Run `/auto-tasks` to decompose the plan into `tasks.json`.

### Step 5: Gate 2 — Auto-approve Tasks (replaces human gate)

After `/auto-tasks` writes `tasks.json`, evaluate against trust-level guardrails:

Read `tasks.json` and calculate:
- `task_count` — total number of tasks
- `high_risk_count` — tasks tagged as high-risk or that modify auth, payments, migrations, webhooks
- `total_files` — estimated total files across all tasks
- `touches_env` — any task modifies `.env*` files
- `touches_migrations` — any task modifies migration files

**Conservative trust:**
- AUTO-APPROVE if ALL: `task_count <= max_tasks`, `high_risk_count == 0`, `total_files <= 30`, `touches_env == false`, `touches_migrations == false`
- BLOCK if ANY guardrail fails

**Balanced trust:**
- AUTO-APPROVE if ALL: `task_count <= max_tasks * 1.5`, `high_risk_count <= 2`, `touches_env == false`
- BLOCK if: `high_risk_count > 2` OR `touches_env == true`

**Aggressive trust:**
- AUTO-APPROVE if: `task_count <= max_tasks * 2`, `touches_env == false`
- BLOCK if: exceeds absolute limits

**On guardrail block:**
1. Update `~/.claude/ghost-config.json` — set `"status": "blocked_guardrail"`
2. Run: `bash ~/.claude/hooks/ghost-notify.sh failure "Ghost Mode blocked: tasks exceeded guardrails. [task_count] tasks, [high_risk_count] high-risk. Review required."`
3. Report why the guardrail blocked and exit non-zero

**On auto-approve:**
- Log: "Gate 2 auto-approved: [task_count] tasks, [high_risk_count] high-risk (trust=$TRUST)"
- Continue to Step 6

### Step 6: Delegate to /auto-ship

Run `/auto-ship` with $ARGUMENTS. This is the identical existing 8-phase pipeline:
1. Pre-flight
2. Build all tasks (Ralph Loop)
3. Coverage gate
4. Direct verification
5. Visual verification
6. Check gate
7. Ship (commit + PR)
8. Self-review

`/auto-ship` handles everything from here — no logic duplication.

### Step 7: Post-completion

After `/auto-ship` completes:
1. Extract PR URL from the auto-ship output
2. Update `~/.claude/ghost-config.json` — set `"status": "complete"` and `"pr_url": "{url}"`
3. Run: `bash ~/.claude/hooks/ghost-notify.sh success "Ghost Mode complete! PR ready for review." "{pr_url}"`

## Rules

- This command is a pipeline orchestrator — it NEVER duplicates logic from sub-commands
- NEVER call this directly — it's designed to run inside `claude -p` via the watchdog
- On guardrail block, ALWAYS update config status and notify BEFORE exiting
- On any unrecoverable error, set status to `"blocked_guardrail"` and notify
- Trust levels are strictly enforced — no escalation within a run
- .env files are NEVER auto-approved regardless of trust level
