#!/usr/bin/env bash
# Claude Code status line script
# Receives JSON on stdin with session context

input=$(cat)

# Extract fields from JSON
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')

# Shorten the working directory (replace $HOME with ~)
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch (skip locks to avoid hanging)
git_branch=""
if [ -n "$cwd" ] && [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
fi

# Build status line with ANSI colors (dim-friendly)
# Colors: cyan for model, yellow for path, green for git, magenta for context
parts=()

# Model
parts+=("$(printf '\033[36m%s\033[0m' "$model")")

# Working directory
parts+=("$(printf '\033[33m%s\033[0m' "$short_cwd")")

# Git branch
if [ -n "$git_branch" ]; then
  parts+=("$(printf '\033[32m\xef\xa0\x85 %s\033[0m' "$git_branch")")
fi

# Context usage
if [ -n "$used_pct" ]; then
  used_int=${used_pct%.*}
  if [ "$used_int" -ge 80 ] 2>/dev/null; then
    color='\033[31m'  # red when high
  elif [ "$used_int" -ge 50 ] 2>/dev/null; then
    color='\033[33m'  # yellow when medium
  else
    color='\033[32m'  # green when low
  fi
  parts+=("$(printf "${color}ctx:%s%%\033[0m" "$used_int")")
fi

# Vim mode
if [ -n "$vim_mode" ]; then
  parts+=("$(printf '\033[35m[%s]\033[0m' "$vim_mode")")
fi

# Session name
if [ -n "$session_name" ]; then
  parts+=("$(printf '\033[90m#%s\033[0m' "$session_name")")
fi

# Join parts with a separator
printf '%s' "$(IFS=' | '; echo "${parts[*]}")"
