---
name: ship
description: Commit changes and create a PR — the last step before merge
---
Ship the current work: $ARGUMENTS

## What This Does

This is the ONE command for committing and creating PRs. It replaces manually running git commands and `/pr`.

## Process

### Step 1: Check State
```bash
git status
git diff --stat
git log --oneline -5
```

- If no changes: "Nothing to ship. Write some code first."
- If on main/master: "Create a feature branch first: `git checkout -b feature/{name}`"

### Step 2: Stage and Commit (if uncommitted changes exist)

- Review all changed files
- Stage relevant files (NOT .env, secrets, or build artifacts)
- Create conventional commit(s):
  - Group related changes into logical commits
  - Use proper prefixes: feat:, fix:, test:, refactor:, docs:
  - Descriptive messages explaining WHY, not just WHAT

### Step 3: Push and Create PR

- Push branch to remote: `git push -u origin HEAD`
- Create PR using `gh pr create`:
  - Title: short, under 70 characters
  - Body: summary bullets, test plan, any notes for reviewers
  - Add labels if applicable

### Step 4: Report

```
## Shipped!

Branch: {branch-name}
Commits: {N}
PR: {url}

VS Code sidebar:
- GitHub PRs: see your PR, add reviewers, track status
- GitHub Actions: watch CI run live, re-run if needed
- GitLens: compare your branch against main

The PR is ready for human review.
```

## VS Code Integration

### GitHub PRs in Sidebar
After `/ship` creates the PR, it appears immediately in the VS Code sidebar under `GitHub > Pull Requests > Created By Me`. The user can:
- Add reviewers and labels from the sidebar
- See review comments inline in the editor
- Respond to review feedback without leaving VS Code
- Merge the PR from the sidebar once approved

### GitHub Actions in Sidebar
The CI workflow triggered by the push shows under `GitHub > Actions`:
- Live status (running/passed/failed)
- Click to view logs for any job
- Re-run failed jobs with one click
- No need to open browser for CI status

### GitLens Post-Ship
GitLens shows the full branch diff in the Source Control sidebar. Useful for a final sanity check after shipping.

## Rules
- NEVER push to main/master (branch guard will block it anyway)
- NEVER commit .env files, secrets, or credentials
- ALWAYS use conventional commit format
- If /check hasn't been run yet, warn: "Consider running /check first for automated review."
- If tests haven't been run, warn: "Tests haven't been verified. Run /check or test manually."
- After creating the PR, remind the user: "Check GitHub Actions in VS Code sidebar for CI status."
