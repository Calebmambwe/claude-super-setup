---
name: check
description: Unified quality gate — runs code review, security audit, and test verification in parallel
---
Run all quality checks on current changes: $ARGUMENTS

## What This Does

This is the ONE command you run before merging. It replaces `/code-review`, `/security-check`, `/security-audit`, and `/review`.

## Process

### Step 1: Determine Scope
- If $ARGUMENTS provided, focus on those files/paths
- If on a feature branch: `git diff main...HEAD` for all branch changes
- If no branch: `git diff --staged` for staged changes, or `git diff` for unstaged
- If nothing changed: "No changes to review. Commit or stage changes first."

### Step 2: Run Parallel Review Agents

Launch ALL three agents in parallel using the Agent tool:

**Agent 1: Code Quality (code-reviewer agent, Opus)**
- Correctness, architecture compliance, naming, duplication
- Test coverage for new code
- Error handling completeness
- Performance concerns (N+1 queries, missing pagination)

**Agent 2: Security (security-auditor agent, Opus)**
- OWASP Top 10 scan on changed files
- Secrets/credentials in code
- Input validation at boundaries
- Dependency vulnerabilities (`pnpm audit` / `pip audit`)

**Agent 3: Test Verification (Sonnet)**
- Run the test suite: `pnpm test` or `pytest`
- Run linting: `pnpm lint` or `ruff check`
- Run typecheck: `pnpm typecheck` or `mypy .`
- Report any failures

### Step 3: Compile Results

Merge all findings into a single report:

```
## Quality Gate Report

### Test Suite: PASS / FAIL
{test output summary}

### Lint: PASS / FAIL
{lint output summary}

### Typecheck: PASS / FAIL
{typecheck output summary}

### Code Review: {N} findings
CRITICAL:
- {finding}
WARNING:
- {finding}

### Security: {N} findings
CRITICAL:
- {finding}
HIGH:
- {finding}

### Verdict: PASS / FAIL
{If any CRITICAL findings or test failures: FAIL with action items}
{If only warnings/suggestions: PASS with recommendations}
```

## VS Code Integration

### Error Lens + Problems Panel
After `/check` runs, all findings are visible in VS Code:
- **Error Lens** highlights errors inline on every affected line
- **Problems panel** (`Ctrl+Shift+M`) lists all TypeScript/ESLint issues
- **mcp__ide__getDiagnostics** — if the Claude Code VS Code extension is active, Claude reads the Problems panel directly and can auto-fix remaining issues

### Playwright Test Explorer
For E2E test failures, the `ms-playwright.playwright` extension shows:
- Failing tests in the Testing sidebar with one-click re-run
- Trace viewer for step-by-step replay of failed flows
- Point-and-click locator generation for fixing selectors

### GitLens Branch Compare
Before declaring PASS, suggest the user verify changes visually:
- GitLens > "Compare Branch" shows full diff against main
- File-by-file change review with inline annotations
- Timeline view shows progression of changes during `/build`

### Todo Tree
After code review, any TODO/FIXME/HACK tags found in new code appear in the Todo Tree sidebar. Report these as non-blocking warnings.

## Rules
- ALWAYS run all three agents in parallel (not sequentially)
- ALWAYS run tests — don't skip even if "just a small change"
- CRITICAL findings = must fix before merge
- WARNING findings = should fix, not blocking
- If verdict is PASS: "Ready for PR. Run /ship to create it."
- If verdict is FAIL: list exactly what needs fixing
- Report any new TODO/FIXME tags as non-blocking warnings (visible in Todo Tree sidebar)
