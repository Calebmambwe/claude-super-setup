# Feature Brief: Browser Error Monitor

**Created:** 2026-03-26
**Status:** Draft

---

## Problem

When Claude Code edits frontend files, the existing auto-fix-loop hook catches compile-time errors (TypeScript, lint, build), but **runtime browser errors go completely undetected**. React hydration failures, unhandled promise rejections, console.error calls, network 4xx/5xx responses, and page crashes only surface when a human manually opens the browser and checks the console. This creates a blind spot where Claude declares a task "done" while the app is visibly broken in the browser. The developer must manually copy-paste browser errors back into the conversation, breaking the autonomous development loop.

---

## Proposed Solution

A two-part system that closes the runtime error feedback loop:

1. **Browser Monitor Daemon** (`browser-monitor.js`) — A long-running Playwright script that connects to Chrome via CDP (`--remote-debugging-port=9222`), attaches listeners for all five error categories (console.error, pageerror/weberror, HTTP 4xx/5xx responses, request failures, page crashes), taps the Next.js HMR WebSocket for server/compilation errors, and writes structured errors to a JSON file. Includes error deduplication, rate limiting, and optional screenshot capture on error.

2. **PostToolUse Hook** (`browser-error-check.sh`) — Fires after every file edit, waits for HMR to settle (~2s), reads the error log, and feeds any new errors back to Claude as a block decision with structured error details. Claude then fixes the runtime errors before proceeding.

The daemon auto-starts alongside `pnpm dev` and requires no app source code changes.

---

## Target Users

**Primary:** Claude Code users doing frontend development — the agent itself is the consumer of the error data, enabling autonomous runtime error fixing.

**Secondary:** Any developer using Claude Code who wants to catch browser errors without manually checking the console.

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Technical | Chrome must be launched with `--remote-debugging-port=9222`; Playwright required as dev dependency |
| Location | Lives in `claude-super-setup` — reusable across all projects, not project-specific |
| Integration | Must follow existing PostToolUse hook patterns (same as `auto-fix-loop.sh` and `test-after-impl.sh`) |
| Non-intrusive | Zero app source code changes required — purely external monitoring |
| Stack | Node.js daemon + bash hook; Playwright CDP for browser connection |

---

## Scope

### In Scope
- Playwright CDP daemon connecting to Chrome on port 9222
- Console.error capture with source location
- Unhandled exception / promise rejection capture (pageerror + weberror)
- HTTP 4xx/5xx response detection (via `response` event, not `requestfailed`)
- Network connection failure detection (via `requestfailed`)
- Page crash detection
- Next.js HMR WebSocket tap for server/compilation errors
- Screenshot capture on error (saved alongside error log)
- Auto-start daemon with `pnpm dev` (package.json script integration)
- Error deduplication (same error within 5s window = 1 report)
- Rate limiting (max N errors per hook invocation to avoid flooding Claude)
- PostToolUse hook that reads error log after HMR settle time
- Debounce logic matching auto-fix-loop.sh pattern
- Global installation via claude-super-setup (works across all projects)

### Out of Scope
- Performance monitoring / Core Web Vitals (separate concern)
- Visual regression testing (existing /visual-regression skill handles this)
- Browser extension approach (CDP is sufficient)
- React Error Boundary injection (requires source changes)
- Support for non-Chromium browsers (Firefox/Safari CDP not stable enough)
- Production error monitoring (this is dev-only)

---

## Feature Name

**Kebab-case identifier:** `browser-error-monitor`

**Folder:** `docs/browser-error-monitor/`

---

## Notes

- Research brief at `docs/research/research-browser-monitor.md` covers all architecture options and API verification
- Playwright event API signatures verified against Context7 (v1.51.0)
- Key gotcha: `requestfailed` does NOT fire for HTTP 4xx/5xx — must use `response` event
- Next.js HMR WebSocket (`ws://localhost:3000/_next/webpack-hmr`) provides `serverError` messages but only covers server-side errors
- No existing MCP server or tool does persistent background browser monitoring — this is a novel capability
- The daemon should handle page navigation gracefully (re-attach listeners on new pages)
- Consider adding a `/browser-monitor` skill command to start/stop/status the daemon

