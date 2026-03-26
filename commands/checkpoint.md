---
name: checkpoint
description: Manage codebase checkpoints — save, restore, or list snapshots of your working state
---

Manage checkpoints: $ARGUMENTS

## Process

### Step 1: Parse Action

Parse $ARGUMENTS for:
- `save` or `create` — manually create a checkpoint now
- `restore` or `rollback` — restore to last checkpoint
- `list` or `history` — show checkpoint history
- `diff <checkpoint-id>` — show diff between current state and a checkpoint
- No arguments — show status (last checkpoint time, edit count since)

### Step 2: Execute

**save:**
1. Run `git stash push -m "manual-checkpoint-$(date +%Y%m%d-%H%M%S)" --include-untracked`
2. Immediately `git stash pop` (we just want the stash entry as a snapshot)
3. Log to ~/.claude/checkpoints/history.log
4. Report: "Checkpoint created at {timestamp}"

**restore:**
1. Read ~/.claude/checkpoints/history.log for last entry
2. Show what changed since that checkpoint: `git diff`
3. Ask for confirmation: "Restore to checkpoint {timestamp}? This will discard current changes."
4. If confirmed: `git checkout .` to restore tracked files
5. Report: "Restored to checkpoint {timestamp}"

**list:**
1. Read ~/.claude/checkpoints/history.log
2. Show last 10 checkpoints with timestamps
3. Show edit count since each

**diff:**
1. Show `git diff` of current state

## Rules
- Auto-checkpoints happen every 20 edits via the hook
- Manual checkpoints via `/checkpoint save` happen immediately
- Restore requires confirmation — it's destructive
- Checkpoints use git stash mechanism — lightweight, no extra storage
