## Research Brief: Browser Error Monitoring for AI Coding Agent Feedback

---

### 1. Playwright CDP/Console Monitoring

**API signatures verified against Context7 (/microsoft/playwright v1.51.0).**

#### Connect to an already-running browser

Playwright can attach to an existing Chromium instance via CDP. The remote browser must be launched with `--remote-debugging-port=9222`:

```js
const browser = await playwright.chromium.connectOverCDP('http://localhost:9222');
const defaultContext = browser.contexts()[0];
const page = defaultContext.pages()[0];
```

This is the key mechanism for connecting to a dev server's browser without spawning a new one.

#### Console errors

```js
page.on('console', msg => {
  if (msg.type() === 'error') {
    // msg.text() — the error message string
    // msg.location() — { url, lineNumber, columnNumber }
  }
});
```

#### Unhandled exceptions / promise rejections

```js
// BrowserContext-level: catches ALL uncaught errors across all pages in context
browserContext.on('weberror', error => {
  // error.error() returns the Error object with stack
});

// Page-level: same, scoped to one page
page.on('pageerror', error => {
  // error is a standard Error object
});
```

**Critical note:** `weberror` / `pageerror` catch uncaught exceptions and unhandled promise rejections. React hydration errors surface here as unhandled errors or as `console.error` messages — they appear on **both** channels.

#### Network failures

```js
// requestfailed only fires for connection-level failures (net::ERR_*, timeouts)
// It does NOT fire for HTTP 4xx/5xx — those are "successful" HTTP responses
page.on('requestfailed', request => {
  // request.url(), request.failure().errorText
});

// To catch 4xx/5xx, listen to 'response' instead:
page.on('response', response => {
  if (response.status() >= 400) {
    // response.url(), response.status(), response.request().method()
  }
});
```

**Important gotcha:** `requestfailed` does not cover 4xx/5xx. You need `response` event for HTTP errors.

#### Page crash

```js
page.on('crash', () => {
  // page has crashed (OOM etc.)
});
```

#### CDP raw event access

```js
const session = await page.context().newCDPSession(page);
session.on('event', ({ name, params }) => {
  // All raw CDP events — broadest possible coverage
});
```

---

### 2. Next.js Dev Server Error API

**Version in this project: 16.2.1 with React 19.2.4.**

Next.js does NOT expose a clean public API for runtime errors. However, inspecting `node_modules/next/dist/server/dev/hot-reloader-types.js` directly reveals the internal HMR WebSocket message types sent over `ws://localhost:3000/_next/webpack-hmr`:

| Message type | Meaning |
|---|---|
| `serverError` | Server-side compilation/runtime error |
| `ERRORS_TO_SHOW_IN_BROWSER` (enum=1) | Errors the overlay should display |
| `built` / `building` | Compilation lifecycle |
| `turbopack-message` | Turbopack-specific events |
| `reloadPage` | Full reload triggered |

You can tap this WebSocket directly:

```js
const ws = new WebSocket('ws://localhost:3000/_next/webpack-hmr');
ws.on('message', (raw) => {
  const msg = JSON.parse(raw);
  if (msg.action === 'serverError' || msg.action === 'ERRORS_TO_SHOW_IN_BROWSER') {
    // server-side error — build failure, invalid import, etc.
  }
});
```

**Caveats:**
- This is an internal, undocumented API. It has changed across Next.js major versions (message format differed in v12, v13, v14, v15, v16).
- It catches **server-side / compilation** errors, NOT client-side runtime errors (React throws, unhandled promises in browser).
- For browser-side errors you still need a Playwright listener or an in-browser capture mechanism.
- The `__nextjs_original-stack-frames` HTTP endpoint (served at `/_next/__nextjs_original-stack-frames`) maps minified stack frames back to source — useful for post-processing errors caught in the browser.

**Conclusion:** The HMR WebSocket is worth tapping for server/compilation errors. Browser runtime errors require the Playwright approach.

---

### 3. Existing Tools Survey

#### Microsoft Playwright MCP (`@microsoft/playwright-mcp`)
- **What it is:** Official MCP server from Microsoft for browser automation in Claude Code / Cline / Cursor.
- **Console log support:** Added in recent releases via `Playwright_console_logs` tool.
- **Network monitoring:** Yes — captures requests with URL, method, response time.
- **Limitation for this use case:** Designed for interactive agent-driven sessions, not passive background monitoring. Requires an active MCP session. Has a known compatibility bug with Claude Code versions > 0.0.41 (as of March 2026); downgrading to 0.0.41 is the workaround.
- **Verdict:** Not suitable for a PostToolUse background hook — it's a session-interactive tool, not a daemon.

