# Autonomous Coding Pipeline Analysis

**Date:** 2026-03-28
**Scope:** Full analysis of ghost mode, auto-dev, auto-build, and all autonomous workflows

---

## Pipeline Hierarchy

```
/ghost "feature"                  -- launcher only
  +-- ghost-watchdog.sh           -- process supervisor (screen + caffeinate)
        +-- claude -p /ghost-run  -- actual pipeline
              |-- /plan           -- research + 3-tier routing
              |-- Gate 1          -- auto-approves plan
              |-- /auto-tasks     -- architect decomposes to tasks.json
              |-- Gate 2          -- auto-approves tasks
              +-- /auto-ship      -- build + check + ship
                    |-- /auto-build-all  -- Ralph Loop per task
                    |     +-- /auto-build -- Plan > Implement > Verify > Fix
                    |-- Coverage gate (80%)
                    |-- Direct verify (test+lint+typecheck)
                    |-- /regression-gate --tier 2
                    |-- Visual verification (3-tool)
                    |-- /check    -- 6 parallel agents
                    +-- /ship     -- commit + PR

/auto-dev "feature"               -- interactive (2 human gates)
  |-- /auto-plan > /plan + /auto-tasks (with gates)
  +-- /auto-ship (same as above)

/auto-develop "feature"           -- zero-gate with BMAD phases
  |-- /bmad:research
  |-- /brainstorm
  |-- /design-doc
  |-- /auto-plan
  |-- /auto-build-all
  |-- Visual verification
  |-- /check
  |-- /ship
  +-- /reflect
```

---

## 10 Critical Issues Found

### Issue #1: Only 3 Restart Attempts (HIGH)
**File:** `ghost-watchdog.sh:184`
- MAX_ATTEMPTS=3, backoff 15/30/60s
- Rate limit hits burn attempts without useful work
- Attempt counter increments even on rate-limit rapid exits

### Issue #2: OTEL Telemetry Pollutes Ghost Logs (HIGH)
**File:** `settings.json` (`OTEL_METRICS_EXPORTER=console`)
- Raw telemetry JSON in log files
- Budget detection (`grep -qi "budget"`) triggers false positives on telemetry text
- Fast exit + OTEL noise = spurious "budget exhausted" kills

### Issue #3: Session ID Never Captured (HIGH)
**File:** `ghost-watchdog.sh:271-275`
- Grep pattern matches non-existent log format
- session_id stays null permanently
- Wrong command on restart: `/auto-ship` instead of `/ghost-run` on attempt 2+

### Issue #4: `subagent_type: "Plan"` Invalid (MEDIUM)
**File:** `auto-build.md:23`
- No "Plan" subagent type exists in Claude Code
- Silently falls back to default behavior
- Plan phase doesn't reliably use Opus or specialized context

### Issue #5: Stop Hook Blocks Headless Sessions (HIGH)
**File:** `settings.json:363-378`
- Fires for ALL sessions including `claude -p`
- `"block"` decision keeps Claude running, burning budget
- No guard for non-interactive mode

### Issue #6: SDLC Artifact Hooks Block Autonomous Pipelines (CRITICAL)
**File:** `settings.json:257-300`
- PostToolUse blocking hooks on research.md/brief.md/design-doc.md writes
- "Tell the user: run /design-doc next" in headless = deadlock
- Most likely cause of inconsistent autonomous results

### Issue #7: Checkpoint Phase Float vs Integer Regex (MEDIUM)
**File:** `ghost-watchdog.sh`
- `^[0-9]+$` regex doesn't match phases like `2.25`, `2.5`
- Pipeline never considered "done" by watchdog
- Causes redundant restarts of completed phases

### Issue #8: /auto-tasks Has Hidden Human Gate (MEDIUM)
**File:** `auto-tasks.md:62-77`
- "Write tasks.json? [yes / adjust / abort]" inside the command
- Fires BEFORE ghost-run's Gate 2
- Claude sometimes interprets this as requiring actual human response

### Issue #9: Three "Autonomous" Commands Confuse Routing (MEDIUM)
- `/auto-dev` — has 2 human gates despite "fully autonomous" description
- `/auto-develop` — actually zero-gate but triggers SDLC blocking hooks
- `/ghost-run` — genuinely gate-free but documented as "Do NOT call directly"

### Issue #10: Insufficient Restarts for Complex Pipelines (MEDIUM)
- 3 attempts insufficient for 60-120+ minute pipelines
- No checkpoint-aware restart logic
- Should resume via /auto-ship (not /ghost-run) on subsequent attempts

---

## Recommended Fixes (Priority Order)

1. **Fix Stop hook** — add non-interactive session guard, respond `allow` unconditionally in headless
2. **Fix SDLC artifact hooks** — add autonomous mode guard, output `{"decision": "allow"}` when ghost-config.json status = "running"
3. **Fix budget detection regex** — replace `grep -qi "budget"` with specific pattern
4. **Fix checkpoint phase matching** — use float-capable regex and comparison
5. **Fix restart command selection** — check pipeline-checkpoint.json for resume path
6. **Fix `subagent_type: "Plan"`** — use valid agent type or inline planning
7. **Fix /auto-tasks approval gate** — auto-proceed in headless/pipeline mode
8. **Increase MAX_ATTEMPTS** to 5, don't increment on rate-limit rapid exits
