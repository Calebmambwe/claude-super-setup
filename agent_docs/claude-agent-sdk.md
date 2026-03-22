# Claude Agent SDK Reference

Comprehensive reference for building custom agentic tools with the Claude Agent SDK.

## When to Use CLI vs SDK

| Use Case | Tool | Why |
|----------|------|-----|
| Daily dev tasks | Claude Code CLI | Built-in tools, CLAUDE.md, hooks, subagents |
| CI/CD automation | `claude -p` (CLI) | `--output-format json`, `--append-system-prompt` |
| Custom multi-agent pipelines | Agent SDK | Programmatic control, custom MCP tools, streaming |
| RAG-enhanced research agents | Agent SDK | Custom tools + vector DB integration |
| IDE/editor integrations | Agent SDK | Embed Claude in custom UIs |
| One-off scripts | CLI with `--print` | No session overhead, pipe-friendly |

**Rule of thumb:** If `.claude/agents/*.md` can define your subagent, use the CLI. If you need programmatic control over the tool loop, custom MCP tools, or streaming into a custom UI, use the SDK.

## Installation

### TypeScript
```bash
pnpm add @anthropic-ai/claude-agent-sdk
```

### Python
```bash
uv add claude-agent-sdk
```

## Core API

### `query()` — The Main Entry Point

```typescript
import { query, type ClaudeAgentOptions } from "@anthropic-ai/claude-agent-sdk";

const options: ClaudeAgentOptions = {
  prompt: "Research the codebase and summarize the architecture",
  permissionMode: "default", // "default" | "plan" | "acceptEdits" | "bypassPermissions"
  systemPrompt: "You are a senior engineer researching codebases.",
  model: "claude-sonnet-4-6-20250514",
  tools: ["Read", "Grep", "Glob", "WebSearch"],
  maxTurns: 50,
  cwd: process.cwd(),
};

// Streaming — async generator
for await (const message of query(options)) {
  switch (message.type) {
    case "text":
      console.log(message.content);
      break;
    case "tool_use":
      console.log(`Tool: ${message.name}(${JSON.stringify(message.input)})`);
      break;
    case "result":
      console.log("Final:", message.content);
      break;
  }
}
```

### Permission Modes

| Mode | Behavior |
|------|----------|
| `default` | Prompt user for destructive actions |
| `plan` | Require approval before any edits |
| `acceptEdits` | Auto-allow file edits, prompt for Bash |
| `bypassPermissions` | Allow everything (use in containers only!) |

## Multi-Agent Architecture

### Defining Subagents

```typescript
import { query, type AgentDefinition } from "@anthropic-ai/claude-agent-sdk";

const researcher: AgentDefinition = {
  name: "researcher",
  description: "Researches codebases and documentation",
  tools: ["Read", "Grep", "Glob", "WebSearch", "WebFetch"],
  systemPrompt: "You research codebases. Return structured findings.",
  model: "claude-sonnet-4-6-20250514",
};

const implementer: AgentDefinition = {
  name: "implementer",
  description: "Implements code changes based on specifications",
  tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"],
  systemPrompt: "You implement code changes precisely as specified.",
  model: "claude-sonnet-4-6-20250514",
};

for await (const msg of query({
  prompt: "Research the auth module, then add rate limiting",
  agents: [researcher, implementer],
  tools: ["Read", "Grep", "Agent"], // Parent needs Agent tool to spawn subagents
})) {
  // Parent orchestrates, subagents execute
}
```

### Key Constraints
- **Subagents CANNOT spawn subagents** — hierarchy is strictly one level deep
- **Subagents don't inherit parent history** — each starts fresh with its own prompt
- **Context isolation** — subagent results return to parent as a single message
- **Tool renamed:** `Task` was renamed to `Agent` in Claude Code v2.1.63+

## Custom MCP Tools

### TypeScript — `@tool` Decorator

```typescript
import { tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk";

@tool("semantic_search", {
  description: "Search the knowledge base using semantic similarity",
  parameters: {
    query: { type: "string", description: "Search query" },
    top_k: { type: "number", description: "Number of results", default: 5 },
  },
})
async function semanticSearch(query: string, top_k: number = 5) {
  // Your vector DB query here
  const results = await vectorDb.search(query, top_k);
  return results.map(r => `[${r.score.toFixed(2)}] ${r.content}`).join("\n");
}

// Register as MCP server
const server = createSdkMcpServer({
  tools: [semanticSearch],
  name: "my-rag-tools",
});

// Use in query
for await (const msg of query({
  prompt: "Search for authentication patterns",
  mcpServers: [server],
})) {
  // Agent can now call semantic_search
}
```

### Python — `@tool` Decorator

