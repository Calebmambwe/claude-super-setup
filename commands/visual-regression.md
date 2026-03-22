---
name: visual-regression
description: Run visual regression check on specified pages at multiple viewports
---

Run visual regression check on: $ARGUMENTS

## What This Does

Captures screenshots at multiple viewports, compares against baselines, and reports visual regressions. Designed to catch layout shifts, missing elements, and design system violations.

## Process

### Step 1: Determine Pages to Test

If $ARGUMENTS specifies pages/routes, use those. Otherwise:
1. Read `src/app/` directory for all `page.tsx` files
2. Map file paths to routes (e.g., `src/app/pricing/page.tsx` → `/pricing`)
3. Include at minimum: `/` (home page)

### Step 2: Start Dev Server (if not running)

```bash
PORT=4173 pnpm dev &
sleep 5
```

### Step 3: Capture Screenshots at 3 Viewports

For each page, use Playwright MCP to:
1. Navigate to the page
2. Wait for network idle
3. Take full-page screenshots at:
   - **Mobile**: 375px width (iPhone SE)
   - **Tablet**: 768px width (iPad)
   - **Desktop**: 1440px width (standard laptop)
4. Save to `tests/screenshots/current/{route}-{viewport}.png`

### Step 4: Compare Against Baselines

If `tests/screenshots/baseline/` exists:
1. Compare each current screenshot against its baseline
2. Use pixel-level comparison thresholds:
   - **Component-level pages**: 0.1% pixel diff tolerance
   - **Full marketing pages**: 1% pixel diff tolerance (content may vary)
3. Report any screenshots that exceed the threshold
4. For each failure: show the specific area that changed

If no baseline exists:
1. Copy current screenshots to `tests/screenshots/baseline/`
2. Report: "Baseline created for {N} pages x 3 viewports = {N*3} screenshots"

### Step 5: Design System Compliance Check

In addition to pixel comparison, check:
1. No hardcoded hex colors in the rendered HTML (inspect via Playwright)
2. All interactive elements have visible focus states (Tab through the page)
3. No horizontal scroll at any viewport (content doesn't overflow)
4. Images have alt text (check via snapshot)

### Step 6: Report

```
## Visual Regression Report

Pages tested: {N}
Viewports: mobile (375px), tablet (768px), desktop (1440px)
Total screenshots: {N*3}

Results:
  ✓ / (home) — all viewports pass
  ✗ /pricing — mobile viewport: 2.3% diff (threshold: 1%)
    → Area: pricing cards not stacking correctly

Design system compliance:
  ✓ No hardcoded colors detected
  ✗ /about — missing focus ring on "Learn More" button
```

### Step 7: Update Baselines (on intentional changes)

If the user confirms a visual change is intentional:
```bash
cp tests/screenshots/current/* tests/screenshots/baseline/
```

## Rules
- ALWAYS test at all 3 viewports — desktop-only testing misses most layout regressions
- NEVER update baselines without user confirmation
- If the dev server is already running, reuse it
- This command is called by `/check` for frontend tasks — it is not just manual
- Kill the dev server at the end if this command started it
