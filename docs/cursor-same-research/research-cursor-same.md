# Research: Cursor IDE + Same.new — Patterns to Adopt

**Date:** 2026-03-26
**Sources:** 20+ (official docs, engineering blogs, funding reports)

## Key Findings

### Cursor ($29.3B valuation, 1M+ paying devs)
- VS Code fork (not extension) — controls the editor kernel
- Codebase indexing: AST parsing + embeddings in Turbopuffer (272k token context)
- Tab: RL-trained MoE model, 400M req/day, 21% fewer suggestions but 28% higher accept
- Agent: 8 parallel agents in Git worktrees, background cloud VMs, BugBot PR review
- Rules: .mdc files with 4 apply modes (always, intelligent, file-glob, manual)
- @symbols: @codebase, @Docs, @Files, @Web, @Git, @Notepads
- Checkpoints: auto-save before operations, preview + restore
- KV-cache optimization for near-instant Tab completions

### Same.new (App Generator)
- Prompt-to-app: describe -> working Next.js app in minutes
- URL cloning: drop URL -> React/Next.js replica (~95% visual accuracy)
- Live preview + code diff side-by-side
- Opinionated defaults (Next.js always) = more reliable generation
- Integration bundles: Neon + Supabase + Clerk = complete app, not just frontend

## What to Adopt for claude-super-setup

### From Cursor:
1. **Checkpoint system** — auto-save codebase state before destructive operations
2. **@Docs integration** — use Context7 to inject live docs into any command
3. **Rule scoping by glob** — we have CLAUDE.md but no file-pattern scoping
4. **Background agent queuing** — queue follow-up instructions while agent works
5. **BugBot pattern** — auto-review PRs and propose fixes (we have /check but no auto-fix)
6. **Parallel worktree agents** — Cursor does 8, we could expand from 3

### From Same.new:
1. **URL-to-app cloning** — describe or paste URL -> scaffold a project
2. **Live preview during generation** — visual verification as code is written
3. **Integration bundles** — pre-configured auth + DB + payments per template
4. **Opinionated defaults** — reduce decision fatigue in scaffolding
