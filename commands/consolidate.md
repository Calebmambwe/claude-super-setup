Weekly learning cleanup and promotion.

Run this to deduplicate, archive stale, and promote eligible learnings.

## Steps

1. **Load all learnings** from the ledger via `get_learning_stats` to see the current state.

2. **Archive stale learnings** — call:
   ```
   python3 ~/.claude/skills/reflect/scripts/learning_ledger.py archive --days 90
   ```
   Report how many were archived.

3. **Find promotion candidates** — use `search_learnings` with an empty query to get recent learnings, then call `get_learning_stats` to see `promotion_eligible` count.
   Also run:
   ```
   python3 ~/.claude/skills/reflect/scripts/learning_ledger.py candidates
   ```

4. **For each promotion candidate** (up to 5):
   - Show the learning content to the user
   - Ask: "Promote to CLAUDE.md? (yes/no/skip)"
   - If yes: call `promote_learning` with the fingerprint
   - If no: skip
   - If user says "promote all": promote all candidates without asking per-item

5. **Update the consolidation timestamp**:
   ```bash
   date +%s > ~/.claude/reflect/last-consolidation.timestamp
   ```

6. **Show summary report**:
   - Learnings before consolidation: N
   - Archived: N
   - Promoted: N
   - Remaining active: N
   - Next consolidation: in 7 days

## Notes

- Consolidation is safe to run multiple times — dedup is fingerprint-based
- Promotions are appended to `~/.claude/CLAUDE.md` — review after running
- Backups of CLAUDE.md are saved to `~/.claude/backups/`
