#!/usr/bin/env bash
set -eo pipefail

# cleanup-project.sh — Clean temp files, caches, and screenshots after finishing a project
# Called by SessionEnd hook or manually: bash scripts/cleanup-project.sh [project-dir]

PROJECT_DIR="${1:-$(pwd)}"
CLEANED=0

log() { echo "[cleanup] $1"; }

# --- Project-level cleanup ---

if [ -d "$PROJECT_DIR" ]; then
  # .next build cache (rebuilds on pnpm dev)
  if [ -d "$PROJECT_DIR/.next" ]; then
    SIZE=$(du -sm "$PROJECT_DIR/.next" 2>/dev/null | awk '{print $1}')
    rm -rf "$PROJECT_DIR/.next"
    log "Removed .next/ (${SIZE}MB)"
    CLEANED=$((CLEANED + SIZE))
  fi

  # Playwright test results and screenshots
  if [ -d "$PROJECT_DIR/test-results" ]; then
    SIZE=$(du -sm "$PROJECT_DIR/test-results" 2>/dev/null | awk '{print $1}')
    rm -rf "$PROJECT_DIR/test-results"
    log "Removed test-results/ (${SIZE}MB)"
    CLEANED=$((CLEANED + SIZE))
  fi

  if [ -d "$PROJECT_DIR/playwright-report" ]; then
    SIZE=$(du -sm "$PROJECT_DIR/playwright-report" 2>/dev/null | awk '{print $1}')
    rm -rf "$PROJECT_DIR/playwright-report"
    log "Removed playwright-report/ (${SIZE}MB)"
    CLEANED=$((CLEANED + SIZE))
  fi

  # Visual regression screenshots (keep baselines, remove diffs/actuals)
  if [ -d "$PROJECT_DIR/.claude/visual-regression" ]; then
    for subdir in diffs actuals; do
      if [ -d "$PROJECT_DIR/.claude/visual-regression/$subdir" ]; then
        SIZE=$(du -sm "$PROJECT_DIR/.claude/visual-regression/$subdir" 2>/dev/null | awk '{print $1}')
        rm -rf "$PROJECT_DIR/.claude/visual-regression/$subdir"
        log "Removed visual-regression/$subdir/ (${SIZE}MB)"
        CLEANED=$((CLEANED + SIZE))
      fi
    done
  fi

  # Vitest/Jest coverage reports
  if [ -d "$PROJECT_DIR/coverage" ]; then
    SIZE=$(du -sm "$PROJECT_DIR/coverage" 2>/dev/null | awk '{print $1}')
    rm -rf "$PROJECT_DIR/coverage"
    log "Removed coverage/ (${SIZE}MB)"
    CLEANED=$((CLEANED + SIZE))
  fi

  # Turbopack/Next.js trace files
  find "$PROJECT_DIR" -maxdepth 1 -name "*.trace" -o -name "next-env.d.ts.bak" 2>/dev/null | while read f; do
    rm -f "$f"
    log "Removed $(basename "$f")"
  done

  # Stale pipeline checkpoint
  if [ -f "$PROJECT_DIR/.claude/pipeline-checkpoint.json" ]; then
    rm -f "$PROJECT_DIR/.claude/pipeline-checkpoint.json"
    log "Removed stale pipeline checkpoint"
  fi

  # Stale worktrees
  if [ -d "$PROJECT_DIR/.claude/worktrees" ]; then
    for wt in "$PROJECT_DIR/.claude/worktrees"/*/; do
      if [ -d "$wt" ]; then
        WT_NAME=$(basename "$wt")
        git -C "$PROJECT_DIR" worktree remove "$wt" --force 2>/dev/null && \
          log "Removed stale worktree: $WT_NAME" || true
        # Clean up orphaned branch
        git -C "$PROJECT_DIR" branch -D "worktree-$WT_NAME" 2>/dev/null || true
      fi
    done
  fi
fi

# --- Global cleanup (only if --global flag passed) ---

if [ "${2}" = "--global" ]; then
  # Playwright old browser versions (keep latest)
  PW_CACHE="$HOME/Library/Caches/ms-playwright"
  if [ -d "$PW_CACHE" ]; then
    # Count browser dirs, remove all but the newest
    BROWSER_DIRS=$(ls -dt "$PW_CACHE"/*/ 2>/dev/null | tail -n +3)
    if [ -n "$BROWSER_DIRS" ]; then
      for d in $BROWSER_DIRS; do
        SIZE=$(du -sm "$d" 2>/dev/null | awk '{print $1}')
        rm -rf "$d"
        log "Removed old Playwright browser: $(basename "$d") (${SIZE}MB)"
        CLEANED=$((CLEANED + SIZE))
      done
    fi
  fi

  # npm cache
  if command -v npm &>/dev/null; then
    SIZE=$(du -sm "$HOME/.npm" 2>/dev/null | awk '{print $1}')
    npm cache clean --force 2>/dev/null
    log "Cleaned npm cache (${SIZE}MB)"
    CLEANED=$((CLEANED + SIZE))
  fi

  # uv cache (Python package manager)
  if [ -d "$HOME/.cache/uv" ]; then
    SIZE=$(du -sm "$HOME/.cache/uv" 2>/dev/null | awk '{print $1}')
    rm -rf "$HOME/.cache/uv"
    log "Cleaned uv cache (${SIZE}MB)"
    CLEANED=$((CLEANED + SIZE))
  fi

  # Puppeteer cache (if using Playwright instead)
  if [ -d "$HOME/.cache/puppeteer" ]; then
    SIZE=$(du -sm "$HOME/.cache/puppeteer" 2>/dev/null | awk '{print $1}')
    rm -rf "$HOME/.cache/puppeteer"
    log "Cleaned puppeteer cache (${SIZE}MB)"
    CLEANED=$((CLEANED + SIZE))
  fi

  # VS Code cached extension VSIXs
  VSIX_CACHE="$HOME/Library/Application Support/Code/CachedExtensionVSIXs"
  if [ -d "$VSIX_CACHE" ]; then
    SIZE=$(du -sm "$VSIX_CACHE" 2>/dev/null | awk '{print $1}')
    rm -rf "$VSIX_CACHE"
    log "Cleaned VS Code cached extensions (${SIZE}MB)"
    CLEANED=$((CLEANED + SIZE))
  fi

  # Chrome cache
  CHROME_CACHE="$HOME/Library/Caches/Google"
  if [ -d "$CHROME_CACHE" ]; then
    SIZE=$(du -sm "$CHROME_CACHE" 2>/dev/null | awk '{print $1}')
    rm -rf "$CHROME_CACHE"
    log "Cleaned Chrome cache (${SIZE}MB)"
    CLEANED=$((CLEANED + SIZE))
  fi

  # Brave cache
  BRAVE_CACHE="$HOME/Library/Caches/BraveSoftware"
  if [ -d "$BRAVE_CACHE" ]; then
    SIZE=$(du -sm "$BRAVE_CACHE" 2>/dev/null | awk '{print $1}')
    rm -rf "$BRAVE_CACHE"
    log "Cleaned Brave cache (${SIZE}MB)"
    CLEANED=$((CLEANED + SIZE))
  fi

  # Homebrew cache
  if command -v brew &>/dev/null; then
    brew cleanup --prune=7 2>/dev/null
    log "Cleaned Homebrew cache (7+ day old)"
  fi

  # Old Claude CLI logs (keep last 7 days)
  if [ -d "$HOME/.claude/logs" ]; then
    find "$HOME/.claude/logs" -name "*.log" -mtime +7 -delete 2>/dev/null
    log "Cleaned old Claude logs (7+ days)"
  fi

  # iOS Simulators (unavailable ones)
  if command -v xcrun &>/dev/null; then
    xcrun simctl delete unavailable 2>/dev/null
    log "Cleaned unavailable iOS simulators"
  fi
fi

# --- Report ---
echo ""
echo "=== Cleanup Complete ==="
echo "Freed: ~${CLEANED}MB"
echo "Disk: $(df -h / | tail -1 | awk '{print $4 " free (" $5 " used)"}')"
