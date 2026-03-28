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

### Step 2: Run Parallel Review Agents (6 agents, 3 code review gates)

Launch ALL agents in parallel using the Agent tool with `isolation: "worktree"` for file safety and fresh context (~40% usage per agent instead of 80-90%):

**MANDATORY:** Every Agent call in this step MUST include `isolation: "worktree"`. This uses the quality-gate team preset pattern from `config/teams/quality-gate.json`.

Also run the regression gate as part of verification:
```bash
bash scripts/regression-gate.sh --tier 1 --project-dir .
```

**Agent 1: Code Review — Gate A: Correctness (code-reviewer agent, Opus)**
Focus ONLY on whether the code is correct:
- Logic errors, off-by-one, null dereference, unhandled promise rejections
- Missing error handling for failure paths
- Race conditions, deadlocks, data corruption risks
- Wrong algorithm or data structure for the problem
- N+1 queries, missing pagination, unbounded loops
- Incorrect type usage (any casts, unsafe assertions)

Findings format: `[CORRECTNESS-{severity}] {file}:{line} — {description}`

**Agent 2: Code Review — Gate B: Ownership (code-reviewer agent, Opus)**
Focus ONLY on whether a new team member could maintain this code:
- Architecture compliance — does it follow the project's established patterns?
- Naming quality — do variable/function/class names convey intent?
- Dependency direction — does it respect layer boundaries (routes → services → repositories)?
- Duplication — is there copy-paste that should be extracted?
- Test coverage — does new code have corresponding tests?
- Configuration — are magic numbers extracted, are feature flags used where needed?
- Documentation — are complex algorithms or non-obvious decisions explained?

Findings format: `[OWNERSHIP-{severity}] {file}:{line} — {description}`

**Agent 3: Code Review — Gate C: Readability (code-reviewer agent, Sonnet)**
Focus ONLY on whether the code is easy to read and review:
- Function length — is any function doing too much? (> 40 lines = flag)
- Nesting depth — more than 3 levels of nesting = flag
- Control flow clarity — are early returns used? Are conditionals simple?
- Consistency — does it match the style of surrounding code?
- Dead code — unused imports, unreachable branches, commented-out code
- Naming conventions — kebab-case files, camelCase functions, PascalCase types (or project convention)

Findings format: `[READABILITY-{severity}] {file}:{line} — {description}`

**Agent 4: Security (security-auditor agent, Opus)**
- OWASP Top 10 scan on changed files
- Secrets/credentials in code
- Input validation at boundaries
- Dependency vulnerabilities (`pnpm audit` / `pip audit`)

**Agent 5: Test Verification (Sonnet)**
- Run the test suite: `pnpm test` or `pytest`
- Run linting: `pnpm lint` or `ruff check`
- Run typecheck: `pnpm typecheck` or `mypy .`
- Report any failures

**Agent 6: Visual Verification (visual-tester agent, Sonnet)** — only if frontend files in scope
- Run `/visual-verify` to check console errors, network failures, and layout
- Run `/visual-regression` at 3 viewports (mobile 375px, tablet 768px, desktop 1440px)
- Use `visual-tester` agent for interactive UI flow testing on changed pages
- Report visual regressions, broken layouts, and accessibility issues
- Findings format: `[VISUAL-{severity}] {page}@{viewport} — {description}`

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

### Code Review — Gate A: Correctness ({N} findings)
CRITICAL:
- [CORRECTNESS-CRITICAL] {file}:{line} — {finding}
WARNING:
- [CORRECTNESS-WARNING] {file}:{line} — {finding}

### Code Review — Gate B: Ownership ({N} findings)
CRITICAL:
- [OWNERSHIP-CRITICAL] {file}:{line} — {finding}
WARNING:
- [OWNERSHIP-WARNING] {file}:{line} — {finding}

### Code Review — Gate C: Readability ({N} findings)
WARNING:
- [READABILITY-WARNING] {file}:{line} — {finding}
SUGGESTION:
- [READABILITY-SUGGESTION] {file}:{line} — {finding}

### Security: {N} findings
CRITICAL:
- {finding}
HIGH:
- {finding}

### Visual Verification: {N} findings (if frontend files in scope)
CRITICAL:
- [VISUAL-CRITICAL] {page}@{viewport} — {finding}
WARNING:
- [VISUAL-WARNING] {page}@{viewport} — {finding}

### Review Summary
| Gate | Findings | Critical | Blocking? |
|------|----------|----------|-----------|
| A: Correctness | {N} | {N} | {YES/NO} |
| B: Ownership | {N} | {N} | {YES/NO} |
| C: Readability | {N} | {N} | NO (advisory) |
| Security | {N} | {N} | {YES/NO} |
| Visual | {N} | {N} | {YES/NO} |

### Verdict: PASS / FAIL
{FAIL if: any Gate A CRITICAL, any Gate B CRITICAL, any Security CRITICAL, or test failures}
{PASS if: only Gate C findings, warnings, or suggestions remain}
{Gate C findings are advisory — they do not block merge}
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
- ALWAYS run all agents in parallel (not sequentially) — 3 code review gates + security + tests + visual (if frontend)
- Agent 6 (Visual) only launches if changed files include .tsx/.jsx/.css/.html or files in components/pages/app directories
- ALWAYS run tests — don't skip even if "just a small change"
- Gate A (Correctness) CRITICAL = must fix before merge — these are bugs
- Gate B (Ownership) CRITICAL = must fix before merge — these create maintenance debt
- Gate C (Readability) findings are advisory — they NEVER block merge, but should be addressed
- Security CRITICAL = must fix before merge
- WARNING findings across all gates = should fix, not blocking
- If verdict is PASS: "Ready for PR. Run /ship to create it."
- If verdict is FAIL: list exactly what needs fixing, organized by gate
- Report any new TODO/FIXME tags as non-blocking warnings (visible in Todo Tree sidebar)
- Each gate's agent MUST stay focused on its scope — a Correctness agent should not flag readability issues
