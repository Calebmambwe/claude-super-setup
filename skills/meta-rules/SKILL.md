---
name: meta-rules
description: "How to update CLAUDE.md — rules for writing actionable, non-duplicate learnings"
invoked_by:
  - /meta-rules
---

# Meta-Rules: How to Update CLAUDE.md

## Rules
- Each rule must be ONE sentence, actionable, with a concrete example
- Format: "ALWAYS/NEVER do X because Y. Example: ..."
- Before adding: check if a similar rule exists — update it instead of duplicating
- Categorize: [critical] = broke production, [pattern] = repeated 2+ times, [preference] = style choice
- After fixing a bug that took 3+ iterations: add a learning
- After a correction from the user: add a learning
- Never add vague rules like "be careful with X" — specify exactly what to do/not do
- When a learning applies 2+ times, promote it to the Critical section
- Keep total learnings under 50 entries — consolidate related items

## Examples
```markdown
# Good rule:
- [critical] ALWAYS use parameterized queries because string interpolation causes SQL injection. Example: `db.query('SELECT * FROM users WHERE id = $1', [id])`

# Bad rule:
- Be careful with database queries
```

## Anti-Patterns
- Adding duplicate rules — search existing rules first
- Vague rules without examples — every rule needs a concrete "do this"
- Unbounded growth — consolidate related items, keep under 50 entries
