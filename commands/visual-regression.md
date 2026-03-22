Run visual regression check on: $ARGUMENTS

Use the Playwright MCP to capture the current state:

1. Launch headless browser
2. Navigate to each page/route listed in $ARGUMENTS
3. Take full-page screenshots at 1440px width
4. Save to tests/screenshots/current/
5. If tests/screenshots/baseline/ exists:
   - Compare current vs baseline screenshots
   - Report any visual differences
6. If no baseline exists:
   - Save current screenshots as the new baseline
   - Report: "Baseline created for [pages]"
