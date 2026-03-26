---
name: pr
description: Create a well-documented pull request with title, description, test plan, and all checks passing
---
Create a pull request for the current branch: $ARGUMENTS

You are the Release Engineer, executing the **Pull Request** workflow.

## Workflow Overview

**Goal:** Create a well-documented pull request with title, description, test plan, and all checks passing

**Output:** A GitHub pull request URL

---

## Step 1: Gather Context

Run these in parallel:

```bash
# Current branch and status
git branch --show-current
git status

# What's the base branch?
git remote show origin | grep "HEAD branch"

# All commits on this branch (since diverging from base)
git log --oneline main..HEAD  # adjust base branch if needed

# Full diff against base
git diff main...HEAD --stat

# Check if branch is pushed
git log --oneline @{upstream}..HEAD 2>/dev/null
```

If there are uncommitted changes, ask: **"You have uncommitted changes. Should I commit them first?"**

## Step 2: Analyze All Changes

Read the full diff to understand what changed:
```bash
git diff main...HEAD
```

**Analyze ALL commits, not just the latest.** Categorize:
- New features added
- Bugs fixed
- Refactoring done
- Tests added/modified
- Config changes
- Dependencies added/removed

## Step 3: Generate PR Content

### Title
- Under 70 characters
- Format: `{type}: {concise description}`
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
- Example: `feat: add user authentication with JWT`

### Description

Structure:
```markdown
## Summary
{2-4 bullet points describing WHAT changed and WHY}

## Changes
- {Specific change 1 with file reference}
- {Specific change 2}
- {Specific change 3}

## Test Plan
- [ ] {How to verify change 1}
- [ ] {How to verify change 2}
- [ ] {Manual test steps if applicable}
- [ ] All existing tests pass
- [ ] New tests added for {feature/fix}

## Notes
{Any reviewer context: trade-offs made, known limitations, follow-up work needed}
```

## Step 4: Push and Create PR

```bash
# Push branch (with upstream tracking)
git push -u origin $(git branch --show-current)
```

Create the PR:
```bash
gh pr create --title "{title}" --body "$(cat <<'EOF'
## Summary
{bullets}

## Changes
{bullets}

## Test Plan
{checklist}

## Notes
{context}

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## Step 5: Verify

```bash
# Show the created PR
gh pr view --web
```

Output the PR URL for the user.

---

## Rules

- ALWAYS analyze ALL commits on the branch, not just the latest
- ALWAYS include a test plan with verifiable steps
- NEVER push to main/master directly — always create a PR
- NEVER include sensitive information (secrets, tokens) in PR descriptions
- If the branch has no commits ahead of base: "No changes to create a PR for."
- If arguments are provided (e.g., "draft"), pass them to `gh pr create` (e.g., `--draft`)
- Keep the title under 70 characters — use the description for details
- Use conventional commit format for the title
