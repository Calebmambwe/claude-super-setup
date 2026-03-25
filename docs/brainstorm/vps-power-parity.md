# Brainstorm: VPS Power Parity + AgentOS as Full Autonomous Coding Agent

**Date:** 2026-03-25
**Goal:** Make the VPS agent AND AgentOS as powerful as the local Mac Claude Code — full mirror image with all MCPs, tools, settings, hooks, agents, and skills. AgentOS should be a fully autonomous coding agent (like Manus).

---

## Current State: Mac vs VPS Gap Analysis

### What's ALREADY the same:
| Component | Mac | VPS | Parity? |
|-----------|-----|-----|---------|
| settings.json | 148 permissions, 8 hooks | 149 permissions, 8 hooks | YES |
| CLAUDE.md | Full global config | Full global config | YES |
| Agents (50+) | All in ~/.claude/agents/ | All in ~/.claude/agents/ | YES |
| Commands (86+) | All in ~/.claude/commands/ | All in ~/.claude/commands/ | YES |
| Hooks (17) | All in ~/.claude/hooks/ | All in ~/.claude/hooks/ | YES |
| Plugins | claude-plugins-official | claude-plugins-official | YES |
| Learning server | learning-server.py | learning-server.py | YES |
| Sandbox server | sandbox-server.py | sandbox-server.py | YES |
| Telegram | Mac bot (separate token) | VPS bot (separate token) | YES |

### What's MISSING on VPS:

| Component | Mac | VPS | Gap |
|-----------|-----|-----|-----|
| **Gmail MCP** | Connected via claude.ai | Not available | HIGH |
| **Google Calendar MCP** | Connected via claude.ai | Not available | HIGH |
| **GitHub MCP** | Connected via claude.ai | Not available | HIGH |
| **Context7 MCP** | Available | Not configured | HIGH |
| **Memory MCP** | Knowledge graph server | Not running | MEDIUM |
| **Sequential Thinking MCP** | Available | Not configured | LOW |
| **Playwright MCP** | Auto-installed | Installed but stale | LOW |
| **API Keys (.env.local)** | Manus, Gemini, OpenAI | Only in .claude/.env | MEDIUM |
| **gh CLI auth** | Authenticated | Unknown | HIGH |
| **Docker** | Running | Running | OK |

---

## The Three Sync Strategies

### Strategy 1: Config Sync Script (Quick Win)
Copy all config files from Mac to VPS via SSH/git.

**What it syncs:**
- `settings.json` → exact copy
- `.mcp.json` → adapted for VPS paths
- `CLAUDE.md` → exact copy
- `.env.local` → API keys (Manus, Gemini, OpenAI)
- `hooks/` → exact copy
- `commands/` → exact copy
- `agents/` → exact copy
- `rules/` → exact copy

**Limitations:**
- Claude.ai integrations (Gmail, Calendar, GitHub MCP) are OAuth-bound to the browser session
- These can't be "synced" — they're managed through claude.ai/settings
- VPS needs its own OAuth tokens for these services

### Strategy 2: MCP Server Self-Hosting (Full Power)
Instead of relying on claude.ai OAuth integrations, run our own MCP servers.

**Self-hosted MCP servers to deploy:**
1. **GitHub MCP** → `npx @modelcontextprotocol/server-github` (needs GITHUB_TOKEN env var)
2. **Context7 MCP** → `npx @upstash/context7-mcp@latest` (free, no auth needed)
3. **Memory MCP** → `npx @modelcontextprotocol/server-memory` (local knowledge graph)
4. **Sequential Thinking** → `npx @modelcontextprotocol/server-sequential-thinking`
5. **Filesystem MCP** → `npx @modelcontextprotocol/server-filesystem` (expanded file access)
6. **Gmail MCP** → Requires Google OAuth — need service account or OAuth flow
7. **Calendar MCP** → Same as Gmail — requires Google OAuth

**Advantage:** These run locally on VPS, no dependency on claude.ai browser session.
**Note:** Gmail/Calendar require Google Cloud project + service account credentials.

### Strategy 3: Hybrid (Recommended)
- **Config Sync** for settings, hooks, commands, agents (Strategy 1)
- **Self-hosted MCP** for GitHub, Context7, Memory, Sequential Thinking (Strategy 2)
- **Claude.ai OAuth** for Gmail and Calendar (manual setup once, tokens persist)

---

## Implementation: The Sync Script

### `scripts/sync-to-vps.sh`

A single command that mirrors the Mac config to VPS:

```bash
#!/usr/bin/env bash
# Syncs local Claude Code config to VPS for power parity
# Usage: bash scripts/sync-to-vps.sh [--dry-run]

# What gets synced:
# 1. settings.json (permissions, hooks, env vars)
# 2. .mcp.json (MCP server configs, adapted for VPS paths)
# 3. CLAUDE.md (global instructions)
# 4. API keys (.env.local → .claude/.env on VPS)
# 5. All hooks, commands, agents, rules, skills
# 6. MCP server scripts (learning-server.py, etc.)

# What gets INSTALLED (not just copied):
# 7. Context7 MCP server
# 8. GitHub MCP server (with gh auth)
# 9. Memory MCP server
# 10. Sequential Thinking MCP server
```

