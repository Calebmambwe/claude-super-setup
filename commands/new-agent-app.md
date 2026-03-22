---
name: new-agent-app
description: Scaffold a new Claude Agent SDK project for building custom agentic tools
---
Scaffold a new Claude Agent SDK project: $ARGUMENTS

## Step 1: Parse Arguments

Extract from the arguments:
- **Project name** (required)
- **Variant** — `ts` (TypeScript) or `python` (default: `ts`)

If project name is missing, ask for it. Parse both `new-agent-app my-agent ts` and `new-agent-app ts my-agent`.

**Validate PROJECT_NAME:** Must match `^[a-zA-Z0-9_-]+$`. Reject anything else.

## Step 2: Scaffold Project

### TypeScript variant:
```bash
mkdir -p {project-name} && cd {project-name}
pnpm init
pnpm add @anthropic-ai/claude-agent-sdk
pnpm add -D typescript @types/node tsx vitest
```

Create `tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "esModuleInterop": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "sourceMap": true,
    "skipLibCheck": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

### Python variant:
```bash
mkdir -p {project-name} && cd {project-name}
uv init
uv add claude-agent-sdk
uv add --dev pytest ruff mypy
```

## Step 3: Create Starter Files

### Directory structure:
```
src/
  index.ts (or main.py)     — main agent entry point
  agents/
    researcher.ts            — example research subagent
    implementer.ts           — example implementation subagent
  tools/
    search.ts                — example custom MCP tool
  hooks/
    permissions.ts           — example lifecycle hooks
```

### src/index.ts (TypeScript)
```typescript
import { query, type ClaudeAgentOptions, type AgentDefinition } from "@anthropic-ai/claude-agent-sdk";
import { researcher } from "./agents/researcher.js";
import { implementer } from "./agents/implementer.js";
import { searchServer } from "./tools/search.js";
import { permissionHooks } from "./hooks/permissions.js";

async function main() {
  const prompt = process.argv[2];
  if (!prompt) {
    console.error("Usage: tsx src/index.ts \"your prompt here\"");
    process.exit(1);
  }

  const options: ClaudeAgentOptions = {
    prompt,
    agents: [researcher, implementer],
    mcpServers: [searchServer],
    hooks: permissionHooks,
    tools: ["Read", "Grep", "Glob", "Agent"],
    permissionMode: "default",
    maxTurns: 30,
    cwd: process.cwd(),
  };

  for await (const message of query(options)) {
    switch (message.type) {
      case "text":
        process.stdout.write(message.content);
        break;
      case "tool_use":
        console.log(`\n[tool] ${message.name}`);
        break;
      case "result":
        console.log("\n[done]", message.content);
        break;
    }
  }
}

main().catch(console.error);
```

### src/main.py (Python)
```python
import sys
import asyncio
from claude_agent_sdk import query
from agents.researcher import researcher
from agents.implementer import implementer
from tools.search import search_server
from hooks.permissions import permission_hooks

async def main():
    if len(sys.argv) < 2:
        print("Usage: python src/main.py 'your prompt here'", file=sys.stderr)
        sys.exit(1)

    prompt = sys.argv[1]

    async for message in query(
        prompt=prompt,
        agents=[researcher, implementer],
        mcp_servers=[search_server],
        hooks=permission_hooks,
        tools=["Read", "Grep", "Glob", "Agent"],
        permission_mode="default",
        max_turns=30,
    ):
        match message.type:
            case "text":
                print(message.content, end="", flush=True)
            case "tool_use":
                print(f"\n[tool] {message.name}")
            case "result":
                print(f"\n[done] {message.content}")

if __name__ == "__main__":
    asyncio.run(main())
```

### src/agents/researcher.ts
```typescript
import type { AgentDefinition } from "@anthropic-ai/claude-agent-sdk";

export const researcher: AgentDefinition = {
  name: "researcher",
  description: "Researches codebases, documentation, and the web for information",
  tools: ["Read", "Grep", "Glob", "WebSearch", "WebFetch"],
  systemPrompt: `You are a senior engineer who researches codebases and documentation.
Return structured findings with file paths, code snippets, and explanations.
Always cite the source file and line number for code references.`,
  model: "claude-sonnet-4-6-20250514",
};
```

### src/agents/implementer.ts
```typescript
import type { AgentDefinition } from "@anthropic-ai/claude-agent-sdk";

