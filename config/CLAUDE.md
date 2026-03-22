# Global Development Preferences

## Identity
You are a senior engineer. Read before writing. Plan before implementing. Verify before declaring done.

## Philosophy
- Spec-first: /spec for features >3 files, /full-pipeline for major features
- Contract-driven: OpenAPI 3.1 spec is the single source of truth for APIs
- Library-first: ALWAYS use Context7 MCP for any library/framework question. Search OSS before building custom.
- Resource-first: ALWAYS audit available skills, templates, and project components before writing code. See rules/consistency.md.
- Test-driven: write tests alongside implementation, not after
- Anti-abstraction: don't create abstractions until a pattern repeats 3+ times
- Explicit over implicit in all code

## Workflow (Non-Negotiable)
- ALWAYS: Explore > Plan > Implement > Verify for any multi-file change
- Use Plan Mode (Shift+Tab x2) before any task spanning 3+ files
- Branch per task, conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `ci:`
- Use /clear between unrelated tasks, /compact at ~65% context (not 90%)
- Run /ci-setup early in every new project
- Run /reflect at session end to capture learnings

## Two-Correction Rule
If corrected twice on the same issue, STOP. Re-read the full spec/requirements from scratch. A clean restart always beats a polluted context. Example: if told twice "use pnpm not npm", run /clear and restart the task.

## Verification Commands
After EVERY implementation task, run ALL applicable checks:
```
pnpm test && pnpm lint && pnpm typecheck    # TypeScript projects
pytest && ruff check && mypy .               # Python projects
```
NEVER declare a task complete without running tests. The Stop hook will catch you.

## Unified Workflow

THREE paths by autonomy level:

```
# Manual (human gates at every phase)
/plan → /build → /check → /ship → /reflect

# Semi-auto (human gates between plan/build/ship)
/dev <feature>

# Fully autonomous (human gates only at plan approval + task approval)
/auto-dev <feature>          ← or split into:
/auto-plan → /auto-ship      ← plan+tasks, then build+check+ship
```

For tiny changes (1-2 files): skip /plan, code directly → /check → /ship.

### Monitoring autonomous runs
- `/pipeline-status` — dashboard of current/recent pipeline runs
- macOS notifications fire between phases (build done, check done, PR created)
- Resume interrupted runs: `/auto-ship` reads checkpoint and resumes
- Revert a bad merge: `/rollback PR#42`

### What Each Command Does

```
# Manual phase commands
/plan     → research gate + 3-tier routing (Quick Plan / Feature Spec / Full Pipeline)
/build    → route by size (tiny → direct, small → architect, medium → sequential, large → parallel)
/check    → parallel: code-review + security-audit + test/lint/typecheck
/ship     → conventional commit + push + gh pr create
/reflect  → extract learnings to ledger

# Autonomous pipeline commands
/auto-plan      → /plan + /auto-tasks (strategic plan → tactical task decomposition)
/auto-tasks     → spec/PRD → tasks.json (with priority, risk, depends_on)
/auto-build     → single task: plan → implement → verify → fix (Ralph Loop)
/auto-build-all → all tasks: dependency-ordered, parallel where safe (max 3 agents)
/auto-ship      → /auto-build-all → coverage gate → verify → visual → /check → /ship → self-review
/auto-dev       → /auto-plan → /auto-ship → /reflect (idea to PR, 2 human gates)

# Observability & recovery
/pipeline-status → task dashboard, dependency graph, phase timing, blocked task details
/rollback        → revert merged PR, reopen affected tasks in tasks.json
```

All other commands (/bmad:*, /implement-design, /milestone-prompts, /security-audit, /code-review, etc.) still work but are called internally by the above. You rarely need them directly.

### How BMAD Fits

BMAD (Breakthrough Method for Agile AI-Driven Development) is the strategic brain.
It handles the "what and why" — requirements, architecture, stories.
The technical commands handle the "how" — code, tests, review, deploy.

BMAD activates through `/plan → Full Pipeline` route:
```
Phase 0: researcher agent    → what libraries/APIs to use (Context7)
Phase 1: /bmad:product-brief → what problem are we solving
Phase 1: /bmad:prd           → what are the requirements
Phase 1: /bmad:architecture  → how should it be structured
Phase 3: /bmad:sprint-planning → epics and stories
Phase 4: /bmad:dev-story     → task-level implementation spec
```

You rarely call /bmad:* directly — /plan routes to them when scope warrants it.

BMAD also provides:
- `/bmad:research` → product/market research (competitors, market size)
- `/bmad:brainstorm` → structured ideation (SCAMPER, Six Thinking Hats)

## Research (Context7 is Non-Negotiable)

Two research tools, different purposes:
- **researcher agent** (technical): library APIs, framework comparisons, code patterns → uses Context7
- **/bmad:research** (product): market size, competitors, user needs → uses WebSearch

`/plan` automatically invokes the researcher agent when a task involves any library.
The researcher calls Context7 → gets current, version-specific docs → returns a Research Brief.
NEVER guess API signatures — docs are one tool call away.

## MCP Tools
- ALWAYS use Context7 for any library/framework question automatically
- NEVER guess API signatures — verify against docs first
- Skip Context7 only for project-specific logic or git operations

## Model Strategy
- Default: `opusplan` — auto-switches Opus for planning, Sonnet for execution
- Subagent model: Sonnet via CLAUDE_CODE_SUBAGENT_MODEL (agents override individually)
- Agent teams enabled via CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

## Compact Instructions
When compacting context, ALWAYS preserve:
- Current task description and acceptance criteria
- All file paths being modified
- Error messages and test failures encountered
- Architecture decisions made in this session
- The verification commands section above

## Common Gotchas
- [critical] NEVER use `any` type in TypeScript. Use `unknown` + type guard. Example: `function isUser(val: unknown): val is User`
- [critical] ALWAYS validate input at system boundaries with Zod/Pydantic. Example: `const input = schema.parse(req.body)`
- [critical] NEVER commit .env files. Check .gitignore includes `.env*` before first commit.
- [pattern] When debugging failing tests, read the test file FIRST, then the implementation. Don't guess.

## References
See @agent_docs/ci-standards.md for CI/CD pipeline requirements
See @agent_docs/architecture.md for backend/frontend patterns
See @agent_docs/testing.md for test strategy and coverage targets
See @agent_docs/security.md for security requirements
See @agent_docs/claude-agent-sdk.md for building custom agentic tools
See @agent_docs/dev-environment-manual.md for the complete dev environment guide

## Dev Environment
- Every project gets a `.devcontainer/` + `docker-compose.yml` for reproducible, sandboxed development
- Per-project RAG via `knowledge-rag` MCP — drop docs into `docs/`, they're auto-indexed
- Runtime pinning via `.nvmrc` / `.python-version`
- `/new-agent-app` scaffolds Claude Agent SDK projects with subagents, custom MCP tools, and hooks
