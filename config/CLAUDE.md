# Claude Code — Project Rules

IMPORTANT: These are the highest-priority rules. Everything else is in path-scoped rule files.

## Core Workflow
- Explore > Plan > Implement > Verify for multi-file changes
- One task per context window. /clear between unrelated tasks.
- Branch per task. Conventional commits: feat:, fix:, refactor:, docs:, test:, ci:
- NEVER write code without a spec for features >3 files. Run /plan first.
- ALWAYS use Context7 MCP for library/framework questions. NEVER guess API signatures.

## Verification (Non-Negotiable)
After EVERY implementation, run ALL applicable:
  pnpm test && pnpm lint && pnpm typecheck    # TypeScript
  pytest && ruff check && mypy .               # Python
NEVER declare done without running tests.

## Two-Correction Rule
Corrected twice on same issue: STOP, re-read spec, /clear, restart. Polluted context cannot be fixed — only replaced.

## Autonomous Pipelines
- Manual: /plan > /build > /check > /ship > /reflect
- Semi-auto: /dev <feature>
- Fully autonomous: /auto-dev <feature>
- Resume interrupted: /auto-ship reads checkpoint and resumes
- Tiny changes (1-2 files): code directly > /check > /ship

## Critical Gotchas (MUST follow)
- NEVER use `any` in TypeScript. Use `unknown` + type guard.
- ALWAYS validate at system boundaries with Zod/Pydantic.
- NEVER commit .env files.
- NEVER leave features half-wired. Forms must send. Links must resolve. Images must exist.
- Next.js 16: cookies(), headers(), params, searchParams are ALL async.
- shadcn/ui v4: run `shadcn docs <component>` before implementing. gap-* not space-*.
- Framer Motion SSR: NEVER `initial={{ opacity: 0 }}` above fold. Use `initial={false}`.
- Local fs uploads don't work on Vercel. Use @vercel/blob.
- Bash scripts: `#!/usr/bin/env bash` + `set -euo pipefail` on lines 1-2.
- ALL static data in src/data/ — never duplicate arrays across files.

## Compact — Preserve These
- Current task + acceptance criteria
- File paths being modified
- Error messages and test failures
- Architecture decisions this session