export const implementer: AgentDefinition = {
  name: "implementer",
  description: "Implements code changes based on specifications",
  tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"],
  systemPrompt: `You are a senior engineer who implements code changes precisely as specified.
Follow existing patterns in the codebase. Write tests alongside implementation.
Never use 'any' type in TypeScript. Validate inputs at system boundaries with Zod.`,
  model: "claude-sonnet-4-6-20250514",
};
```

### src/tools/search.ts
```typescript
import { tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk";

@tool("semantic_search", {
  description: "Search the project knowledge base using semantic similarity",
  parameters: {
    query: { type: "string", description: "Search query" },
    top_k: { type: "number", description: "Number of results to return", default: 5 },
  },
})
async function semanticSearch(query: string, top_k: number = 5): Promise<string> {
  // TODO: Replace with your vector DB integration
  // Options: Pinecone, Qdrant, ChromaDB, or local FAISS
  return `[placeholder] No vector DB configured yet. Query: "${query}", top_k: ${top_k}`;
}

export const searchServer = createSdkMcpServer({
  tools: [semanticSearch],
  name: "project-search",
});
```

### src/hooks/permissions.ts
```typescript
import type { Hook } from "@anthropic-ai/claude-agent-sdk";

export const permissionHooks: Hook[] = [
  {
    event: "PreToolUse",
    matcher: { toolName: "Write" },
    handler: async (event) => {
      // Block writes to sensitive files
      const blockedPatterns = [".env", "credentials", "secret", ".pem", ".key"];
      const filePath = event.input.file_path || "";
      if (blockedPatterns.some((p) => filePath.toLowerCase().includes(p))) {
        return { decision: "deny", reason: `Blocked write to sensitive file: ${filePath}` };
      }
      return { decision: "allow" };
    },
  },
  {
    event: "PostToolUse",
    handler: async (event) => {
      // Log all tool usage for debugging
      const timestamp = new Date().toISOString();
      console.error(`[${timestamp}] Tool: ${event.toolName}, Duration: ${event.durationMs}ms`);
      return {};
    },
  },
  {
    event: "Stop",
    handler: async (event) => {
      console.error("\n--- Agent Session Summary ---");
      console.error(`Turns: ${event.turnCount}`);
      console.error(`Tools used: ${event.toolsUsed?.join(", ") || "none"}`);
      return {};
    },
  },
];
```

Create equivalent Python files for the Python variant following the same patterns.

## Step 4: Create CLAUDE.md

```markdown
# CLAUDE.md — {project-name}

## Project
- Name: {project-name}
- Type: Claude Agent SDK application
- Language: {TypeScript/Python}

## Commands
- Run: `pnpm tsx src/index.ts "your prompt"` / `uv run python src/main.py "your prompt"`
- Test: `pnpm test` / `uv run pytest`
- Typecheck: `pnpm tsc --noEmit` / `uv run mypy .`

## Architecture
```
src/
  index.ts        — main agent orchestrator
  agents/         — subagent definitions (researcher, implementer)
  tools/          — custom MCP tools (semantic_search)
  hooks/          — lifecycle hooks (permissions, logging)
```

## Key Patterns
- Parent agent orchestrates, subagents execute specific tasks
- Subagents CANNOT spawn subagents — hierarchy is one level deep
- Custom MCP tools extend agent capabilities (vector search, APIs, etc.)
- Hooks intercept lifecycle events (PreToolUse, PostToolUse, Stop)
- Priority: deny > ask > allow for permission hooks

## References
- SDK API: ~/.claude/agent_docs/claude-agent-sdk.md
- CLI vs SDK decision matrix in the reference doc above
```

## Step 5: Create .env.example

```
# Anthropic API key (required)
ANTHROPIC_API_KEY=sk-ant-...

# Or use AWS Bedrock:
# CLAUDE_CODE_USE_BEDROCK=1
# AWS_REGION=us-east-1

# Or use Google Vertex:
# CLAUDE_CODE_USE_VERTEX=1
# CLOUD_ML_REGION=us-east5
```

## Step 6: Create .gitignore

```
node_modules/
dist/
.env
.env.*
!.env.example
__pycache__/
*.pyc
.mypy_cache/
.ruff_cache/
.venv/
```

## Step 7: Git + GitHub

```bash
git init
git add -A
git commit -m "feat: scaffold {project-name} with Claude Agent SDK

Includes: orchestrator, 2 subagents, custom MCP tool, lifecycle hooks
Generated with Claude Code /new-agent-app command

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

gh repo create {project-name} --private --source . --push
```

## Step 8: Summary

```
Agent App Created: {project-name}

Stack: Claude Agent SDK ({ts/python})

Files:
  src/index.ts          — main agent entry point
  src/agents/           — subagent definitions (researcher, implementer)
  src/tools/            — custom MCP tools (semantic_search)
  src/hooks/            — lifecycle hooks (permissions, logging)
  CLAUDE.md             — project guidance
  .env.example          — auth config

Run:
  Dev:   pnpm tsx src/index.ts "your prompt here"
  Test:  pnpm test

Next steps:
  1. Copy .env.example to .env and add your ANTHROPIC_API_KEY
  2. Customize the subagents in src/agents/
  3. Replace the placeholder in src/tools/search.ts with your vector DB
  4. Run: pnpm tsx src/index.ts "research the codebase"
```

## Rules
- ALWAYS use the Agent SDK, not raw Anthropic Client SDK — the SDK manages the tool loop
- ALWAYS use Context7 to verify SDK API signatures before scaffolding
- NEVER hardcode API keys — use .env + environment variables
- Subagents CANNOT spawn subagents — keep hierarchy flat (one level deep)
- Include at least one custom MCP tool example — this is the SDK's killer feature
- ALWAYS set maxTurns to prevent runaway agents
- Use `claude-sonnet-4-6-20250514` for subagents (cost-effective), Opus for orchestrator if needed
- Hook priority: deny > ask > allow — if any hook denies, the action is blocked
