# Testing Strategy for Generated Apps

## Testing Pyramid

```
         ┌──────────────────┐
         │   Visual Tests    │  ← Screenshot comparison
         │   (per build)     │
         ├──────────────────┤
         │   E2E Tests       │  ← Playwright
         │   (per milestone) │
         ├──────────────────┤
         │  Integration Tests│  ← API + DB
         │  (per feature)    │
         ├──────────────────┤
         │   Unit Tests      │  ← Vitest
         │  (per function)   │
    ─────┴──────────────────┴─────
         Type & Lint Checks
         (per file save)
```

## Test Types

### 1. Type Checking (Continuous)
- Run after every file write
- `tsc --noEmit` on changed files
- Zero tolerance — must pass before proceeding

### 2. Linting (Continuous)
- Run after every file write
- ESLint with strict config
- Auto-fix where possible

### 3. Unit Tests (Per Feature)
- Vitest for utility functions, hooks, validation schemas
- Focus on business logic, not UI rendering
- Minimum 80% coverage on utils/lib files

### 4. E2E Tests (Per Milestone)
- Playwright for critical user flows
- Standard test suite generated for every app:

```typescript
// Standard E2E suite for any generated app
const standardTests = [
  "homepage loads with visible content",
  "navigation between all pages works",
  "mobile navigation (hamburger) works",
  "all links have valid href (no dead links)",
  "all forms accept input",
  "no console errors on any page",
  "responsive at 390px, 768px, 1440px",
  "dark/light theme toggle works (if applicable)",
  "auth flow works (sign up → sign in → protected page)",
];
```

### 5. Visual Tests (Per Build)
- Screenshot all pages at 3 viewports
- Compare with baseline (if exists) or reference screenshots (for clones)
- Flag visual regressions > 5% pixel difference

### 6. Accessibility Tests (Per Build)
- axe-core via Playwright
- Check all pages for WCAG 2.2 AA violations
- Zero critical violations policy
- Warn on minor violations

### 7. Performance Tests (Pre-Ship)
- Lighthouse CI with minimum thresholds:
  - Performance: > 90
  - Accessibility: > 95
  - Best Practices: > 90
  - SEO: > 90

## Generated Test Templates

Every template includes a baseline test file. Example for web-shadcn-v4:

```typescript
// e2e/smoke.spec.ts — generated with every new project
import { test, expect } from "@playwright/test";

const pages = ["/"]; // auto-populated from app/ directory

for (const path of pages) {
  test(`${path} loads with content`, async ({ page }) => {
    await page.goto(`http://localhost:3000${path}`, { waitUntil: "networkidle" });
    const body = await page.locator("body").textContent();
    expect(body!.length).toBeGreaterThan(50);
  });

  test(`${path} has no console errors`, async ({ page }) => {
    const errors: string[] = [];
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(msg.text());
    });
    await page.goto(`http://localhost:3000${path}`, { waitUntil: "networkidle" });
    await page.waitForTimeout(1000);
    const real = errors.filter((e) => !e.includes("favicon") && !e.includes("hydration"));
    expect(real).toHaveLength(0);
  });

  test(`${path} is responsive at mobile`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(`http://localhost:3000${path}`, { waitUntil: "networkidle" });
    // No horizontal scroll
    const bodyWidth = await page.evaluate(() => document.body.scrollWidth);
    const viewportWidth = await page.evaluate(() => window.innerWidth);
    expect(bodyWidth).toBeLessThanOrEqual(viewportWidth + 1);
  });
}

test("all links have valid href", async ({ page }) => {
  await page.goto("http://localhost:3000", { waitUntil: "networkidle" });
  const links = page.locator("a[href]");
  const count = await links.count();
  for (let i = 0; i < count; i++) {
    const href = await links.nth(i).getAttribute("href");
    expect(href).toBeTruthy();
    expect(href).not.toBe("#");
  }
});

test("accessibility: no critical violations", async ({ page }) => {
  await page.goto("http://localhost:3000", { waitUntil: "networkidle" });
  // Note: requires @axe-core/playwright
  // const results = await new AxeBuilder({ page }).analyze();
  // expect(results.violations.filter(v => v.impact === 'critical')).toHaveLength(0);
});
```

## Human-in-the-Loop Testing

For when the builder needs human verification:

### Click Tracker (auto-included)
- Tracks every click, scroll depth, and navigation path
- Captures console errors and network failures
- Detects dead links and dead clicks
- Stores to `analytics.jsonl` and `errors.jsonl`
- API endpoint for real-time analysis

### Error Reporter (auto-included)
- Captures unhandled errors, promise rejections
- Intercepts failed fetch requests
- Detects broken links on click
- Flushes to server every 3 seconds

### Analysis Workflow
1. Human tests the site
2. Human says "analyze"
3. System reads analytics.jsonl and errors.jsonl
4. Generates report: top clicks, dead zones, scroll depth, errors found
5. Auto-fixes every error
6. Human re-tests
7. Iterate until clean