---

## PR/FAQ: Browser Error Monitor

### Press Release

**San Francisco, March 2026** — Claude Super Setup today announced Browser Error Monitor, a new developer tool that enables AI coding agents to automatically detect and fix browser runtime errors during development. Starting immediately, developers can close the last major gap in autonomous frontend development.

When AI coding agents edit frontend code, they can catch TypeScript errors and lint violations through existing tooling. But runtime errors — the React hydration failure that breaks the page, the unhandled promise rejection from a bad API call, the 500 response from a misconfigured endpoint — remain invisible to the agent. The developer has to manually open the browser, check the console, copy the error, and paste it back into the conversation. This breaks the autonomous development loop and turns what should be a seamless fix-cycle into a manual back-and-forth.

"I'd kick off an auto-dev run and come back to find Claude had 'completed' the task, but the page was completely broken in the browser. I'd spend 10 minutes copy-pasting console errors back and forth before things actually worked," said Caleb, a developer using Claude Code daily. "Now the agent sees what I see in the browser — it fixes runtime errors the same way it fixes TypeScript errors, automatically."

Browser Error Monitor works by running a lightweight Playwright daemon alongside your dev server. It connects to Chrome via the Chrome DevTools Protocol and listens for five categories of errors: console.error messages, unhandled exceptions and promise rejections, HTTP 4xx/5xx responses, network failures, and page crashes. It also taps the Next.js HMR WebSocket for server-side compilation errors. After every file edit, a PostToolUse hook checks for new browser errors and feeds them directly back to the AI agent with full stack traces and source locations.

Unlike existing browser monitoring MCP tools (which require the agent to explicitly query for errors), Browser Error Monitor is push-based — errors are detected passively and reported automatically. The agent never needs to "remember" to check the browser. And unlike React Error Boundaries or custom middleware, it requires zero changes to your application code.

To get started, run `node ~/.claude/hooks/browser-monitor.js` alongside your dev server, or add it to your `package.json` dev script. Chrome must be launched with `--remote-debugging-port=9222`.

### Frequently Asked Questions

**Customer FAQs:**

**Q: Who is this for?**
A: Developers using Claude Code (or similar AI coding agents) for frontend work who want the agent to automatically detect and fix runtime browser errors without manual copy-pasting.

**Q: How is this different from the Playwright MCP server?**
A: Playwright MCP is on-demand — the agent must explicitly call a tool to check browser state. Browser Error Monitor is push-based — it runs in the background and automatically reports errors after every file edit. The agent never needs to "remember" to check.

**Q: What does it cost?**
A: Free, open source, included in claude-super-setup. Requires Playwright as a dev dependency (~50MB).

**Q: What if I don't like it?**
A: Remove the PostToolUse hook entry from settings.json and stop the daemon. Zero residual changes to your project.

**Q: When will it be available?**
A: Targeting completion within 1 sprint (6 days) of starting /auto-dev.

**Internal/Technical FAQs:**

**Q: How long will this take to build?**
A: 2-3 milestones: (1) daemon + basic hook, (2) HMR tap + screenshots + dedup, (3) auto-start integration + global install. Roughly 1 sprint.

**Q: What are the biggest risks?**
A: (1) Chrome CDP connection reliability — daemon must handle Chrome restarts and page navigations gracefully. (2) HMR settle timing — too short misses errors, too long slows the feedback loop. (3) Error noise — some apps produce benign console.error spam that could flood Claude with false positives.

**Q: What are we NOT building?**
A: Production monitoring, performance tracking, visual regression, non-Chromium support, or anything requiring app source changes.

**Q: How will we measure success?**
A: (1) Runtime errors caught per session that would have been missed without the monitor. (2) Reduction in manual "paste browser error" messages from developer to Claude. (3) Zero false-positive rate on error deduplication (no duplicate reports for the same error).

**Q: What's the rollback plan?**
A: Remove the hook entry from settings.json. The daemon is a standalone process with no side effects on the project.
