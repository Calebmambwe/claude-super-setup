---
name: visual-verify
description: Launch the app in a browser and visually verify it works using Playwright
---

You are running the visual self-testing pipeline. This mirrors Manus AI's approach: launch the app, interact with it, and verify it works visually.

## Pre-Flight

1. Detect the project type:
   - `package.json` → Node project, look for `dev` script
   - `pyproject.toml` → Python project, look for uvicorn/flask/django
2. Determine the dev server command:
   - Check `package.json` scripts for `dev` or `start`
   - Check `pyproject.toml` for uvicorn config
   - If CLAUDE.md exists, read the Dev command from it
3. Determine the app port and URL:
   - Check CLAUDE.md for port number
   - Check `package.json` dev script for `--port` or `-p` flags
   - Check `.env` or `.env.example` for PORT variable
   - Default: `3000`
   - Store as `{{PORT}}` — use this variable in ALL subsequent steps

## Step 1: Start Dev Server

Use the Bash tool to start the dev server in the background and capture its PID:
```bash
pnpm dev &    # or detected command
DEV_PID=$!
echo $DEV_PID > /tmp/claude-visual-verify-pid
```

Poll until the server is ready (up to 30 seconds):
```bash
PORT={{PORT}}  # resolved from Pre-Flight, default 3000
for i in $(seq 1 15); do
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT)
  [ "$code" = "200" ] && break
  sleep 2
done
if [ "$code" != "200" ]; then
  echo "Dev server failed to start within 30 seconds"
  kill $(cat /tmp/claude-visual-verify-pid) 2>/dev/null || true
  exit 1
fi
```

If the server fails to start, report the error and stop. Do NOT proceed to browser verification.

## Step 2: Browser Verification

Use Playwright MCP tools in sequence:

### 2a: Navigate to the app
Use `mcp__plugin_playwright_playwright__browser_navigate` to open the app URL.

### 2b: Take initial screenshot
Use `mcp__plugin_playwright_playwright__browser_take_screenshot` to capture the landing page.

### 2c: Check for console errors
Use `mcp__plugin_playwright_playwright__browser_console_messages` to capture any JavaScript errors.

### 2d: Get page snapshot
Use `mcp__plugin_playwright_playwright__browser_snapshot` to get the accessibility tree — this shows what's actually rendered.

### 2e: Check network failures
Use `mcp__plugin_playwright_playwright__browser_network_requests` to find any failed API calls (4xx/5xx responses).

## Step 3: Interactive Verification

If $ARGUMENTS specifies user flows, test them. Otherwise, perform basic interaction tests:

### Default flows to test:
1. **Navigation**: Click all visible nav links, verify pages load without errors
2. **Forms**: If any forms are visible, fill them with test data using `browser_fill_form`
3. **Buttons**: Click primary action buttons, check for console errors after each click
4. **Responsive**: Resize to mobile (375x667) using `browser_resize`, take screenshot, then resize back to desktop (1280x720)

For each interaction:
- Take a screenshot after the action
- Check console for new errors
- Check network for failed requests

## Step 4: Report

Generate a report in this format:

```
## Visual Verification Report

### Pages Tested
- [PASS/FAIL] / (landing page) — {notes}
- [PASS/FAIL] /page2 — {notes}

### Console Errors
- {error 1} (on /page)
- {error 2} (on /page)
- None found ✓

### Network Failures
- {method} {url} → {status} (on /page)
- None found ✓

### Interactive Tests
- [PASS/FAIL] Navigation — {details}
- [PASS/FAIL] Forms — {details}
- [PASS/FAIL] Responsive — {details}

### Screenshots
{Describe what each screenshot shows — layout issues, broken styling, etc.}

### Verdict: PASS / FAIL
{Summary of critical issues to fix}
```

## Step 5: Cleanup

Close the browser:
```
Use mcp__plugin_playwright_playwright__browser_close
```

Kill the dev server (using the PID captured at startup):
```bash
kill $(cat /tmp/claude-visual-verify-pid) 2>/dev/null || true
rm -f /tmp/claude-visual-verify-pid
```

## Rules
- ALWAYS start the dev server before attempting Playwright navigation
- ALWAYS check console errors — they reveal runtime bugs invisible in code review
- ALWAYS check network requests — failed API calls are a top source of user-facing bugs
- ALWAYS take screenshots — visual regressions can't be caught by unit tests
- ALWAYS clean up (close browser + kill server) even if verification fails
- If the dev server won't start, diagnose the build error first — don't proceed with a broken build
- If Playwright MCP tools are not available, report that and suggest installing the Playwright plugin
- Port detection: check CLAUDE.md, package.json `dev` script, or default to 3000