### VPS MCP Config (what .mcp.json should look like on VPS)

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "code-review-graph": {
      "command": "uvx",
      "args": ["code-review-graph", "serve"]
    },
    "knowledge-rag": {
      "command": "npx",
      "args": ["-y", "knowledge-rag", "serve"],
      "env": {
        "KNOWLEDGE_RAG_DIR": "./docs:./agent_docs",
        "KNOWLEDGE_RAG_EXTENSIONS": ".md,.mdx,.txt,.yaml,.yml"
      }
    },
    "learning": {
      "command": "python3",
      "args": ["/home/claude/.claude/mcp-servers/learning-server.py"],
      "env": {
        "OPENAI_API_KEY": "${OPENAI_API_KEY}"
      }
    },
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
```

---

## AgentOS: Full Autonomous Coding Agent

AgentOS (the web UI at manus-clone on VPS) should be MORE than a chat interface — it should be a full autonomous coding agent like Manus. Here's how:

### Current AgentOS State:
- Next.js frontend + FastAPI backend
- PostgreSQL + Redis via Docker Compose
- Backend health: OK (after restart)
- Chat: needs wiring to Claude API
- Agent execution: not implemented
- Sandbox: not implemented
- Connectors: not implemented

### What Makes Manus a Full Coding Agent:

1. **Sandbox execution** — Docker containers for code execution
2. **Browser automation** — Playwright for web tasks
3. **File system access** — read/write project files
4. **Shell execution** — run commands in sandbox
5. **Multi-step planning** — Plan-Execute-Verify loop
6. **Tool use** — 28+ tools (code, browser, files, search, etc.)
7. **Persistent workspace** — files survive across messages
8. **Live preview** — see what the agent built (artifacts)

### How to Make AgentOS This Powerful:

**Option A: Wire AgentOS to Claude Code CLI**
AgentOS backend calls `claude -p` (headless Claude Code) for each task.
- Gets ALL the power of our 86 commands, 50+ agents, MCPs, hooks
- AgentOS is just the UI wrapper
- Each task spawns a `claude -p "task"` subprocess
- Results streamed back via SSE

**Option B: Wire AgentOS to Claude API + MCP**
AgentOS backend calls Claude API directly with MCP tools.
- More control over the conversation
- Can implement custom tool use loop
- Needs to re-implement tool handling that Claude Code already does

**Option C: Hybrid (Recommended)**
- Simple tasks → Claude API with MCP tools (fast, cheap)
- Complex tasks → Spawn `claude -p` with full Claude Code power
- Autonomous mode → Spawn `claude --dangerously-skip-permissions -p "/auto-dev feature"`

### AgentOS Architecture for Autonomous Coding:

```
User (browser) → AgentOS Frontend (Next.js)
                     ↓
              AgentOS Backend (FastAPI)
                     ↓
              Task Router
              ├── Simple query → Claude API + streaming
              ├── Code task → claude -p "implement X" (Claude Code CLI)
              ├── Autonomous → claude -p "/auto-dev X" (full pipeline)
              └── Research → claude -p "/bmad:research X"
                     ↓
              Docker Sandbox (code execution)
              ├── Build & run user's code
              ├── Playwright browser automation
              └── File system workspace
                     ↓
              Results → SSE → Frontend → Live Preview
```

### Key Implementation Steps for AgentOS:

1. **Wire Claude API** — LiteLLM → Claude Sonnet for chat, Opus for planning
2. **Add Claude Code CLI integration** — spawn `claude -p` for complex tasks
3. **Add Docker sandbox** — isolated code execution per task
4. **Add Playwright** — browser automation inside sandbox
5. **Add artifact preview** — render HTML/React in iframe (you already asked for this)
6. **Add MCP connectors** — reuse our existing MCP configs
7. **Add persistent workspace** — MinIO/local storage per project
8. **Add task queue** — Celery for background agent tasks

---

## Priority Implementation Order

### Phase 1: Config Sync (1 hour)
- Build `scripts/sync-to-vps.sh`
- Deploy all configs, MCPs, API keys to VPS
- VPS Claude becomes mirror of Mac Claude

### Phase 2: Self-Hosted MCPs (30 min)
- Install Context7, GitHub, Memory, Sequential Thinking on VPS
- Configure `.mcp.json` with all servers
- Verify all MCPs respond

### Phase 3: AgentOS Chat (2 hours)
- Wire Claude API to AgentOS backend via LiteLLM
- SSE streaming for real-time responses
- Basic conversation with tool use

### Phase 4: AgentOS Autonomous Coding (4 hours)
- Add `claude -p` integration for complex tasks
- Docker sandbox for code execution
- Playwright for browser automation
- Artifact preview in frontend

### Phase 5: AgentOS Full Manus Parity (ongoing)
- Persistent workspaces
- Task history and replay
- Multi-agent orchestration via web UI
- GitHub/Gmail/Calendar connectors through AgentOS
