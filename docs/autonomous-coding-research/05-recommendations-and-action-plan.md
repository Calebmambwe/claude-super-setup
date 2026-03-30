# Recommendations and Action Plan

**Date:** 2026-03-28
**Goal:** Achieve Manus.ai-level reliability in Claude Code autonomous coding

---

## Executive Summary

Your Claude Code setup is architecturally sophisticated — 68 agents, 34 hooks, 4 team presets, benchmarks, and a self-improvement loop. However, the autonomous coding results are inconsistent because of **6 critical issues** that cause pipelines to deadlock, loop, or produce garbage output:

1. SDLC artifact hooks deadlock headless sessions (CRITICAL)
2. Stop hook blocks autonomous sessions with no human to respond
3. OTEL telemetry noise triggers false budget-exhaustion kills in Ghost Mode
4. Ghost Mode restarts with wrong command after crash
5. CLAUDE.md is likely over 200 lines (attention dilution)
6. All subagents forced to Sonnet (no model escalation for complex tasks)

The fix is NOT more complexity. It's **less noise + smarter defaults + deterministic enforcement.**

---

## Phase 1: Critical Fixes (Day 1) — Make Autonomous Actually Work

### Fix 1.1: Add Headless Session Guard to All Blocking Hooks

Every `type: "prompt"` hook that returns `{"decision": "block"}` must check if the session is headless first:

**Stop hook:** Add guard — if `CLAUDE_CODE_HEADLESS=1` or running inside screen session, always return `allow`.

