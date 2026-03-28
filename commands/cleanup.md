---
name: cleanup
description: Clean project caches, screenshots, temp files, and optionally global caches
---

Clean up disk space: $ARGUMENTS

## What This Does

Removes build caches, test screenshots, visual regression diffs, coverage reports, stale worktrees, and optionally global caches (npm, Playwright, Chrome, uv, VS Code).

## Process

### Step 1: Determine Scope

- If `--global` in $ARGUMENTS: run both project + global cleanup
- If `--project-only` or no flag: run project cleanup only
- If `--audit` in $ARGUMENTS: show disk usage report without deleting anything

### Step 2: Run Cleanup

```bash
# Project-only (default)
bash ~/.claude-super-setup/scripts/cleanup-project.sh "$(pwd)"

# Project + global caches
bash ~/.claude-super-setup/scripts/cleanup-project.sh "$(pwd)" --global
```

### Step 3: Find Inactive node_modules (optional, if --global)

Search for node_modules in projects not modified in 30+ days:

```bash
find ~ -maxdepth 4 -name "node_modules" -type d -prune | while read d; do
  project=$(dirname "$d")
  last_mod=$(find "$project" -maxdepth 1 -name "*.ts" -o -name "*.tsx" -o -name "*.json" 2>/dev/null | head -1 | xargs stat -f "%m" 2>/dev/null || echo 0)
  now=$(date +%s)
  days_ago=$(( (now - last_mod) / 86400 ))
  if [ "$days_ago" -gt 30 ]; then
    size=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
    echo "  $size  $project (${days_ago} days inactive)"
  fi
done
```

Present the list and ask: "Remove node_modules from these inactive projects? They can be reinstalled with `pnpm install`."

If user confirms, remove them.

### Step 4: Report

```
## Cleanup Complete

Project: {cwd}
Freed: {total}MB

{If --global:}
Global caches cleaned:
  npm cache:        {size}
  Chrome cache:     {size}
  Playwright old:   {size}
  uv cache:         {size}
  VS Code VSIXs:    {size}

{If inactive node_modules found:}
Inactive node_modules removed: {count} projects, {total}GB

Disk: {free} free ({percent} used)
```

## Rules

- NEVER delete node_modules from the CURRENT project
- NEVER delete .git directories
- NEVER delete source code files
- ALWAYS show what will be deleted before deleting (for node_modules)
- Visual regression baselines are KEPT — only diffs/actuals are removed
- The SessionEnd hook runs project cleanup automatically — /cleanup --global is for manual deep cleaning
