Run an accessibility audit on the project: $ARGUMENTS

You are executing the **Accessibility Audit** workflow. Audit the project for WCAG 2.2 AA compliance and generate a prioritized violation report.

---

## Step 1: Check for eslint-plugin-jsx-a11y

```bash
cat package.json 2>/dev/null | grep -E "jsx-a11y"
```

**If found:** Run ESLint with a11y rules:

```bash
npx eslint src/ --ext .tsx,.jsx --plugin jsx-a11y \
  --rule '{"jsx-a11y/alt-text": "error", "jsx-a11y/label-has-associated-control": "error", "jsx-a11y/interactive-supports-focus": "error", "jsx-a11y/click-events-have-key-events": "error", "jsx-a11y/no-noninteractive-element-interactions": "warn"}' \
  --format stylish 2>/dev/null || \
npx eslint src/ --ext .tsx,.jsx --format stylish 2>/dev/null
```

Record all a11y rule violations — note file, line, and rule name.

**If NOT found:**

```
[WARN] eslint-plugin-jsx-a11y not installed. Static analysis skipped.
Install with: pnpm add -D eslint-plugin-jsx-a11y
```

---

## Step 2: Check for Playwright + Run axe-core

```bash
npx playwright --version 2>/dev/null && echo "PLAYWRIGHT_AVAILABLE" || echo "PLAYWRIGHT_NOT_AVAILABLE"
```

**If Playwright is available**, check if a dev server is running:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null
```

**If dev server is up**, run axe-core:

```bash
cat > /tmp/a11y-axe.js << 'EOF'
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  const routes = process.argv.slice(2).length ? process.argv.slice(2) : ['/'];

  for (const route of routes) {
    try {
      await page.goto(`http://localhost:3000${route}`, { waitUntil: 'networkidle', timeout: 15000 });

      await page.addScriptTag({
        url: 'https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.9.1/axe.min.js'
      });

      const results = await page.evaluate(async () => {
        return await window.axe.run(document, {
          runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] }
        });
      });

      const summary = results.violations.map(v => ({
        id: v.id,
        impact: v.impact,
        description: v.description,
        helpUrl: v.helpUrl,
        nodes: v.nodes.map(n => ({ html: n.html.slice(0, 120), target: n.target }))
      }));

      console.log(JSON.stringify({ route, violations: summary, passes: results.passes.length }, null, 2));
    } catch (err) {
      console.log(JSON.stringify({ route, error: err.message }));
    }
  }

  await browser.close();
})();
EOF

node /tmp/a11y-axe.js 2>/dev/null
```

Parse JSON output. Report each violation with impact level, description, and affected HTML.

**If Playwright is NOT available or dev server is down:**

```
[INFO] Runtime axe-core check skipped (Playwright not available or dev server not running).
Start your dev server and re-run /a11y-audit for runtime checks.
```

---

## Step 3: Check for SkipNav Component

```bash
grep -rn "SkipNav\|skip-nav\|skipnav\|skip-to-content\|skip.*content\|href.*#main" src/ app/ pages/ 2>/dev/null | head -10
```

**PASS** if a skip nav link targeting `#main-content` (or equivalent) exists as the first focusable element.

**FAIL** output:
```
[FAIL] Skip navigation — no skip nav link found
  Impact: Keyboard users must tab through all navigation on every page load.
  Fix: Add <SkipNav /> as the first element in your root layout targeting #main-content.
```

---

## Step 4: Check HTML lang Attribute

```bash
# Check app layout, _document, index.html
grep -rn "lang=" app/layout.tsx app/layout.jsx pages/_document.tsx pages/_document.jsx public/index.html src/index.html 2>/dev/null | head -10
grep -rn '<html' app/ pages/ public/ src/ 2>/dev/null | head -10
```

**PASS** if `<html lang="...">` is present with a valid BCP 47 language tag.

**FAIL** output:
```
[FAIL] HTML lang attribute — <html> element has no lang attribute
  Impact: Screen readers cannot determine document language for correct pronunciation.
  Fix: <html lang="en"> in your root layout.
```

---

## Step 5: Check Focus Styles — No outline:none Without Replacement

```bash
grep -rn "outline.*none\|outline:\s*0\b" src/ app/ --include="*.css" --include="*.scss" --include="*.module.css" --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v "focus-visible" | head -20
```

**PASS** if no `outline: none` found without an accompanying `focus-visible` rule.

**FAIL** output (per occurrence):
```
[FAIL] Focus visible — outline:none suppresses keyboard focus indicators
  File: src/styles/globals.css:42
  Impact: Keyboard users lose all visual indication of which element is focused.
  Fix: Replace `outline: none` with a :focus-visible rule using outline or box-shadow.
```

---

## Step 6: Check Interactive Elements

```bash
# Divs/spans with onClick but no role
grep -rn "onClick=" src/ app/ --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v "button\|role=" | head -15

# Images without alt
grep -rn '<img\b' src/ app/ --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v 'alt=' | head -15

# Inputs without labels
grep -rn '<input\b' src/ app/ --include="*.tsx" --include="*.jsx" 2>/dev/null | grep -v 'aria-label\|aria-labelledby' | head -15
```

Report each finding with file and line number.

---

## Step 7: Generate Report

Print a structured report to the terminal:

```
╔══════════════════════════════════════════════════════╗
║           ACCESSIBILITY AUDIT REPORT                 ║
║           WCAG 2.2 Level AA                          ║
╚══════════════════════════════════════════════════════╝

Project: {project name from package.json}
Date: {today}

CHECKS
------
eslint-plugin-jsx-a11y   [ PASS / FAIL / NOT CONFIGURED ]
axe-core runtime scan    [ PASS / FAIL / SKIPPED        ]
Skip navigation          [ PASS / FAIL                  ]
HTML lang attribute      [ PASS / FAIL                  ]
Focus visible            [ PASS / FAIL                  ]
Interactive elements     [ PASS / FAIL                  ]
Images with alt text     [ PASS / FAIL                  ]
Form inputs with labels  [ PASS / FAIL                  ]

VIOLATIONS ({total} total)
-----------
[critical] {N}
[high]     {N}
[medium]   {N}
[low]      {N}

{Per violation:}
[severity] file:line — description
  WCAG: {criterion}
  Fix: {one-line fix}
```

Then write the full report with code examples to `docs/a11y-audit-{YYYY-MM-DD}.md`.

---

## Rules

- Run ALL six checks regardless of whether earlier checks fail
- NEVER declare PASS on focus styles if `outline: none` exists without `focus-visible`
- ALWAYS report the WCAG 2.2 criterion number alongside each violation
- If axe-core is skipped, note it clearly — don't pretend runtime checks passed
- Sort violations: critical first, then high, medium, low
- Include the line number for every static finding — vague file-level reports are not actionable
