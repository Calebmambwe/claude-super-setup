# claude:// URI Scheme — VS Code Deep Linking

## 1. URI Scheme Overview

**Scheme:** `claude://`

**Purpose:** Deep link from external tools — Smart Hub dashboard, Telegram messages, browser — directly into Claude Code actions in VS Code. This eliminates the need to manually switch to VS Code, open Claude Code, and type commands when a notification or dashboard link is already telling you what to do next.

**Pattern:**

```
claude://{action}/{resource}/{identifier}?{params}
```

| Part | Description | Example |
|------|-------------|---------|
| `action` | Top-level category | `command`, `task`, `agent`, `pipeline` |
| `resource` | Sub-resource within the action | `plan`, `ghost-status`, `next` |
| `identifier` | Specific instance (optional) | `3`, `auth-module`, `code-reviewer` |
| `params` | Query-string arguments (optional) | `feature=auth-module` |

---

## 2. URI Patterns

### Commands

Trigger Claude Code slash commands directly from external links.

| URI | Equivalent Command | Notes |
|-----|--------------------|-------|
| `claude://command/plan` | `/plan` | Opens Claude Code and starts planning flow |
| `claude://command/build?feature=auth-module` | `/build auth-module` | Passes `feature` param as argument |
| `claude://command/ghost-status` | `/ghost status` | Read-only; no confirmation required |
| `claude://command/check` | `/check` | Runs quality gates (lint, typecheck, tests) |

**Full examples:**

```
claude://command/plan
claude://command/build?feature=auth-module
claude://command/ghost-status
claude://command/check
```

---

### Tasks

Navigate to or act on entries in `tasks.json`.

| URI | Action |
|-----|--------|
| `claude://task/3` | Navigate to task #3 in `tasks.json` and display it |
| `claude://task/3/implement` | Start `/auto-build` for task #3 |
| `claude://task/next` | Pick the next `pending` task (by priority + dependencies) and implement it |

**Full examples:**

```
claude://task/3
claude://task/3/implement
claude://task/next
```

The `implement` sub-action is a CONFIRM-tier operation (see Security section) and will prompt before execution.

---

### Agents

Open or invoke agent definitions from the agent catalog.

| URI | Action |
|-----|--------|
| `claude://agent/verifier` | Open the verifier agent definition in the editor |
| `claude://agent/code-reviewer/run` | Invoke the `code-reviewer` agent |
| `claude://team/review` | Activate the `review` team preset (all agents in that team) |

**Full examples:**

```
claude://agent/verifier
claude://agent/code-reviewer/run
claude://team/review
```

Agent names map directly to entries in `agents/catalog.json`. If the agent does not exist in the catalog the handler surfaces an error rather than failing silently.

---

### Pipeline

Inspect and interact with the autonomous pipeline.

| URI | Action |
|-----|--------|
| `claude://pipeline/status` | Show pipeline dashboard (`/pipeline-status`) |
| `claude://pipeline/latest-pr` | Open the most recent PR created by ghost mode |
| `claude://pipeline/metrics` | Show metrics dashboard |

**Full examples:**

```
claude://pipeline/status
claude://pipeline/latest-pr
claude://pipeline/metrics
```

---

## 3. VS Code URI Handler Registration

The handler is registered via the Claude Code VS Code extension.

### package.json contribution

```json
{
  "contributes": {
    "uriHandler": true
  }
}
```

Declaring `uriHandler: true` causes VS Code to route any `vscode://` URI prefixed with the extension's identifier — and any registered custom scheme — to the extension's `UriHandler` implementation.

### Handler implementation (TypeScript sketch)

```typescript
import * as vscode from 'vscode';

export class ClaudeUriHandler implements vscode.UriHandler {
  handleUri(uri: vscode.Uri): void {
    // uri.path = "/{action}/{resource}/{identifier}"
    const segments = uri.path.replace(/^\//, '').split('/');
    const [action, resource, identifier] = segments;
    const params = new URLSearchParams(uri.query);

    const handler = ALLOWED_ACTIONS[action]?.[resource];
    if (!handler) {
      vscode.window.showWarningMessage(
        `claude:// — unknown action: ${action}/${resource}`
      );
      return;
    }

    handler({ identifier, params });
  }
}

