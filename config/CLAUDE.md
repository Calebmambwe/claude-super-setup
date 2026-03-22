# Global Development Preferences

## Philosophy
- Spec-first: /spec for features >3 files, /full-pipeline for major features
- Contract-driven: OpenAPI 3.1 spec is the single source of truth for APIs
- Library-first: ALWAYS use Context7 MCP for any library/framework question
- Test-driven: write tests alongside implementation, not after
- Anti-abstraction: don't create abstractions until a pattern repeats 3+ times
- Explicit over implicit in all code

## Workflow (Non-Negotiable)
- ALWAYS: Explore > Plan > Implement > Verify for any multi-file change
- Use Plan Mode (Shift+Tab x2) before any task spanning 3+ files
- Branch per task, conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `ci:`
- Use /clear between unrelated tasks, /compact at ~65% context
- Run /reflect at session end to capture learnings

## Two-Correction Rule
If corrected twice on the same issue, STOP. Re-read the full spec/requirements from scratch.

## Verification Commands
After EVERY implementation task, run ALL applicable checks:
```
pnpm test && pnpm lint && pnpm typecheck    # TypeScript projects
pytest && ruff check && mypy .               # Python projects
```
NEVER declare a task complete without running tests.

## Unified Workflow
```
# Manual: /plan -> /build -> /check -> /ship -> /reflect
# Semi-auto: /dev <feature>
# Fully autonomous: /auto-dev <feature>
```

## Common Gotchas
- [critical] NEVER use `any` type in TypeScript. Use `unknown` + type guard.
- [critical] ALWAYS validate input at system boundaries with Zod/Pydantic.
- [critical] NEVER commit .env files. Check .gitignore includes `.env*`.
- [pattern] When debugging failing tests, read the test file FIRST, then the implementation.

## Model Strategy
- Default: Opus for planning, Sonnet for execution
- Subagent model: Sonnet via CLAUDE_CODE_SUBAGENT_MODEL
- Agent teams enabled via CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
