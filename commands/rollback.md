---
name: rollback
description: Revert a merged PR and reopen affected tasks
---

Rollback: $ARGUMENTS

## What This Does

Safely reverts a merged PR by creating a revert commit, opening a revert PR, and
reopening affected tasks in tasks.json for rework.

## Process

### Step 1: Identify the PR

If $ARGUMENTS is a PR number (e.g., `42` or `#42`):
- Fetch PR details: `gh pr view {number} --json title,mergeCommit,state,headRefName`
- Verify the PR is merged — if not: "PR #{number} is not merged. Nothing to revert."

If $ARGUMENTS is a commit SHA:
- Find the associated PR: `gh pr list --search {sha} --state merged --json number,title`

If $ARGUMENTS is empty:
- Show recent merged PRs: `gh pr list --state merged --limit 5 --json number,title,mergedAt`
- Ask user which one to revert

### Step 2: Safety Checks

1. **Verify you're not on main/master** — if so, create a revert branch: `revert/pr-{number}`
2. **Check for uncommitted changes** — stash or abort if found
3. **Confirm with user:**
   ```
   ## Rollback Plan

   Reverting: PR #{number} — {title}
   Merge commit: {sha}
   Branch: revert/pr-{number}

   This will create a revert commit and open a new PR.
   Proceed? [yes / abort]
   ```

### Step 3: Create Revert

```bash
git checkout -b revert/pr-{number}
git revert {merge-commit-sha} --no-edit
```

If the revert has conflicts:
- Report the conflicting files
- Attempt auto-resolution for simple conflicts
- If complex conflicts: "Revert has conflicts in {files}. Resolve manually, then run `/ship`."

### Step 4: Reopen Tasks

If `tasks.json` exists:
- Find tasks that were completed by the reverted PR (match by file overlap with PR diff)
- Set their status back to `"pending"`
- Reset `attempts` to 0
- Add note: `"reverted_from": "PR #{number}"`
- Report which tasks were reopened

### Step 5: Ship the Revert

Run `/ship` to:
- Push the revert branch
- Create a revert PR with title: `revert: PR #{number} — {original title}`
- PR body includes: reason for revert, list of reopened tasks, original PR link

### Report

```
## Rollback Complete

Reverted: PR #{number} — {title}
Revert PR: #{revert-pr-number}
Tasks reopened: {list of task IDs, or "none (no tasks.json)"}

Next:
- Review and merge the revert PR
- Fix the issues that caused the rollback
- Run /auto-build-all to re-implement reopened tasks
```

## Rules

- ALWAYS confirm with user before reverting
- ALWAYS create a separate revert branch — never revert on main
- ALWAYS create a revert PR — never push directly to main
- If tasks.json exists, reopen affected tasks automatically
- If the revert has complex conflicts, stop and ask for help
- Never force-push — use a clean revert commit