#### ExecuteAutomation Playwright MCP (`@executeautomation/mcp-playwright`)
- Adds `Playwright_console_logs` and screenshot tools on top of Playwright MCP.
- Same session-interactive limitation as microsoft/playwright-mcp.

#### `playwright-consolelogs` / `@Operative-Sh/playwright-consolelogs-mcp`
- Dedicated MCP server for browser log and network request monitoring.
- Exposes console logs (filtered by level: error, warning, info, debug) and network traffic as MCP tools.
- More monitoring-focused than the general Playwright MCP.
- Still an MCP tool called on demand — not a persistent daemon writing to a file.

#### `Operative-Sh/web-eval-agent`
- Python MCP server for autonomous web app evaluation.
- Captures: console logs+errors, network traffic (intelligently filtered), screenshots.
- Uses BrowserUse + Playwright backend.
- Closest existing tool to "autonomous error capture" but designed for task-based evaluation, not continuous monitoring.

#### `ariangibson/playwright-devtools-mcp`
- Specialised CDP-based MCP server with Chrome DevTools access.
- Tools: console capture with filtering, network 4xx/5xx detection, Core Web Vitals, DOM inspection, localStorage.
- Architecture: modular, each tool is self-contained.
- Most feature-complete for debugging scenarios — but still on-demand, not a daemon.

#### `mattiasw/browserloop`
- Screenshot + console log MCP tool.
- Waits 3 seconds after page load before collecting logs (configurable).
- Sanitises sensitive data (API keys, tokens) from logs.
- Not monitoring-focused — snapshot on demand only.

**Gap:** No existing tool implements "persistent background daemon that writes new errors to a file as they happen, for PostToolUse hooks to read." All existing MCP tools are on-demand query tools, not push-based error daemons.

---

### 4. Architecture Options

#### Option A: Playwright CDP daemon — RECOMMENDED

A long-running Node.js script that:
1. Launches Chrome with `--remote-debugging-port=9222` (or connects to existing).
2. Attaches all four Playwright listeners: `console` (errors), `pageerror` (unhandled), `response` (4xx/5xx), `crash`.
3. Appends structured JSON lines to `.claude/browser-errors.jsonl`.
4. Writes a `.claude/browser-errors-last.json` (only the errors since last read, cleared on read).

The PostToolUse hook then:
1. Waits 2–3 seconds (HMR reload window — Next.js 16 with Turbopack is typically < 500ms).
2. Reads `.claude/browser-errors-last.json`.
3. If non-empty: emits `decision: "block"` with the errors as `reason` so Claude sees them.
4. Clears the file after reading (or uses a timestamp watermark).

**Pros:**
- No app source changes required.
- Captures all four error types.
- The daemon is stateless relative to Claude — it just writes; the hook reads.
- Works across page navigations (re-attach on `targetchanged`).

**Cons:**
- Requires Chrome to be launched with `--remote-debugging-port=9222` (one extra flag on `next dev`).
- Daemon must be running before the dev session starts — add to a `package.json` `dev:monitor` script or a `tmux` pane.
- Playwright adds ~50MB to dev dependencies if not already present.

**Start Chrome with CDP enabled (add to package.json or launch script):**
```bash
# Option 1: Use the already-open browser by launching with CDP port
# In your browser profile or alias:
open -a "Google Chrome" --args --remote-debugging-port=9222

# Option 2: Have Playwright launch its own browser automatically
# (daemon handles this — user just runs `node .claude/browser-monitor.js`)
```

#### Option B: Next.js middleware error log — NOT RECOMMENDED for runtime errors

A Next.js middleware or `instrumentation.ts` file can log server-side errors (request failures, SSR throws) to a file. But it cannot capture client-side React errors, hydration failures, or unhandled browser-side promise rejections. **Only covers ~40% of the error surface.** Also violates the "no source changes" constraint.

#### Option C: CDP directly via `ws` (no Playwright dependency) — VIABLE ALTERNATIVE

Skip Playwright entirely and connect via raw WebSocket to the CDP endpoint:
```js
import WebSocket from 'ws';
const ws = new WebSocket('http://localhost:9222/json');
// Then connect to page debugger WebSocket and subscribe to:
// Runtime.exceptionThrown, Log.entryAdded, Network.responseReceived
```

Lighter than Playwright (just `ws` package, ~40kb). More work to implement. Same `--remote-debugging-port=9222` requirement.

#### Option D: React Error Boundary — NOT RECOMMENDED

