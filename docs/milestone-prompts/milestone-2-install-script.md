# Milestone 2: Install Script

## Section 1: Task Summary

**What:** Create `install.sh` and `uninstall.sh` that enable one-command installation of the claude-super-setup configuration on any macOS/Linux machine.

**In scope:**
- `install.sh` with --mode (symlink/copy), --dry-run, --no-backup, --modules, --prefix, --help
- `uninstall.sh` with optional backup restore
- Post-install health check
- User override template creation
- Testing on clean environment

**Out of scope:**
- Homebrew formula (deferred)
- npm package distribution (deferred)
- Interactive setup wizard (deferred)

**Definition of done:**
- [ ] `install.sh` creates working symlinks from `~/.claude/` to repo
- [ ] `install.sh --dry-run` shows changes without making them
- [ ] `install.sh --mode=copy` copies instead of symlinks
- [ ] Existing `~/.claude/` is backed up before overwrite
- [ ] `uninstall.sh` removes symlinks/copies cleanly
- [ ] `uninstall.sh --restore` restores from backup
- [ ] Health check validates installation
- [ ] User override templates created for settings.local.json and personal CLAUDE.md
- [ ] Both scripts pass shellcheck

## Section 2: Project Background

**Prerequisites:** Milestone 1 must be complete. The repo must exist with all config files in the correct structure.

**Install philosophy:** Symlink by default. This means `git pull` in the repo immediately updates the live config. Copy mode is available for environments where symlinks cause issues.

**Key design decision:** The repo is cloned to `~/.claude-super-setup/` (not the user's choice of directory). Symlinks point from `~/.claude/{target}` → `~/.claude-super-setup/{source}`. This ensures a consistent, predictable layout.

## Section 3: Current Task Context

Milestone 1 (Repository Scaffold & CI) is complete. The repo exists at GitHub with all config files and a passing CI pipeline.

## Section 4: Design Document Reference

See `docs/design/design-document.md` for:
- Section 2.2: Complete install flow diagram
- Section 4.1: install.sh design specification (all flags, all steps)
- Section 3.4: Personal vs shared config classification

## Section 5: Pre-Implementation Exploration

Before implementing:
1. Read `docs/design/design-document.md` Section 2.2 and 4.1 — install flow and design
2. Read the repo structure to understand what gets symlinked where
3. Check what files currently exist in `~/.claude/` that are personal (must NOT be overwritten)
4. Review bash best practices for installers (error handling, color output, idempotency)

## Section 6: Implementation Instructions

### Architecture constraints
- Scripts must work on macOS (BSD tools) and Linux (GNU tools) — watch for `cp`, `ln`, `readlink` differences
- Use POSIX-compatible shell where possible, bash 4+ features only when necessary
- Must be idempotent: running install.sh twice should not break anything
- NEVER overwrite personal files (settings.local.json, agent-memory/, logs/, etc.)
- Backup directory: `~/.claude-backup-{YYYYMMDD-HHMMSS}/`

### Ordered build list

**Step 1: Create install.sh**
Implement all 11 steps from design doc Section 4.1:
1. Parse arguments (--mode, --dry-run, --no-backup, --modules, --prefix, --help)
2. Pre-flight checks (git, bash version, jq)
3. Clone repo to `~/.claude-super-setup/` (or `git pull` if already cloned)
4. Backup existing `~/.claude/` (unless --no-backup)
5. Create `~/.claude/` if needed
6. Create symlinks (or copy in copy mode) for each module
7. Handle config files specially: settings.json merge, CLAUDE.md merge
8. Create user override files from templates (if they don't exist)
9. Make hooks executable
10. Run health check
11. Print summary

Symlink targets:
```
~/.claude/commands     → ~/.claude-super-setup/commands
~/.claude/agents       → ~/.claude-super-setup/agents/core  (plus community/ contents)
~/.claude/hooks        → ~/.claude-super-setup/hooks
~/.claude/rules        → ~/.claude-super-setup/rules
~/.claude/skills       → ~/.claude-super-setup/skills
~/.claude/agent_docs   → ~/.claude-super-setup/agent_docs
~/.claude/config       → ~/.claude-super-setup/config  (selective files)
```

**Step 2: Create uninstall.sh**
1. Parse arguments (--restore, --help)
2. Remove symlinks (or copied files)
3. If --restore: find most recent backup, restore it
4. Print summary

**Step 3: Create user-overrides/settings.local.json.template**
```json
{
  "$schema": "https://json-schema.store.org/claude-code-settings.json",
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-4-6"
  },
  "permissions": {
    "allow": [],
    "deny": []
  }
}
```

**Step 4: Test locally**
- Test on current machine with existing `~/.claude/`
- Verify backup is created
- Verify symlinks point correctly
- Verify health check passes
- Test `--dry-run` mode
- Test `uninstall.sh`
- Test `uninstall.sh --restore`

### Git workflow
- Branch: `feature/install-script`
- Commit: `feat: add install.sh and uninstall.sh with backup, symlink, and health check`

## Section 7: Final Reminders

- Run `shellcheck install.sh uninstall.sh` before committing
- Test both symlink and copy modes
- Verify idempotency: run install.sh twice, everything should still work
- Verify personal files are NEVER overwritten
- Handle edge case: user has some but not all directories in `~/.claude/`
- Handle edge case: `~/.claude-super-setup/` already exists (git pull, not re-clone)
- Print colored output for clarity (green = success, yellow = warning, red = error)
