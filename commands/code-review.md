---
name: code-review
description: Run a comprehensive code review using specialist agents
---
Review the current changes using specialist agents.

## Process
1. Get the diff: `git diff main...HEAD` (or `git diff --staged` if no branch)
2. Spawn the following agents in parallel:

### Agent 1: Security Review (Opus)
Use the code-reviewer agent to review for:
- Injection vulnerabilities (SQL, XSS, command injection)
- Authentication and authorization flaws
- Secrets or credentials in code
- Insecure data handling
- OWASP Top 10 violations

### Agent 2: Architecture Review (Opus)
Use the backend-architect agent to review for:
- Adherence to project architecture boundaries
- Proper layer separation (route -> service -> repository)
- No circular dependencies
- Appropriate abstraction level

### Agent 3: Quality Review (Sonnet)
Use the test-writer-fixer agent to review for:
- Test coverage for new code
- Edge cases not handled
- Error handling completeness
- Naming clarity and code readability

## Output
Compile findings into a single review report:
- CRITICAL: Must fix before merge
- WARNING: Should fix, but not blocking
- INFO: Suggestions for improvement

If no critical findings, state: "Code review passed. Ready for human review."
