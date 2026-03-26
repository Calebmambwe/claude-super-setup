---
name: learning-dashboard
description: Display the learning ledger dashboard with trends, top learnings, and promotion candidates
---
Show the learning ledger dashboard — trends, top learnings, and promotion candidates.

## Steps

1. **Ledger overview** — call `get_learning_stats` and display:
   - Total learnings, with embeddings, promotion eligible, total promotions
   - Breakdown by status (active / pending / promoted / archived)
   - Breakdown by type (correction / success / pattern / preference)

2. **Top learnings** (most reinforced) — search the ledger for recently active learnings:
   ```
   python3 ~/.claude/skills/reflect/scripts/learning_ledger.py search ""
   ```
   Sort by `count` descending. Show the top 5 with their reinforcement count and confidence.

3. **Promotion candidates** — run:
   ```
   python3 ~/.claude/skills/reflect/scripts/learning_ledger.py candidates
   ```
   List each with fingerprint, content preview, repo count.

4. **Session metrics trend** — read `~/.claude/metrics.jsonl` if it exists.
   Extract the `learning_metrics` field from each entry.
   Show a table: date | corrections | applied | rework_rate
   If fewer than 3 sessions have metrics, note "Not enough data yet."

5. **Corrections/session trend** — from metrics.jsonl, compute average corrections per session
   over the last 10 sessions vs the 10 before that. Show if the rate is improving (decreasing).

6. **Pending review queue** — count learnings with `status = 'pending'`.
   If > 0, suggest: "Run `/consolidate` to review {N} pending learnings."

7. **Consolidation status** — check `~/.claude/reflect/last-consolidation.timestamp`.
   Show when consolidation was last run and whether it's overdue (> 7 days).

## Example output format

```
═══════════════════════════════════════
  Learning Ledger Dashboard
  2026-03-12
═══════════════════════════════════════

OVERVIEW
  Total learnings:      42
  Active:               28 | Pending: 8 | Promoted: 4 | Archived: 2
  Promotion eligible:   3
  With embeddings:      15

BY TYPE
  correction:  24 | success: 10 | pattern: 6 | preference: 2

TOP 5 LEARNINGS (by reinforcement)
  [a1b2c3d4] Always use pnpm not npm  ×7  conf=0.92
  [e5f6g7h8] Never use `any` type     ×5  conf=0.90
  ...

PROMOTION CANDIDATES
  [x1y2z3w4] (3 repos) Use Zod for input validation
  ...

TRENDS (last 10 sessions)
  Corrections/session: 2.1 ↓ (was 3.4) — improving!
  Rework rate:         8%  ↓ (was 15%)

CONSOLIDATION
  Last run: 5 days ago
  Next due: in 2 days
```
