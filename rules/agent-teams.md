# Agent Teams Rules (Always Loaded)

## Worktree Isolation — Mandatory for Parallel Builds

When spawning multiple Agent subagents that touch different files, ALWAYS use `isolation: "worktree"` in the Agent tool call. This gives each agent a fresh context window (~40% usage vs 80-90% without isolation) and prevents file conflicts.

```
// CORRECT — each agent gets its own worktree
Agent(prompt: "Build the auth module", isolation: "worktree")
Agent(prompt: "Build the dashboard", isolation: "worktree")

// WRONG — agents share files and context, causing conflicts
Agent(prompt: "Build the auth module")
Agent(prompt: "Build the dashboard")
```

## When to Use Agent Teams

| Scenario | Team Preset | Agents |
|----------|------------|--------|
| Building a feature with 3+ files | `full-stack` | implementer + tester + reviewer |
| Building frontend pages | `frontend` | ui-builder + a11y-checker + visual-qa |
| Running quality checks | `quality-gate` | code-reviewer + security-auditor + regression-tester |

Team presets are at `config/teams/*.json`.

## Rules

- [critical] ALWAYS use `isolation: "worktree"` when spawning 2+ parallel agents that write to files
- [critical] NEVER let parallel agents write to the same file — split work by module/directory
- [pattern] After all worktree agents complete, verify the merge was clean before proceeding
- [pattern] Use `run_in_background: true` for independent agents, foreground for sequential dependencies
- [pattern] Max 3 concurrent worktree agents — more causes git merge complexity

## Integration with Pipeline Commands

| Command | Team Usage |
|---------|-----------|
| `/auto-build-all` | Use worktree isolation for non-overlapping tasks (risk: low/medium) |
| `/auto-ship` | Quality gate team runs in parallel (code-review + security + regression) |
| `/team-build` | Use the appropriate team preset from config/teams/ |
| `/check` | Quality gate team — 3 parallel agents with worktree isolation |
| `/ghost` | Full-stack team for building, quality-gate team for verification |

## Anti-Patterns

- [critical] NEVER run sequential builds when tasks are independent — use parallel worktree agents
- [critical] NEVER skip `isolation: "worktree"` for parallel file-writing agents
- [critical] NEVER spawn more than 3 concurrent worktree agents (git merge complexity)
- [pattern] If a task depends on another's output, run it AFTER the dependency completes (use `depends_on`)