// Register in activate()
context.subscriptions.push(
  vscode.window.registerUriHandler(new ClaudeUriHandler())
);
```

### Parsing model

| Component | Source | Example value |
|-----------|--------|---------------|
| `action` | `uri.path` segment 0 | `task` |
| `resource` | `uri.path` segment 1 | `3` |
| `identifier` | `uri.path` segment 2 | `implement` |
| `params` | `uri.query` (URL-encoded) | `feature=auth-module` |

### Fallback behaviour

If the action is not in the allowlist, the handler opens the Claude Code panel without running any command — so the user lands in a useful state rather than seeing a hard error.

---

## 4. Security

### Allowlist

Only explicitly registered action paths are executed. The handler maintains a static map:

```typescript
const ALLOWED_ACTIONS: Record<string, Record<string, ActionHandler>> = {
  command: { plan, build, 'ghost-status', check },
  task:    { /* numeric ids resolved at runtime */, next },
  agent:   { /* catalog-validated at runtime */ },
  team:    { review, /* other registered presets */ },
  pipeline:{ status, 'latest-pr', metrics },
};
```

Any URI that does not resolve to an entry in this map is rejected before any code runs.

### No arbitrary command execution

URIs cannot pass raw shell commands or arbitrary CLI arguments. The `params` map is validated against a per-action schema; unknown keys are dropped.

### Confirmation tier

Actions with side effects require user confirmation before proceeding — mirroring the CONFIRM tier used in the Telegram dispatch system:

| Tier | Examples | Behaviour |
|------|----------|-----------|
| Read-only | `pipeline/status`, `agent/verifier` | Execute immediately |
| CONFIRM | `task/{id}/implement`, `agent/{name}/run`, `command/build` | Show VS Code confirmation dialog |
| Blocked | Any URI not in the allowlist | Rejected with warning |

### Untrusted sources

URIs arriving from a browser, email client, or any source outside the Smart Hub dashboard are treated as untrusted. The handler inspects `uri.authority` (the origin hint VS Code passes when available) and applies the following policy:

- **Trusted origins** (Smart Hub, Telegram bot webhook): confirmation only for CONFIRM-tier actions.
- **Untrusted origins**: confirmation dialog for ALL actions, including read-only ones, and the dialog explicitly names the source.

### Rate limiting

A sliding-window counter enforces a maximum of **5 URI invocations per minute** across all sources. Invocations beyond the limit are queued and retried after the window expires, with a VS Code status-bar indicator showing the queue depth.

---

## 5. Smart Hub Integration

The Smart Hub dashboard (`http://localhost:7334`) renders `claude://` URIs as clickable links throughout its UI.

### Link placement

| Dashboard element | URI rendered |
|-------------------|-------------|
| Task card | `claude://task/{id}/implement` |
| Task card (view only) | `claude://task/{id}` |
| Pipeline status widget | `claude://pipeline/status` |
| Agent card | `claude://agent/{name}` |
| Agent card "Run" button | `claude://agent/{name}/run` |
| Team preset card | `claude://team/{name}` |
| Latest PR row | `claude://pipeline/latest-pr` |
| Metrics panel | `claude://pipeline/metrics` |

### Telegram deep links

When the Telegram bot sends a notification — task complete, pipeline blocked, review requested — it appends a `claude://` URI so the recipient can act in one tap:

```
Task #7 is ready to implement.
→ claude://task/7/implement
```

Telegram renders the URI as a plain-text link. On a desktop with VS Code installed and the extension active, clicking it routes directly to the handler.

### Rendering helper (dashboard)

```typescript
function claudeLink(action: string, ...segments: string[]): string {
  const path = [action, ...segments].filter(Boolean).join('/');
  return `claude://${path}`;
}

// Usage
claudeLink('task', String(task.id), 'implement');  // "claude://task/7/implement"
claudeLink('pipeline', 'status');                  // "claude://pipeline/status"
```

---

## 6. Implementation Notes

### VS Code API entry point

```typescript
vscode.window.registerUriHandler(handler: vscode.UriHandler): vscode.Disposable
```

The `UriHandler` interface requires a single method:

```typescript
interface UriHandler {
  handleUri(uri: Uri): ProviderResult<void>;
}
```

VS Code calls `handleUri` whenever the OS routes a URI with the matching scheme to VS Code.

### Invoking Claude Code CLI from the handler

The extension invokes Claude Code via two mechanisms depending on whether the VS Code extension API is available:

1. **Extension API (preferred):** Call the Claude Code extension's exported `runCommand(command: string): Promise<void>` API directly — no subprocess, no shell injection risk.
2. **Subprocess fallback:** Spawn `claude <command>` as a child process using `child_process.execFile` with a fixed argument array (never a shell string). Arguments are taken from the validated params map, never from raw URI text.

### Param encoding

Query params follow standard URL encoding. Multi-word values use `%20` or `+`:

```
claude://command/build?feature=auth%20module
claude://task/next?priority=high
```

The handler decodes params with `new URLSearchParams(uri.query)` before validation.

### Adding a new URI action

1. Define a handler function typed as `ActionHandler`.
2. Add it to the `ALLOWED_ACTIONS` map under the appropriate action/resource key.
3. Declare its confirmation tier (read-only vs. CONFIRM).
4. Add a test case to `src/uri-handler.test.ts` covering both the happy path and a malformed URI.
5. Update this document.

No other files need to change.
