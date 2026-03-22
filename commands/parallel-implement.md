---
name: parallel-implement
description: Execute spec-kit tasks in parallel via worktree-isolated subagents
---
Implement tasks from the spec in parallel using git worktrees.

## Input
Read the task list from: specs/$ARGUMENTS.tasks.md
If no task file found, prompt the user to run /speckit.tasks first.

## Execution Steps

1. **Parse tasks** from the task file into a dependency DAG
2. **Identify parallelizable groups** -- tasks with no unresolved dependencies
3. **For each parallel group:**
   a. Create a git worktree per task: `git worktree add .claude/worktrees/task-{N} -b task/{feature}-{N}`
   b. Spawn a subagent in each worktree with:
      - The task description as the primary prompt
      - The constitution and spec as context
      - Tools: Read, Write, Edit, Bash, Grep, Glob
      - Isolation: worktree
   c. Wait for all agents in the group to complete
4. **Merge results:**
   a. For each completed task branch, rebase onto the feature branch
   b. If conflicts arise, present them for human resolution
   c. Run the verification lattice (Layer 1 minimum) after each merge
5. **Report:** Show summary of completed tasks, any failures, and verification results

## Constraints
- Maximum 5 parallel agents (to stay within API budget)
- Each agent has a 30-minute timeout
- If any agent fails, log the failure and continue with remaining tasks
- Always run lint + typecheck after merging (Layer 1 verification)

## Example
```
/parallel-implement payment-retry
-> Reads specs/payment-retry.tasks.md
-> Identifies 8 tasks, 3 parallelizable groups
-> Group 1 (no deps): tasks 1, 2, 3 (run in parallel)
-> Group 2 (depends on group 1): tasks 4, 5 (run in parallel)
-> Group 3 (depends on group 2): tasks 6, 7, 8 (run in parallel)
-> Merges all branches, runs verification
-> Reports results
```
