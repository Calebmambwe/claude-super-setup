# Self-Healing Pipeline Specification

## Overview

The self-healing pipeline automatically detects, classifies, and fixes errors during app generation. It ensures that the final output is error-free without human intervention.

## Error Classification

### Type 1: Syntax Errors
**Detection:** TypeScript compiler, ESLint
**Examples:** Missing semicolons, unclosed brackets, invalid JSX
**Fix strategy:** Parse error message, locate exact line, apply correction
**Success rate:** ~95% (most are trivial)

### Type 2: Type Errors
**Detection:** `tsc --noEmit`
**Examples:** Wrong type, missing property, incompatible assignment
**Fix strategy:**
1. Read the error message for expected vs actual type
2. Check the interface/type definition
3. Apply the correct type or add missing property
**Success rate:** ~85%

### Type 3: Import Errors
**Detection:** Build failure, TypeScript
**Examples:** Module not found, missing export, wrong path
**Fix strategy:**
1. Search project for the correct module path
2. Check if package needs installing (`pnpm add`)
3. Check if export name changed
**Success rate:** ~90%

### Type 4: Runtime Errors
**Detection:** Playwright E2E tests, console error capture
**Examples:** Null reference, undefined property, hydration mismatch
**Fix strategy:**
1. Read stack trace to locate error source
2. Add null check or default value
3. For hydration: add "use client" or fix SSR/client mismatch
**Success rate:** ~75%

### Type 5: Visual Errors
**Detection:** Screenshot comparison, human-in-the-loop feedback
**Examples:** Wrong colors, missing sections, broken layout, invisible content
**Fix strategy:**
1. Identify which section is wrong
2. Compare with reference screenshot
3. Fix CSS/layout code
4. Re-screenshot and compare
**Success rate:** ~70%

### Type 6: Accessibility Errors
**Detection:** axe-core via Playwright
**Examples:** Missing alt text, low contrast, no keyboard navigation
**Fix strategy:**
1. Parse axe violation details
2. Apply fix per violation type (add aria-label, fix contrast, add tabindex)
**Success rate:** ~90%

### Type 7: SSR/Hydration Errors
**Detection:** Build warnings, runtime console errors
**Examples:** `initial={{ opacity: 0 }}` on above-fold, client-only API in server component
**Fix strategy:**
1. Add "use client" directive where needed
2. Change `initial` to `initial={false}` for above-fold content
3. Wrap client-only code in `useEffect` or dynamic import
**Success rate:** ~85%

## The Fix Loop (Ralph Loop Enhanced)

```
┌─────────────────────────────────────┐
│  1. IMPLEMENT                        │
│     Write/edit code for current task │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  2. VERIFY                           │
│     - TypeScript check               │
│     - ESLint                         │
│     - Build                          │
│     - Run tests                      │
│     - Screenshot (if UI change)      │
└──────────────┬──────────────────────┘
               │
          ┌────┴────┐
          │ PASS?   │
          └────┬────┘
         yes   │   no
          │    │    │
          ▼    │    ▼
       ┌──┐   │  ┌─────────────────────┐
       │OK│   │  │  3. CLASSIFY ERROR   │
       └──┘   │  │     Determine type   │
              │  │     (1-7 above)       │
              │  └──────────┬───────────┘
              │             │
              │             ▼
              │  ┌─────────────────────┐
              │  │  4. AUTO-FIX         │
              │  │     Apply strategy   │
              │  │     for error type   │
              │  └──────────┬───────────┘
              │             │
              │             ▼
              │  ┌─────────────────────┐
              │  │  5. RE-VERIFY        │
              │  │     Run same checks  │
              │  └──────────┬───────────┘
              │             │
              │        ┌────┴────┐
              │        │ PASS?   │
              │        └────┬────┘
              │       yes   │   no
              │        │    │    │
              │        ▼    │    ▼
              │     ┌──┐   │  ┌───────────┐
              │     │OK│   │  │ Attempt   │
              │     └──┘   │  │ < 3?      │
              │            │  └─────┬─────┘
              │            │   yes  │  no
              │            │    │   │   │
              │            │    ▼   │   ▼
              │            │  Go to │ ┌──────────┐
              │            │  step 4│ │ ESCALATE │
              │            │        │ │ to human │
              │            │        │ └──────────┘
              │            │        │
              └────────────┘        │
```

## Fix Attempt Budget

- **Per task:** Max 3 fix attempts
- **Per project:** Max 10 escalations before pausing
- **Per error type:** Track success rate, skip auto-fix if historically < 50%

## Learning from Fixes

After every successful fix:
1. Record the error pattern and fix applied
2. Add to learning ledger via MCP
3. Next time same error appears → apply fix immediately (no diagnosis needed)

After every failed fix (escalation):
1. Record what was tried and why it failed
2. Flag for human review
3. Update fix strategy for that error type

## Error Recovery Strategies by Framework

### Next.js App Router
| Error | Strategy |
|-------|----------|
| "use client" missing | Add directive to file importing useState/useEffect/etc. |
| metadata + "use client" conflict | Remove metadata export, move to parent layout |
| Hydration mismatch | Wrap dynamic content in useEffect or Suspense |
| Missing "use server" | Add to files with server actions |
| Build OOM | Reduce bundle with dynamic imports |

### Framer Motion
| Error | Strategy |
|-------|----------|
| Invisible content (SSR) | Change initial to initial={false} |
| Animation not firing | Add whileInView with viewport={{ once: true }} |
| Type error on Variants | Import Variants type from framer-motion |
| Layout shift on animation | Use layout="position" or layoutId |

### Tailwind v4
| Error | Strategy |
|-------|----------|
| Class not applying | Check @theme and @layer declarations |
| Custom color not working | Define in @theme inline block |
| Dark mode not working | Check @custom-variant dark declaration |

### Playwright E2E
| Error | Strategy |
|-------|----------|
| Element not found | Check selector, add waitFor, increase timeout |
| Strict mode violation | Add .first() or .nth(0) to selector |
| Navigation timeout | Check page routing, use waitForURL with glob |
| Screenshot mismatch | Update baseline or fix visual regression |
