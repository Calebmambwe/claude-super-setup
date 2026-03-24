# HANDOVER.md — Cross-Session State

**Pattern source:** Manus.ai file-based context management + state summarization
**Purpose:** Preserve critical state across Claude Code sessions so new sessions start with full context

**Last updated:** {auto-updated by /reflect or /eod-summary}

---

## How This File Works

Claude Code sessions are ephemeral — context is lost when a session ends. This file bridges sessions by capturing the minimum state needed for a new session to continue work seamlessly.

**Writers:** `/reflect`, `/eod-summary`, `/auto-ship`, `/ghost-run` (update on completion)
**Readers:** Session start (loaded via CLAUDE.md include or manual read), `/morning-brief`

## Current Sprint

**Sprint:** Enterprise Agent Platform Sprint 4
**Branch:** feat/ghost-sprint4-20260324-1613
**Goal:** Personal assistant commands + Manus agent patterns
**Started:** 2026-03-24
**Status:** In progress

## Active Work

### In Progress
- {task/feature currently being worked on}
- {branch and PR if applicable}

### Recently Completed
- Sprint 3: Enterprise dev process (design doc templates, SMURF tests, 3-gate review, feature flags, PR/FAQ, post-mortem) — merged
- Sprint 2: Gemini media + voice transcription — merged
- Sprint 1: Portability foundation + auto-develop — merged

### Blocked
- {blocked items with reason and action needed}

## Key Decisions Made This Sprint

Record decisions that affect future work. Format: decision + rationale.

1. {Decision}: {rationale}
2. {Decision}: {rationale}

## Context for Next Session

### Must Know
- {Critical context that a new session needs immediately}
- {e.g., "Redis is not configured in docker-compose yet — Task 7 depends on it"}

### Nice to Know
- {Helpful but not critical context}
- {e.g., "The learning ledger has 5 unpromoted learnings — run /consolidate"}

### Watch Out For
- {Known issues or gotchas discovered this sprint}
- {e.g., "ghost-notify.sh uses grep -oP which doesn't work on macOS — use grep + sed"}

## File Changelog

Track what was modified across recent sessions to avoid re-reading unchanged files:

| Date | Files Modified | Summary |
|------|---------------|---------|
| {date} | {file list} | {what changed} |

## Pipeline State

### Ghost Mode
- **Last run:** {date + result}
- **Config:** `~/.claude/ghost-config.json`
- **Status:** {running / complete / blocked}

### Tasks
- **File:** `tasks.json`
- **Progress:** {X}/{Y} completed
- **Blocked:** {count} tasks

### Recent PRs
| # | Title | Status | Branch |
|---|-------|--------|--------|
| {num} | {title} | {open/merged/closed} | {branch} |

---

## Rules for Updating This File

1. **Update at session boundaries** — `/reflect` and `/eod-summary` should update this file
2. **Keep it current** — stale handover state is worse than no state (causes wrong assumptions)
3. **Minimum viable context** — only include what a new session NEEDS. If it's in git log, don't duplicate it.
4. **Delete completed items** — don't let "Recently Completed" grow beyond 5 items. Archive to git history.
5. **Never include secrets** — no API keys, tokens, or credentials
6. **Date everything** — entries without dates become untrustworthy quickly
7. **New session protocol:** Read HANDOVER.md → Read tasks.json → Read PROJECT_ANCHOR.md → Start work

## Integration with Other Files

| File | Role | Relationship |
|------|------|-------------|
| `PROJECT_ANCHOR.md` | Goal anchoring during execution | HANDOVER sets the goal, ANCHOR enforces it |
| `AGENTS.md` | Permanent project knowledge | HANDOVER is temporal, AGENTS.md is durable |
| `tasks.json` | Task-level progress | HANDOVER summarizes, tasks.json is authoritative |
| `ghost-config.json` | Pipeline runtime state | HANDOVER records outcomes, config tracks runtime |
| `MEMORY.md` | Cross-project memory | HANDOVER is project-scoped, MEMORY is global |