`<ErrorBoundary onError={postToLocalEndpoint}>` catches React render errors but:
- Requires modifying app source (violates constraint).
- Misses: unhandled promise rejections, network errors, non-React JS errors.
- Cannot be added without touching component tree.

---

### 5. PostToolUse Hook Integration Pattern

Based on reading the actual hook docs and the existing `auto-fix-loop.sh`:

```
File edit (Write/Edit tool)
  → auto-fix-loop.sh fires (typecheck + lint + build)
  → NEW: browser-error-check.sh fires (reads browser error log)
    → If errors found: { "decision": "block", "reason": "Browser errors detected after HMR reload:\n..." }
    → Claude sees errors and fixes them
```

The hook configuration (in `.claude/settings.local.json`):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write(.+\\.(ts|tsx|js|jsx)$)|Edit(.+\\.(ts|tsx|js|jsx)$)",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/browser-error-check.sh",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

The hook script structure (`.claude/hooks/browser-error-check.sh`):

```bash
#!/usr/bin/env bash
# Wait for HMR reload to settle, then check browser error log
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

ERROR_LOG="$PROJECT_ROOT/.claude/browser-errors-last.json"
[ ! -f "$ERROR_LOG" ] && exit 0

# Wait for HMR (Next.js 16 + Turbopack: typically 300-800ms, allow 2s)
sleep 2

ERRORS=$(cat "$ERROR_LOG" 2>/dev/null)
[ -z "$ERRORS" ] || [ "$ERRORS" = "[]" ] && exit 0

# Clear after reading (watermark approach)
echo "[]" > "$ERROR_LOG"

# Feed errors back to Claude
jq -n \
  --argjson errors "$ERRORS" \
  '{
    decision: "block",
    reason: ("Browser runtime errors detected after HMR reload:\n\n" + ($errors | map("- " + .type + ": " + .message + " [" + .url + ":" + (.line|tostring) + "]") | join("\n"))),
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: "Fix the above browser runtime errors before proceeding."
    }
  }'
exit 0
```

---

### Recommendation

**Build Option A: a Playwright CDP daemon + PostToolUse hook.**

Rationale:
- Non-intrusive (no app source changes).
- Captures all error types: `console.error`, unhandled rejections, React hydration errors (surface as `pageerror`), network 4xx/5xx (via `response` event), page crashes.
- Integrates cleanly with the existing PostToolUse hook pattern in `auto-fix-loop.sh`.
- The daemon is a standalone ~80-line Node.js script — no framework, just Playwright.
- The PostToolUse hook is a ~30-line bash script following the exact pattern already in use.

**Implementation checklist for /build:**
1. Write `.claude/browser-monitor.js` — Playwright daemon that connects to Chrome CDP, attaches all listeners, writes to `.claude/browser-errors-last.json`.
2. Write `.claude/hooks/browser-error-check.sh` — PostToolUse hook that reads the log, clears it, and returns structured JSON feedback to Claude.
3. Add `"dev:monitor": "node .claude/browser-monitor.js"` to `package.json` scripts.
4. Add `.claude/browser-errors*.json` to `.gitignore`.
5. Add hook registration to `.claude/settings.local.json` (project-scoped, not global).
6. Document the `--remote-debugging-port=9222` launch requirement in AGENTS.md.

**Alternative if no CDP port:** If Chrome cannot be started with `--remote-debugging-port=9222` (e.g. corporate managed browser), use Option D as a fallback: a tiny `instrumentation.ts` client error handler that POSTs to a local `http://localhost:9223/errors` endpoint (a 10-line express server the daemon also runs). This only adds ~5 lines to the app but does require a source change.

---

### Confidence: High

- Playwright event API signatures verified against Context7 docs (v1.51.0) which matches current Playwright behavior.
- Next.js HMR message types verified by reading `node_modules/next/dist/server/dev/hot-reloader-types.js` directly from the installed v16.2.1.
- PostToolUse hook input/output format verified against official Claude Code docs and cross-referenced with the existing `auto-fix-loop.sh`.
- The `requestfailed` vs `response` distinction (4xx/5xx not in requestfailed) is explicitly documented in Playwright source.

---

### Sources

- Context7 library ID: `/microsoft/playwright` (v1.51.0)
- Playwright CDP connectOverCDP docs
- Playwright page.on('console') docs
- Playwright page.on('requestfailed') docs
- Claude Code Hooks reference
- microsoft/playwright-mcp GitHub
- Operative-Sh/web-eval-agent GitHub
- ariangibson/playwright-devtools-mcp GitHub
- mattiasw/browserloop GitHub
- ExecuteAutomation MCP Playwright console logging docs
