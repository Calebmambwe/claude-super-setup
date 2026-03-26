---
name: auto-fix-review
description: Review code and auto-generate fixes for every finding — BugBot-style automated PR improvement
---

Auto-fix code review: $ARGUMENTS

## Process

### Step 1: Run Code Review

Launch the code-reviewer agent (Opus) to analyze current changes:
- `git diff main...HEAD` for all changes on the current branch
- If no branch diff, review all staged + unstaged changes

Run all three checks in parallel:
1. **Code review** — logic, patterns, naming, complexity, missing error handling, type safety
2. **Security audit** — injection risks, auth gaps, secrets in code, unsafe deserialization
3. **Test/lint/typecheck** — run applicable suite: `pnpm test && pnpm lint && pnpm typecheck` (TS) or `pytest && ruff check && mypy .` (Python)

Collect all findings into a single list before proceeding.

### Step 2: Categorize Findings

For each finding, classify into one of two buckets:

**Auto-fixable** (safe to apply programmatically):
- Lint errors and formatting violations
- Unused imports and dead variables
- Missing null/undefined checks where the fix is obvious
- Missing `await` on async calls
- Simple type annotation gaps (add `: string`, `: number`, etc.)
- Missing error handling on try/catch blocks where the pattern is clear
- Hardcoded values that should be constants
- Console.log statements left in production code
- Missing return type annotations
- Obvious off-by-one errors in loops

**Manual review needed** (require human judgment):
- Architecture concerns and structural design decisions
- Logic errors where intent is ambiguous
- Security vulnerabilities that require a design decision (e.g., auth model changes, SQL injection requiring query restructure)
- Breaking API changes
- Performance issues requiring algorithm changes
- Business logic bugs where the correct behavior is unclear
- Race conditions and concurrency issues
- Any finding where the fix could have unintended side effects across the codebase

### Step 3: Auto-Fix

For each auto-fixable finding, execute this loop:

1. Read the relevant file at the exact line number flagged
2. Apply the minimal fix — change only what is needed, nothing more
3. Verify the fix compiles/parses (run `tsc --noEmit` for TS, `python -m py_compile` for Python)
4. Run the applicable test suite for the affected module
5. **If tests pass:** commit with `fix: {description}` (conventional commit, imperative mood, under 72 chars)
6. **If tests fail:** revert the change with `git checkout -- {file}` and reclassify as "manual review needed" with a note explaining why the fix failed

Each fix is committed independently so it can be reverted in isolation.

### Step 4: Report

After all fixes are attempted, display a structured report:

```
## Auto-Fix Review Report

| # | Finding | File | Severity | Status | Commit |
|---|---------|------|----------|--------|--------|
| 1 | Missing null check in user lookup | auth.ts:42 | High | AUTO-FIXED | abc1234 |
| 2 | SQL injection risk in search query | query.ts:15 | Critical | MANUAL | Needs query redesign |
| 3 | Unused import: lodash | utils.ts:3 | Low | AUTO-FIXED | def5678 |
| 4 | Missing await on db.save() | posts.ts:88 | High | AUTO-FIXED | ghi9012 |
| 5 | Race condition in cache write | cache.ts:21 | Medium | MANUAL | Requires locking strategy |

Summary: Found {total} issues — Auto-fixed {fixed} | Manual review needed: {manual}
```

For each MANUAL item, include a brief explanation of WHY it cannot be auto-fixed and what the human reviewer needs to decide.

## Rules

- NEVER auto-fix security vulnerabilities that require design decisions — flag them as MANUAL with full context
- NEVER auto-fix breaking API changes — surface them as MANUAL with migration notes
- NEVER batch multiple fixes into one commit — one finding, one commit, always
- NEVER apply a fix that touches more than 10 lines — escalate to MANUAL if the fix is that large
- NEVER skip running tests after each fix — a fix that breaks tests is worse than the original issue
- ALWAYS revert a fix that fails tests and reclassify it as MANUAL
- ALWAYS use conventional commits: `fix: {description}` in imperative mood
- ALWAYS run the full applicable test suite, not just unit tests for the changed file
- If $ARGUMENTS specifies a file or directory, scope the review to that path only
- If $ARGUMENTS is empty, review the full branch diff against main
