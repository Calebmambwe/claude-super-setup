# Git Worktree Isolation for Parallel Agent Execution

This document covers the git worktree isolation pattern used to enable safe parallel agent execution in the Claude Code pipeline.

---

## 1. What Worktree Isolation Is

Git worktrees allow you to have multiple working directories checked out from a single repository at the same time. Unlike cloning, worktrees share the same `.git` directory — meaning they share history, refs, and configuration without duplicating the repository on disk.

In a multi-agent context:

- Each agent gets an isolated working directory (the worktree) on a separate branch.
- Agents can write files, commit, and run commands without interfering with each other.
- Because branches are isolated, parallel agents never produce merge conflicts during execution — conflicts only arise when the orchestrator integrates results.

Claude Code supports this natively via the `Agent` tool's `isolation: "worktree"` parameter, making worktree-based parallelism a first-class pattern in the pipeline.

---

## 2. How It Works in Claude Code

When you invoke the `Agent` tool with `isolation: "worktree"`:

1. Claude Code creates a temporary git worktree from the current HEAD, checked out on a new branch (e.g., `agent/task-abc123`).
2. The agent runs inside that worktree directory — all file reads and writes are scoped to it.
3. On completion, one of two things happens:
   - **No changes made**: The worktree and its branch are automatically cleaned up. Nothing is left behind.
   - **Changes made**: The worktree path and branch name are returned in the agent result. The orchestrator decides what to do with them (merge, cherry-pick, review, or discard).

The orchestrator (the parent Claude Code session) is responsible for integrating results. It can inspect diffs, merge branches, cherry-pick commits, or simply discard a worktree if the output is not needed.

---

## 3. When to Use Worktrees

Use this decision matrix to choose between worktree-isolated and sequential execution:

| Scenario | Use Worktree? | Why |
|---|---|---|
| Independent file sets (no overlap) | Yes | Maximum parallelism, no conflict risk |
| Shared files (same module) | No | Sequential execution avoids merge conflicts |
| Read-only research | No | No writes, no isolation needed |
| Large refactors | Yes | Isolate risky changes, easy rollback |
| Test runs | No | Tests read code, they do not modify it |

**Rule of thumb**: if two agents will never touch the same file, worktrees give you free parallelism. If they might, run them sequentially or split the task so the shared file is only touched once.

---

## 4. Merge Strategies

Once agent worktrees complete, the orchestrator has several options for integrating changes:

### Auto-merge
When agents touch entirely different files, `git merge` will succeed cleanly. The orchestrator merges each agent branch into the integration branch sequentially. No manual intervention required.

### Conflict resolution
When two agents modify the same file (even in isolated worktrees), merging will produce a conflict. The orchestrator must resolve it — either by editing the conflict markers directly, choosing one side with `git checkout --ours / --theirs`, or re-running the conflicting agent sequentially after the first has merged.

### Sequential fallback
If the task decomposition reveals that two agents will likely touch the same file, the safest option is to not use worktrees for that pair and run them sequentially instead. Conflict-free integration is always preferable to conflict resolution.

### Cherry-pick
When only specific commits from an agent branch are wanted (not the entire branch), the orchestrator can cherry-pick individual commits onto the integration branch:

```bash
git cherry-pick <commit-sha>
```

This is useful when an agent produces several commits but only one of them is relevant.

---

## 5. Integration with Pipeline Commands

Worktree isolation is wired into several pipeline commands:

- **`/auto-build-all`** — When processing independent tasks from `tasks.json`, tasks with `risk != high` are eligible for parallel execution via worktrees. High-risk tasks always run sequentially.
- **`/parallel-implement`** — Uses worktrees to distribute spec-kit tasks across agents in parallel. Each spec section becomes an agent on its own branch.
- **`/team-build`** — The multi-agent team command. Each agent in the team gets a dedicated worktree. The orchestrator aggregates results after all agents complete.
- **Ghost Mode (`/ghost`)** — Does NOT use worktrees. Ghost Mode runs an overnight sequential pipeline where predictability and clean state matter more than parallelism. Worktrees add integration complexity that is not worth it in unattended runs.

---

## 6. Cleanup

### Automatic
The `Agent` tool handles cleanup automatically when an agent makes no changes. The worktree directory is removed and the branch is deleted without any action required.

### Manual
If a worktree needs to be removed manually (e.g., after merging or discarding agent output):

```bash
# Remove the worktree directory and unregister it from git
git worktree remove <path>

# Delete the agent branch
git branch -d <branch-name>
```

### Stale worktrees
If a worktree directory was deleted outside of git (e.g., `rm -rf`), git still has a stale registration. Clean it up with:

```bash
git worktree prune
```

This removes all stale worktree entries from `.git/worktrees/` without touching any active ones.

---

## 7. Gotchas

**Shared `.git` directory**
All worktrees share the same `.git` directory. This means git hooks, config, and refs are global across all worktrees. A pre-commit hook in one worktree fires in all of them. Be aware of hooks that assume a single working directory.

**One branch per worktree**
Git does not allow two worktrees to be checked out on the same branch simultaneously. Each agent worktree must be on a unique branch. The `Agent` tool handles this automatically by generating unique branch names, but manual worktree creation requires care.

**IDE and file watcher interference**
Tools like VS Code, Tauri dev servers, and filesystem watchers may trigger on changes inside worktree directories. If worktrees are created inside the project root (e.g., `.worktrees/`), add that directory to `.gitignore` and to VS Code's `files.watcherExclude` setting to prevent false positives.

```json
// .vscode/settings.json
{
  "files.watcherExclude": {
    "**/.worktrees/**": true
  }
}
```

**Checkout time on large repos**
Worktree creation itself is fast — it does not clone the repository. However, checking out a branch with many files still takes time proportional to the number of files changed relative to HEAD. For very large repositories, consider whether the parallelism gain outweighs the checkout overhead for short-lived tasks.
