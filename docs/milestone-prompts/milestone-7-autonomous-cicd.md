# Milestone 7: Autonomous CI/CD

## Section 1: Task Summary

**What:** Create the `improve.yml` GitHub Actions workflow that uses `anthropics/claude-code-action` to autonomously analyze the setup weekly and propose improvements as pull requests.

**In scope:**
- `.github/workflows/improve.yml` with weekly cron schedule + manual dispatch
- Claude Code Action configuration with focused improvement prompt
- Drift detection script (`scripts/drift-detect.sh`) for local use
- PR template for improvement proposals
- Rate limiting / guardrails to prevent excessive PRs

**Out of scope:**
- Agent health check automation (deferred to v2)
- Auto-merge of improvement PRs (always require human review)
- Cost monitoring / budget caps for the improvement workflow

**Definition of done:**
- [ ] `improve.yml` deployed and functional
- [ ] Manual workflow_dispatch trigger produces a valid improvement PR
- [ ] Weekly cron schedule configured (Monday 9am UTC)
- [ ] Claude Code Action has appropriate tool restrictions (read-heavy, limited writes)
- [ ] `scripts/drift-detect.sh` compares local `~/.claude/` against repo HEAD
- [ ] Guardrail: max 1 improvement PR per week (skip if open PR exists)
- [ ] PR body includes analysis summary, proposed changes, and confidence level

## Section 2: Project Background

**Innovation:** No competing Claude Code setup has autonomous CI/CD. This is a first-in-market feature. The `improve.yml` workflow makes the configuration self-improving — Claude analyzes the setup weekly and proposes enhancements.

**Workflow engine:** `anthropics/claude-code-action@v1` — Anthropic's official GitHub Action for running Claude Code in CI. Requires `ANTHROPIC_API_KEY` secret.

**Guardrails philosophy:** Improvement PRs are PROPOSALS, never auto-merged. Human review is mandatory. The workflow should be conservative — only propose changes it's confident about.

## Section 3: Current Task Context

M1 and M2 complete. Parallel with M3, M4, M5, M6. The CI and release workflows from M1 are already in place.

## Section 4: Design Document Reference

See `docs/design/design-document.md`:
- Section 2.3: CI/CD pipeline architecture diagram (improve.yml section)
- Section 4.3: Autonomous improvement pipeline specification

## Section 5: Pre-Implementation Exploration

Before implementing:
1. Read `docs/design/design-document.md` Section 2.3 and 4.3
2. Read the existing `.github/workflows/ci.yml` and `release.yml` for workflow conventions
3. Fetch docs for `anthropics/claude-code-action` via Context7 or web — understand inputs, outputs, permissions
4. Review existing improvement prompt in design doc Section 4.3
5. Check GitHub Actions cron schedule syntax

## Section 6: Implementation Instructions

### Architecture constraints
- Claude Code Action MUST have restricted tool access — primarily read tools
- Write access limited to: agent files, stack templates, catalog.json, rules
- NEVER allow: settings.json modification, hook modification, command modification (too risky for autonomous)
- Always create a new branch for proposals — never commit to main
- Include skip logic: if an open improvement PR already exists, skip the run

### Ordered build list

**Step 1: Create improve.yml**

```yaml
name: Weekly Improvement Proposals
on:
  schedule:
    - cron: '0 9 * * 1'    # Monday 9am UTC
  workflow_dispatch:         # Manual trigger for testing

permissions:
  contents: write
  pull-requests: write

jobs:
  check-existing-pr:
    runs-on: ubuntu-latest
    outputs:
      has_open_pr: ${{ steps.check.outputs.has_open_pr }}
    steps:
      - id: check
        run: |
          OPEN_PRS=$(gh pr list --label "autonomous-improvement" --state open --json number | jq length)
          echo "has_open_pr=$([[ $OPEN_PRS -gt 0 ]] && echo true || echo false)" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  propose-improvements:
    needs: check-existing-pr
    if: needs.check-existing-pr.outputs.has_open_pr != 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            [improvement analysis prompt - see below]
          allowed_tools: "Read,Grep,Glob,Bash(jq *),Bash(wc *),Bash(find *),Write,Edit"
          max_turns: 30
```

**Step 2: Write the improvement analysis prompt**

The prompt should instruct Claude to:
1. **Agent catalog audit:** Check catalog.json for agents missing capability tags, wrong model tiers, or gaps in language/domain coverage
2. **Template freshness:** Check each stack template's framework versions against latest stable releases
3. **Rule coverage gaps:** For each framework in templates, verify a corresponding rule exists
4. **Hook optimization:** Review hooks for error handling improvements or performance issues
5. **Documentation accuracy:** Check CLAUDE.md references match actual file structure

Output format: Create a single PR with all changes. PR body must include:
- Analysis summary (what was checked)
- Proposed changes (what is being modified and why)
- Confidence level (High/Medium/Low per change)
- Potential risks

**Step 3: Create PR labels**
Add `autonomous-improvement` label to the repo (used for skip logic).

**Step 4: Create drift-detect.sh**

```bash
#!/usr/bin/env bash
# Compare local ~/.claude/ against repo HEAD
# Identifies files modified locally but not committed

REPO_DIR="$HOME/.claude-super-setup"
CLAUDE_DIR="$HOME/.claude"

# For each symlinked directory, check if target matches repo
for module in commands agents hooks rules skills agent_docs; do
  # Compare file contents between symlink target and repo
  diff -rq "$CLAUDE_DIR/$module" "$REPO_DIR/$module" 2>/dev/null | head -20
done
```

**Step 5: Test with manual dispatch**
- Push the workflow
- Trigger via `workflow_dispatch`
- Verify PR is created with sensible improvements
- Verify skip logic works (trigger again, should skip)

### Git workflow
- Branch: `feature/autonomous-cicd`
- Commit: `feat: add weekly autonomous improvement workflow with Claude Code Action`

## Section 7: Final Reminders

- Claude Code Action requires `ANTHROPIC_API_KEY` as a GitHub Secret — document this in README
- The improvement workflow MUST NOT modify hooks or settings.json autonomously — too risky
- Always require human review — never auto-merge improvement PRs
- Test the skip logic: if an improvement PR is already open, don't create another
- The improvement prompt should be conservative — only propose changes with high confidence
- Include a `workflow_dispatch` trigger for manual testing (don't wait a week to test)
- Pin `anthropics/claude-code-action` to a specific version tag, not `@latest`
