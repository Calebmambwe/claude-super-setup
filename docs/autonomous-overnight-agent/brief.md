# Feature Brief: Autonomous Overnight Agent

**Created:** 2026-03-28
**Status:** Draft

---

## Problem

Ghost Mode — the overnight autonomous coding pipeline — has never successfully produced a PR. Despite having the infrastructure (watchdog, screen sessions, Telegram notifications, task decomposition), every autonomous run deadlocks on blocking hooks that wait for human input, loses track of acceptance criteria mid-task due to attention drift, false-triggers budget exhaustion from OTEL noise, and can't restart cleanly after crashes. The result: Caleb dispatches work at bedtime and wakes up to a stuck screen session with zero output.

---

## Proposed Solution

Implement 6 patterns from Manus.ai's production agent architecture (attention anchoring, file-system memory, independent verifier, task isolation) combined with 4 critical infrastructure fixes (headless guards, watchdog hardening, gate bypass, stop hook fix). This transforms Ghost Mode from a concept into a working overnight coding agent that produces PRs while you sleep.

---

## Target Users

**Primary:** Caleb Mambwe — solo developer dispatching overnight coding tasks via Telegram or `/ghost` command

**Secondary:** VPS bot (same pipeline, runs 24/7 on remote server)

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Technical | Must work within Claude Code's hook system and `claude -p` headless mode. No external dependencies beyond what's installed. |
| Timeline | MVP in 1 sprint (6 days). Must show 1+ successful overnight PR before declaring done. |
| Team | 1 engineer (Caleb) + autonomous agents. No manual QA — verification must be automated. |
| Integration | Must preserve existing `/auto-dev` interactive flow. Changes to hooks/commands must not break interactive sessions. |

---

## Scope

### In Scope
- Headless session guards on all blocking hooks (Stop, SDLC artifacts, SubagentStop)
- Ghost watchdog hardening (OTEL=none, budget regex, checkpoint restart, rate-limit grace)
- Autonomous mode gate bypass in `/auto-tasks`
- Attention anchoring via TODO.md re-reads every 10 tool calls
- File-system memory pattern (session state written at 40% context)
- Independent verifier wired into every autonomous pipeline step
- One task per context window enforcement in ghost-run
- Pipeline command consolidation (`/auto-dev` vs `/ghost` clarity)
- Dead hook/script cleanup (7 unwired files)
- Before/after benchmark comparison

### Out of Scope
- Manus.ai API dispatch (pattern replication only, not peer integration)
- Web UI or dashboard
- OpenAI/Gemini integration
- Agent self-modification (propose only, never auto-implement)
- KV-cache prefix optimization (low ROI at current scale)
- Security hardening (separate effort)
- New agent types or team presets

---

## Feature Name

**Kebab-case identifier:** `autonomous-overnight-agent`

**Folder:** `docs/autonomous-overnight-agent/`

---

## Notes

- Extensive research already complete: `docs/autonomous-coding-research/` (6 docs), `docs/self-improvement-engine/08-manus-deep-dive.md`, `docs/autonomous-coding-research/05-recommendations-and-action-plan.md`
- 9 Manus patterns identified, implementing the top 4 (attention anchoring, file-memory, verifier, task isolation)
- Sharp-knife-redesign already addressed CLAUDE.md pruning, hook trimming, skill archiving
- Verifier agent already exists at `agents/core/verifier.md` — needs to be wired in, not created
- Ghost watchdog exists at `hooks/ghost-watchdog.sh` — needs fixes, not a rewrite
- Benchmark suite exists with 15 regression tasks — use for before/after measurement

---

## PR/FAQ: Autonomous Overnight Agent

### Press Release

**LUSAKA, March 2026** — Twendai Software Ltd today announced the Autonomous Overnight Agent, a reliability upgrade to their Claude Code platform that enables solo developers to dispatch complex coding tasks at bedtime and wake up to completed pull requests. Starting immediately after implementation, developers can queue multi-task features via Telegram or terminal and have them built, tested, and PR'd autonomously.

For solo developers building multiple products, nights represent 8 hours of lost productivity. The current Ghost Mode promises overnight coding but delivers stuck sessions — hooks block waiting for human input that never comes, the agent loses track of what it was building halfway through, and crashes leave no recovery path. Every morning starts with "what went wrong this time" instead of "let me review this PR."

"I dispatch a 5-task feature build at 11 PM and by 7 AM there's a PR with all tasks completed, tests passing, and a verifier report," said a developer testing the system. "It's like having a junior dev who works through the night and never gets distracted."

The Autonomous Overnight Agent implements battle-tested patterns from Manus.ai's production agent architecture: attention anchoring (the agent re-reads its goals every 10 steps to prevent drift), file-system memory (state survives context window compaction), independent verification (a separate agent with fresh context reviews every task), and strict task isolation (one context window per task, preventing cross-contamination).

Unlike Devin ($500/mo) or hiring contractors, this runs on existing Claude Code infrastructure with zero additional cost beyond API usage. The patterns are applied as prompt engineering and hook configuration — no new services, no new dependencies, no new accounts.

To get started, run `/ghost "build feature X"` before bed. Check Telegram in the morning for the PR link.

### Frequently Asked Questions

**Customer FAQs:**

**Q: Who is this for?**
A: Solo developers and small teams who use Claude Code and want to ship features overnight without babysitting the agent.

**Q: How is this different from just running `/auto-dev`?**
A: `/auto-dev` has 2 human gates (plan approval, task approval) and assumes you're watching. The overnight agent is fully gate-free, self-recovering, and designed to run for 8 hours without any human input.

**Q: What does it cost?**
A: No additional cost — uses existing Claude Code API credits. A typical overnight session uses $5-15 in API calls depending on task complexity.

**Q: What if it produces bad code?**
A: Every task goes through an independent verifier agent with fresh context. If verification fails twice, the task is marked blocked and skipped — it won't merge garbage. You review the PR in the morning like any other code review.

**Q: When will it be available?**
A: 1 sprint (6 days) from implementation start. First successful overnight PR is the acceptance criterion.

**Internal/Technical FAQs:**

**Q: How long will this take to build?**
A: 3 milestones across ~6 days. Phase 1 (critical fixes, 2 days), Phase 2 (Manus patterns, 2 days), Phase 3 (consolidation + verification, 2 days).

**Q: What are the biggest risks?**
A: (1) Headless guards might miss edge cases where hooks still block — mitigated by testing each hook individually. (2) Attention anchoring adds overhead to every task — mitigated by only re-reading every 10 tool calls, not every call. (3) File-system memory pattern might lose state on unexpected crashes — mitigated by writing state atomically.

**Q: What are we NOT building?**
A: No Manus API integration (pattern replication only). No web dashboard. No new agent types. No self-modifying agents. No KV-cache optimization.

**Q: How will we measure success?**
A: (1) Ghost Mode produces a mergeable PR in 3/3 test runs. (2) Zero deadlocks in overnight sessions. (3) Benchmark pass rate stays >= baseline (no regression). (4) Verifier scores > 80% on produced code.

**Q: What's the rollback plan?**
A: All changes are to markdown command files, shell scripts, and settings.json. Git history preserves everything. The sharp-knife-redesign branch already has a baseline snapshot. Worst case: `git revert` the changes and Ghost Mode is back to its current (non-working) state — no worse than today.