```python
from claude_agent_sdk import query, tool, create_sdk_mcp_server

@tool("semantic_search", description="Search the knowledge base")
async def semantic_search(query: str, top_k: int = 5) -> str:
    results = await vector_db.search(query, top_k)
    return "\n".join(f"[{r.score:.2f}] {r.content}" for r in results)

server = create_sdk_mcp_server(tools=[semantic_search], name="my-rag-tools")

async for msg in query(
    prompt="Search for authentication patterns",
    mcp_servers=[server],
):
    print(msg)
```

## Hooks — Lifecycle Events

Hooks intercept events during the agent loop. Priority: **deny > ask > allow**.

```typescript
import { query, type Hook } from "@anthropic-ai/claude-agent-sdk";

const hooks: Hook[] = [
  {
    event: "PreToolUse",
    matcher: { toolName: "Write" },
    handler: async (event) => {
      // Block writes to .env files
      if (event.input.file_path?.includes(".env")) {
        return { decision: "deny", reason: "Cannot write to .env files" };
      }
      return { decision: "allow" };
    },
  },
  {
    event: "PostToolUse",
    handler: async (event) => {
      console.log(`Tool ${event.toolName} completed in ${event.durationMs}ms`);
      return {};
    },
  },
  {
    event: "Stop",
    handler: async (event) => {
      console.log("Agent completed. Summary:", event.summary);
      return {};
    },
  },
];

for await (const msg of query({
  prompt: "Refactor the auth module",
  hooks,
})) {
  // ...
}
```

### Available Hook Events

| Event | When | Can Modify |
|-------|------|------------|
| `PreToolUse` | Before any tool executes | Allow/deny/modify input |
| `PostToolUse` | After tool returns | Log, modify result |
| `Stop` | Agent decides to stop | Force continue, cleanup |
| `SubagentStart` | Before subagent spawns | Modify prompt, deny |
| `SubagentStop` | After subagent completes | Process result |
| `Notification` | Agent emits a notification | Log, route |

## Sessions — Persist and Resume

```typescript
import { query, type SessionOptions } from "@anthropic-ai/claude-agent-sdk";

// Start a new session
const session = await query({
  prompt: "Start implementing the auth module",
  session: { create: true }, // Creates a persistent session
});

// Resume later (within 30-day retention)
for await (const msg of query({
  prompt: "Continue where we left off — add the rate limiter",
  session: { resume: session.sessionId },
})) {
  // Agent has full context from previous session
}
```

- Sessions persist for **30 days**
- Transcripts stored locally (or configurable storage)
- Resume picks up full conversation history

## CI/CD Integration

### PR Review Automation

```bash
# Review a PR with structured output
claude -p "Review this PR for security issues" \
  --output-format json \
  --append-system-prompt "Focus on OWASP top 10. Return JSON: {issues: [{severity, file, line, description}]}" \
  < <(gh pr diff 123)
```

### Programmatic SDK Usage in CI

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";

const result = [];
for await (const msg of query({
  prompt: `Review this diff for security issues:\n${diff}`,
  tools: ["Read", "Grep"],
  permissionMode: "bypassPermissions", // Safe in CI container
  maxTurns: 10,
})) {
  if (msg.type === "result") result.push(msg.content);
}

// Post review comment
await github.createPRReview(prNumber, result.join("\n"));
```

## Key Gotchas

1. **Subagents don't inherit history** — pass all necessary context in the subagent's prompt
2. **Tool renamed: Task → Agent** — in Claude Code v2.1.63+, the `Task` tool was renamed to `Agent`
3. **Hook priority: deny > ask > allow** — if any hook denies, the action is blocked regardless of other hooks
4. **`bypassPermissions` only in containers** — never use in production with access to real systems
5. **Streaming is mandatory** — `query()` returns an async generator, not a promise. Always iterate
6. **Model IDs are exact** — use `claude-sonnet-4-6-20250514`, not just `sonnet`
7. **MCP servers are per-query** — each `query()` call can have different MCP servers
8. **Max turns prevent runaway agents** — always set `maxTurns` to a reasonable limit (10-50)

## Architecture Patterns

### RAG-Enhanced Agent

```
User Prompt
    │
    ▼
Parent Agent (Opus)
    ├── semantic_search MCP tool → Vector DB
    ├── Researcher Subagent (Sonnet) → codebase analysis
    └── Implementer Subagent (Sonnet) → code changes
```

### CI Review Pipeline

```
PR Event (GitHub Action)
    │
    ▼
claude -p (CLI, --output-format json)
    ├── Security review
    ├── Code quality review
    └── Test coverage analysis
    │
    ▼
Post PR Comment (gh api)
```

### Custom IDE Integration

```
Editor Event (file save, selection)
    │
    ▼
SDK query() with custom UI
    ├── Read/Edit tools
    ├── Custom MCP tools (linter, formatter)
    └── Streaming to editor panel
```
