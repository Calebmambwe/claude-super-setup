---
name: reflect
description: Reflect on the current session and capture corrections, patterns, and successes to the learning ledger
---
Reflect on this session and capture learnings.

1. Review what happened in this session:
   - What corrections did the user make?
   - What took multiple attempts to get right?
   - What patterns caused bugs or errors?
   - What worked well that should be repeated?

2. For each finding, determine:
   - Is this project-specific or universal?
   - Does a similar rule already exist in docs/learnings.md or CLAUDE.md?
   - What's the severity? [critical] [pattern] [preference]

3. Write learnings following the Meta-Rules:
   - ONE sentence per learning, with a concrete example
   - Add to docs/learnings.md under "Recent Learnings"
   - If this is the 2nd+ time: promote to "Critical (Always Apply)"
   - If it's universal: also add to CLAUDE.md

4. Check if any skill files should be updated:
   - backend-architecture skill: new anti-patterns discovered?
   - design-system skill: new visual rules discovered?
   - If a new category of learnings is emerging: suggest creating a new skill

5. Log session metrics to ~/.claude/metrics.jsonl:
   - Estimate phase durations from conversation flow
   - Count agents used, worktrees created, rework iterations
   - Estimate model cost and human review time
   - Append a JSONL entry (see /metrics for schema)
   - Set outcome: merged, in_progress, abandoned, or blocked

6. Show me the diff of what was added/changed and the metrics logged for review.

7. **Learning metrics** — compute and append to the metrics.jsonl entry:
   - `corrections_this_session`: count of times user corrected Claude (look for "no,", "actually,", "instead of", "never", "always" patterns in the conversation)
   - `learnings_applied`: count of times `search_learnings` or `get_project_learnings` MCP tools were called and returned results that were acted on
   - `rework_count`: count of times a tool call was immediately followed by another tool call undoing the previous one (e.g., write then edit the same file within 2 turns)
   - `learning_metrics`: `{"corrections": N, "applied": N, "rework": N}`

   Append the learning_metrics to the existing JSONL line for this session.
   Example entry addition:
   ```json
   {"session_id": "...", ..., "learning_metrics": {"corrections": 2, "applied": 3, "rework": 1}}
   ```
