# Hook Architecture for Super Builder

## Overview

Hooks are the nervous system of the super builder. They fire at critical moments to enforce quality, catch errors, and trigger auto-fixes. Every hook must be:
- Fast (< 2s execution)
- Silent on success (no noise)
- Actionable on failure (clear error message + suggested fix)
- Idempotent (safe to run multiple times)

## Hook Inventory

### Pre-Write Hooks (fire before Edit/Write tools)

#### 1. design-system-compliance.sh
**Trigger:** PreToolUse on Edit/Write for *.tsx, *.css files
**Purpose:** Prevent hardcoded colors, spacing, and non-token values
**Checks:**
- No hex color values (#xxx) outside design token definitions
- No arbitrary pixel values (px) outside of known patterns
- No inline styles with color/spacing values
- Component imports use @/components/ui/* (shadcn)
**Action on fail:** BLOCK the write, suggest token replacement

#### 2. component-reuse-check.sh
**Trigger:** PreToolUse on Write for new component files
**Purpose:** Prevent duplicate components
**Checks:**
- Search project for existing components with similar names
- Check if shadcn/ui already has the needed component
**Action on fail:** WARN with existing component path

#### 3. read-before-write.sh (existing, enhance)
**Trigger:** PreToolUse on Edit
**Purpose:** Ensure file is read before editing
**Action on fail:** BLOCK the edit

### Post-Write Hooks (fire after Edit/Write tools)

#### 4. typecheck-on-save.sh
**Trigger:** PostToolUse on Edit/Write for *.ts, *.tsx files
**Purpose:** Catch type errors immediately
**Checks:** Run `tsc --noEmit` on the changed file
**Action on fail:** Log error, trigger auto-fix

#### 5. lint-on-save.sh
**Trigger:** PostToolUse on Edit/Write for *.ts, *.tsx, *.js files
**Purpose:** Catch lint errors immediately
**Checks:** Run ESLint on the changed file
**Action on fail:** Auto-fix if possible, log otherwise

#### 6. ssr-safety-check.sh
**Trigger:** PostToolUse on Edit/Write for *.tsx files containing "framer-motion"
**Purpose:** Prevent SSR animation bugs
**Checks:**
- No `initial={{ opacity: 0 }}` without `initial={false}` or `whileInView`
- Above-fold components use `initial={false}`
- `<noscript>` fallback exists in layout
- `viewport={{ once: true }}` on all `whileInView`
**Action on fail:** WARN with fix suggestion

#### 7. accessibility-quick-check.sh
**Trigger:** PostToolUse on Edit/Write for *.tsx files
**Purpose:** Catch obvious a11y issues
**Checks:**
- Images have alt text
- Buttons have accessible names
- Form inputs have labels
- Interactive elements have focus styles
- Touch targets >= 44px
**Action on fail:** WARN with fix suggestion

### Pre-Build Hooks

#### 8. build-gate.sh
**Trigger:** Before `pnpm build` or `next build`
**Purpose:** Prevent known-bad builds
**Checks:**
- No TypeScript errors (`tsc --noEmit`)
- No ESLint errors
- All imports resolve
- Environment variables present
**Action on fail:** BLOCK build, list errors

### Post-Build Hooks

#### 9. visual-snapshot.sh
**Trigger:** After successful build
**Purpose:** Capture visual state for comparison
**Actions:**
- Start dev server if not running
- Screenshot at 390px, 768px, 1440px
- Save to `e2e/screenshots/`
- Compare with baseline if exists

#### 10. dead-link-check.sh
**Trigger:** After successful build
**Purpose:** Find broken links
**Actions:**
- Crawl all pages
- Check all `<a href>` values
- Report any 404s or `href="#"`

### Pre-Commit Hooks

#### 11. test-before-commit.sh (existing, enhance)
**Trigger:** Pre-commit git hook
**Purpose:** No commits without passing tests
**Checks:** Full test suite (unit + E2E if available)
**Action on fail:** BLOCK commit

#### 12. secret-scan.sh
**Trigger:** Pre-commit git hook
**Purpose:** Prevent committing secrets
**Checks:**
- No .env files staged
- No API keys in code
- No private keys
**Action on fail:** BLOCK commit

### Error Recovery Hooks

#### 13. auto-fix-typecheck.sh
**Trigger:** When typecheck-on-save reports error
**Purpose:** Auto-fix common type errors
**Strategies:**
- Missing import → add import
- Type mismatch → suggest correct type
- Missing property → add with default value

#### 14. auto-fix-build.sh
**Trigger:** When build fails
**Purpose:** Auto-fix common build errors
**Strategies:**
- Missing module → install with pnpm
- Missing export → add export
- SSR error → add "use client" directive

### Monitoring Hooks

#### 15. budget-guard.sh (existing, enhance)
**Trigger:** PostToolUse on all tools
**Purpose:** Prevent runaway token usage
**Checks:**
- Tool call count < 200
- Subagent count < 20
- No infinite loops detected

#### 16. progress-reporter.sh
**Trigger:** PostToolUse on task completion markers
**Purpose:** Send progress updates to Telegram
**Actions:**
- Track tasks completed vs total
- Send milestone notifications
- Send completion notification with summary

## Hook Priority and Execution Order

```
PreToolUse (Edit/Write):
  1. read-before-write.sh      (BLOCK on fail)
  2. design-system-compliance.sh (BLOCK on fail)
  3. component-reuse-check.sh    (WARN on fail)

PostToolUse (Edit/Write):
  1. typecheck-on-save.sh       (LOG + auto-fix)
  2. lint-on-save.sh            (AUTO-FIX)
  3. ssr-safety-check.sh        (WARN)
  4. accessibility-quick-check.sh (WARN)

Pre-Commit:
  1. secret-scan.sh             (BLOCK on fail)
  2. test-before-commit.sh      (BLOCK on fail)

Post-Build:
  1. visual-snapshot.sh         (LOG)
  2. dead-link-check.sh         (WARN)

Always:
  1. budget-guard.sh            (BLOCK at limit)
  2. progress-reporter.sh       (LOG)
```

## Implementation Notes

- All hooks are shell scripts in `hooks/`
- Configured via `settings.json` hooks array
- Each hook has `set -euo pipefail` for safety
- Hooks should be fast — use file-level checks, not project-wide scans
- Heavy checks (E2E, visual) only run at build/commit gates, not per-file