**SDLC artifact hooks (research.md, brief.md, design-doc.md, architecture.md, prompts/*.md):** Same guard. In autonomous mode, these should log a note but NOT block.

**SubagentStop hook:** Same guard.

### Fix 1.2: Fix Ghost Mode Watchdog

**ghost-watchdog.sh changes:**
- Change `OTEL_METRICS_EXPORTER=console` to `OTEL_METRICS_EXPORTER=none` for ghost sessions
- Fix budget detection: `grep -qi "budget.*exhausted\|max.*budget.*reached"` instead of `grep -qi "budget"`
- Fix checkpoint phase regex: `^[0-9]+(\.[0-9]+)?$` instead of `^[0-9]+$`
- Fix restart logic: check `.claude/pipeline-checkpoint.json` for resume path before choosing command
- Increase MAX_ATTEMPTS from 3 to 5
- Don't increment ATTEMPT on rate-limit rapid exits (duration < 60s)

### Fix 1.3: Fix auto-tasks Human Gate

Add to `/auto-tasks` command: "In autonomous/pipeline mode (when called from /ghost-run, /auto-dev, or /auto-ship), proceed without waiting for confirmation."

### Fix 1.4: Fix `subagent_type: "Plan"` in auto-build

Change `subagent_type: "Plan"` to a real agent type or inline the planning step.

---

## Phase 2: Configuration Optimization (Day 1-2) — Quality Defaults

### Fix 2.1: Prune CLAUDE.md to Under 200 Lines

**Current state:** Multiple CLAUDE.md files with overlapping rules. The combined injection is likely well over 200 lines/1,800 tokens.

**Action:**
1. Audit every line against "Would removing this cause Claude to make mistakes?"
2. Move domain-specific rules to path-scoped `.claude/rules/` files
3. Move library-specific knowledge to Skills (loaded on demand)
4. Keep only: workflow, critical gotchas, test commands, architectural decisions
5. Place MOST IMPORTANT rules at top, briefly repeat at bottom

**Target:** Under 150 lines in the main CLAUDE.md. Use `@imports` for optional context.

### Fix 2.2: Optimize Model Strategy

**Current:** All subagents use Sonnet (`CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6`)

**Recommended:**
- Remove global `CLAUDE_CODE_SUBAGENT_MODEL` env var
- Set per-agent model in frontmatter (already done for most agents)
- Use `model: "opus"` in agent frontmatter for: architect, code-reviewer, security-auditor, orchestrator
- Use `model: "sonnet"` for: frontend-dev, backend-dev, verifier, test-writer-fixer
- Use `model: "haiku"` for: doc-verifier, exploration subagents

This gives you Opus where reasoning depth matters and Sonnet/Haiku where speed matters.

### Fix 2.3: Remove OTEL Console Export

```json
"OTEL_METRICS_EXPORTER": "none"
```

Or remove the key entirely. Console export adds noise with zero value for your workflow.

### Fix 2.4: Enable Budget Guard

Rename `budget-guard.sh.disabled` to `budget-guard.sh` and set consistent `TASK_MAX_TOOL_CALLS` across global and project settings.

---

## Phase 3: Adopt Manus Patterns (Day 2-3) — Reliability Techniques

### Pattern 3.1: todo.md Attention Anchoring

Add to all autonomous commands (/auto-build, /ghost-run, /auto-ship):
```
Before starting work, create a TODO.md with numbered checklist items.
After every 10 tool calls, re-read TODO.md and update completed items.
This prevents attention drift on long tasks.
```

### Pattern 3.2: Fresh-Context Verifier

Already implemented via the `verifier` agent with `memory: none`. Ensure it's called in EVERY autonomous pipeline, not just team presets.

### Pattern 3.3: File-System as Memory

Add to autonomous commands:
```
When context is filling up (40%+), write current state to .claude/session-state.md:
- What's done
- What's remaining
- Key decisions made
- Errors encountered
Then compact and re-read the state file.
```

### Pattern 3.4: One Task Per Context Window

Enforce strictly. Each task in tasks.json should be a separate `claude -p` invocation, not a continuation. /auto-build-all already does this via Ralph Loop — ensure /ghost-run routes through it consistently.

---

## Phase 4: Streamline Pipeline (Day 3-4) — Reduce Complexity

### Simplification 4.1: Consolidate Autonomous Commands

**Current:** 3 confusingly-named commands (auto-dev, auto-develop, ghost-run)
**Recommended:**
- Keep `/auto-dev` as the interactive pipeline (2 human gates)
- Rename `/ghost-run` to the actual gate-free autonomous command
- Remove `/auto-develop` or make it an alias for `/ghost-run`
- Update all documentation to clarify the distinction

### Simplification 4.2: Reduce Hook Count

**Dead hooks to remove from filesystem:**
- sandbox-router.sh (not wired)
- auto-quality-gate.sh (not wired)
- post-session-benchmark.sh (not wired)
- anthropic-docs-monitor.sh (not wired)
- ghost-monitor.sh (not wired)
- sync-vps-config.sh (not wired)
- telemetry.sh (not wired)

10 dead scripts create confusion during audits. Delete or wire them.

### Simplification 4.3: Remove Duplicate Agents

- Delete `frontend-developer` (engineering/) — `frontend-dev` (core) is superior
- Delete `backend-architect` (engineering/) — `architect` (core) is more rigorous
- Consolidate AGENTS.md (currently at 89 lines, over 80-line trigger)

---

## Phase 5: Security Hardening (Day 4) — Remove Risks

### Fix 5.1: Tighten Permissions

- Remove `Bash(sudo *)` from allow list. Add only specific sudo commands needed.
- Add `Bash(rm -r *)` to deny list (currently only `rm -rf *` is blocked)
- Add `Write(.env*)` to deny list (currently only Read is blocked)
- Add `Bash(curl * | python3)` and `Bash(curl * > *)` to deny list

### Fix 5.2: Remove `skipDangerousModePermissionPrompt`

Per official docs, this key doesn't exist. Replace with:
- CLI flag `--dangerously-skip-permissions` only for ghost/sandbox sessions
- For interactive sessions, use `--permission-mode auto` (classifier-based)

### Fix 5.3: Scope GitHub MCP Permissions

Remove `merge_pull_request` and `create_repository` from pre-approved MCP permissions. These should require confirmation.

---

## Phase 6: Measurement (Ongoing) — Prove It Works

### Benchmark Baseline

Run the full 15-task benchmark suite 3 times to establish a rolling baseline. Current 55% pass rate should improve to 80%+ after Phase 1-2 fixes.

### Track Ghost Mode Success Rate

After fixes, run 3 Ghost Mode sessions on small features. Track:
- Did it produce a PR? (currently: 0 PRs)
- Did it deadlock? (currently: yes, at SDLC hooks)
- Did it burn budget? (currently: yes, false budget detection)
- Code quality of output (verifier agent score)

### Weekly Self-Improvement

The darwin + self-improve loop is well-designed. Run it weekly after establishing baseline.

---

## Priority Matrix

| Fix | Effort | Impact | Priority |
|-----|--------|--------|----------|
| Headless guards on blocking hooks | 1 hour | CRITICAL | P0 |
| Ghost watchdog fixes | 2 hours | HIGH | P0 |
| auto-tasks gate fix | 30 min | HIGH | P0 |
| CLAUDE.md pruning | 2 hours | HIGH | P1 |
| Model strategy optimization | 1 hour | HIGH | P1 |
| Remove OTEL console export | 5 min | MEDIUM | P1 |
| Enable budget guard | 15 min | MEDIUM | P1 |
| todo.md attention anchoring | 1 hour | HIGH | P2 |
| File-system memory pattern | 1 hour | MEDIUM | P2 |
| Pipeline consolidation | 2 hours | MEDIUM | P2 |
| Hook cleanup | 1 hour | LOW | P3 |
| Agent deduplication | 30 min | LOW | P3 |
| Permission tightening | 1 hour | MEDIUM | P3 |
| GitHub MCP scope | 15 min | LOW | P3 |

**Total estimated effort:** ~14 hours across 4 days
**Expected outcome:** Ghost Mode producing PRs, autonomous pipelines completing without deadlock, benchmark pass rate >80%

---

## The Single Most Important Change

If you only do ONE thing from this entire document:

**Add headless session guards to the Stop hook and SDLC artifact hooks.**

This single change will unblock Ghost Mode, /auto-develop, and /auto-dev from deadlocking. It's the root cause of most of your autonomous coding failures.
