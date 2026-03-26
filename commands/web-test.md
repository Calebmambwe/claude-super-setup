---
name: web-test
description: Run browser-based E2E tests using Playwright against the local dev server for specified user flows
---
Run browser-based E2E tests for: $ARGUMENTS

Use the Playwright MCP to test the running application:

1. Launch a headless browser
2. Navigate to the local dev server (http://localhost:3000 or http://localhost:8000)
3. For each user flow described in $ARGUMENTS:
   a. Navigate to the starting page
   b. Interact with elements (click, type, select)
   c. Take a screenshot at each key step -- save to tests/screenshots/
   d. Verify expected elements are visible (wait for selectors)
   e. Verify text content matches expectations
   f. Check for console errors
4. Test responsive behavior:
   a. Repeat critical flows at 375px (mobile), 768px (tablet), 1440px (desktop)
   b. Screenshot each breakpoint
5. Report results: which flows passed, which failed, with screenshots

If any flow fails, describe what went wrong and suggest fixes.
