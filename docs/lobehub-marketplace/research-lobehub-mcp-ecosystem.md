# Research Report: LobeHub Agent & MCP Marketplace Ecosystem

**Date:** 2026-03-26
**Research Type:** Mixed (Competitive + Technical + Market)
**Duration:** ~60 minutes
**Sources Consulted:** 25+

---

## Executive Summary

LobeHub has built the most comprehensive open-source AI agent ecosystem available today, with **217,527+ skills**, **39,603+ MCP servers**, **64K+ GitHub stars**, and a thriving community marketplace. Their platform represents the gold standard for agent discovery, configuration, and collaboration.

Our claude-super-setup system has complementary strengths: **89 slash commands**, **71 agents**, **17 hooks**, **6 skills**, **16 stack templates**, and a sophisticated autonomous pipeline (BMAD + auto-dev). However, we lack a marketplace, public agent discovery, MCP registry integration, and community contribution workflows.

**The opportunity is two-fold:**
1. **Integrate with LobeHub's ecosystem** — tap into their 39K+ MCP servers and 217K+ skills for immediate capability expansion
2. **Build our own marketplace layer** — package our commands, agents, hooks, and pipelines as discoverable, shareable, monetizable artifacts

This would position claude-super-setup as both a consumer and producer in the MCP economy, a market projected to rival early mobile app stores.

---

## Research Questions

1. How does LobeHub define, configure, and share agents?
2. How does the MCP marketplace work (listing, install, security)?
3. What competing MCP marketplaces exist and how do they compare?
4. What does claude-super-setup have that LobeHub doesn't, and vice versa?
5. How can we integrate with LobeHub AND build our own marketplace?
6. What monetization models exist in the MCP ecosystem?
7. What's the strategic path from current state to marketplace-enabled system?

---

## Methodology

- **WebSearch**: 15+ queries across LobeHub, MCP ecosystem, competing platforms
- **WebFetch**: Deep-dived 8+ pages (LobeHub docs, DeepWiki, marketplace comparisons)
- **Codebase Exploration**: Audited claude-super-setup structure (agents, commands, hooks, skills)
- **Competitive Analysis**: Compared 8+ MCP marketplace platforms

---

## Part 1: LobeHub Platform Deep Dive

### 1.1 Agent Architecture

LobeHub treats **agents as the fundamental unit of work**. Each agent is:

| Component | Description |
|-----------|-------------|
| `systemRole` | Core instructions defining behavior, personality, expertise |
| `config.model` | LLM model identifier (e.g., "gpt-4", "claude-3") |
| `config.params` | temperature, top_p, frequency_penalty, presence_penalty |
| `config.displayMode` | "chat" or "docs" mode |
| `config.historyCount` | Messages to retain in context |
| `config.inputTemplate` | Template with `{{text}}` placeholder |
| `meta.avatar` | Emoji or image URL |
| `meta.tags` | Categorization tags |
| `meta.title` | Display name |
| `meta.description` | Agent purpose summary |
| `plugins` | Array of plugin/tool identifiers |

**Agent Definition Format (JSON):**
```json
{
  "author": "creator-name",
  "config": {
    "displayMode": "chat",
    "systemRole": "You are a specialized...",
    "model": "gpt-4",
    "params": {
      "temperature": 0.7,
      "top_p": 0.9
    },
    "enableHistoryCount": true,
    "historyCount": 10
  },
  "homepage": "https://github.com/...",
  "identifier": "unique-agent-id",
  "locale": "en-US",
  "meta": {
    "avatar": "emoji-or-url",
    "tags": ["tag1", "tag2"],
    "title": "Agent Name",
    "description": "What this agent does"
  }
}
```

**Key Insight:** LobeHub's agent format is deliberately simple — JSON with a system prompt and metadata. This is what enables 217K+ contributions. Simplicity drives scale.

### 1.2 Multi-Agent Collaboration (v2.0+)

Released January 2025, LobeHub v2 introduced:

- **Agent Groups**: Multiple specialized agents in one conversation
- **Parallel Response Mode**: Agents work simultaneously
- **Sequential Ordering**: Orchestrated turn-taking
- **Direct Messaging**: Agent-to-agent communication within groups
- **Chat Groups Table**: `chat_groups` + `chat_groups_agents` for member role assignments
- **Agent Builder**: Natural language agent creation — "describe what you want, LobeHub builds it"

**Example Use Case — PR Review Team:**
- Linter Agent: syntax/style validation
- Security Agent: secret scanning + vulnerability detection
- Architect Agent: logic/design review

### 1.3 Knowledge Base & RAG

- Content-addressed `global_files` table (deduplication)
- Document parsing: PDF, DOCX, EPUB via `@lobechat/file-loaders`
- Chunking + pgvector embeddings (1024-dimensional)
- Query-time retrieval through `message_queries` tables
- Agents can query knowledge bases during conversations

### 1.4 Tool Integration Architecture

Four tool sources:

| Source | Description | Scale |
|--------|-------------|-------|
| **Built-in Tools** | Calculator, memory, notebook, knowledge-base, web-browsing, cloud-sandbox | 6 core |
| **MCP Plugins** | Model Context Protocol marketplace | 10,000+ |
| **Klavis OAuth** | Pre-authenticated OAuth services | 30+ |
| **LobeHub Skills** | Premium/community integrations | 217,527+ |

### 1.5 Skills Marketplace

**Skills are NOT agents.** Skills are modular SKILL.md packages that extend agent capabilities:

- **Format**: YAML frontmatter + Markdown instructions + optional bundled resources
- **CLI**: `npx skills find`, `npx skills add`, `npx skills check`, `npx skills update`
- **Compatible with**: Claude Code, Codex CLI, ChatGPT
- **Content**: workflows, tool integrations, domain expertise, scripts/references
- **Scale**: 217,527+ skills in marketplace

**This is the same SKILL.md format we already use in claude-super-setup!** Direct compatibility.

### 1.6 Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 + React 19 |
| Database | PostgreSQL + pgvector |
| Auth | better-auth v1.4.6 (OAuth, OIDC, WebAuthn) |
| UI | Radix UI + antd + lobe-ui |
| State | Zustand |
| API | tRPC (end-to-end type-safe) |
| Streaming | SSE via @lobechat/fetch-sse |
| Desktop | Electron (for STDIO MCP support) |
| Deployment | Vercel, Docker, Desktop (GitHub Releases/S3) |

---

## Part 2: MCP Marketplace Ecosystem

### 2.1 LobeHub MCP Marketplace

- **39,603+ MCP servers** listed
- **One-click install** via LobeHub Desktop
- **Transport types**: STDIO (local tools) and HTTP/HTTPS (cloud services)
- **Categories**: Development, Productivity, Data, Communication, etc.
- **Community-driven**: open submission, automated i18n translation

### 2.2 Competing Platforms

| Platform | Servers | Focus | Hosting | Monetization |
|----------|---------|-------|---------|-------------|
| **mcp.so** | 17,186+ | Largest directory + playground | Discovery only | No |
| **Glama** | 12,610+ | Enterprise hosting + VM isolation | Firecracker VMs | No |
| **Smithery** | 3,305+ | Verified + free hosting + CLI | Free STDIO/HTTP | No |
| **PulseMCP** | 6,970+ | News/updates + official registry | Discovery only | No |
| **Apify** | 7,000+ | Web scraping specialization | Managed | 80% revenue share |
| **Composio** | 500+ integrations | Unified API + managed auth | Managed + OAuth | Usage-based |
| **MCPize** | 100+ | Monetization focus | Managed + CLI | 85% revenue share |
| **Cursor Directory** | 1,800+ | Cursor IDE community | Discovery only | No |
| **Official MCP Registry** | ~2,000 | Source of truth (registry.modelcontextprotocol.io) | API only | No |

### 2.3 Official MCP Registry

- **Launched**: September 2025 at registry.modelcontextprotocol.io
- **Growth**: 407% from initial batch to ~2,000 entries by November 2025
- **API Freeze**: v0.1 in October 2025
- **Built by**: PulseMCP + Goose teams
- **Status**: Preview, community-driven, open submissions

### 2.4 MCP Monetization Landscape

| Model | Example | Revenue Split |
|-------|---------|--------------|
| Freemium + Tiered | 21st.dev: 5 free calls, $20/mo | Developer keeps most |
| Revenue Share | Apify: 80% dev, MCPize: 85% dev | Platform takes 15-20% |
| Transaction Fee | RapidAPI: 75-80% to developer | 20-25% platform cut |
| Affiliate | Apify: 20-30% recurring, up to $2,500/referral | Referral-based |
| Enterprise Licensing | Composio: usage-based with SLAs | Negotiated |

**Key Insight:** The MCP economy is in early "app store" phase. First movers who build quality products and establish market position now will dominate as the ecosystem matures.

---

## Part 3: Gap Analysis — LobeHub vs Claude-Super-Setup

### 3.1 What We Have That LobeHub Doesn't

| Capability | Claude-Super-Setup | LobeHub |
|-----------|-------------------|---------|
| **Autonomous Pipelines** | /auto-dev, /ghost (idea-to-PR) | No autonomous coding |
| **BMAD Method** | Full SDLC (brief → PRD → arch → sprint → build) | No SDLC framework |
| **Hook System** | 17 hooks (session, quality, branch, telemetry) | No hook equivalent |
| **Slash Commands** | 89 commands covering full dev lifecycle | Chat-based only |
| **Stack Templates** | 16 curated templates for project scaffolding | No scaffolding system |
| **Agent Teams** | Pre-configured teams (review, frontend, backend, etc.) | Agent groups (manual) |
| **Learning System** | MCP-based learning ledger + consolidation | Memory (conversation-level) |
| **Telegram Dispatch** | Remote mobile control via Telegram | No remote dispatch |
| **Ghost Mode** | Overnight autonomous development | No equivalent |
| **Quality Gates** | /check = code review + security + tests in parallel | Manual review |
| **Pipeline Orchestration** | Task DAG with dependency resolution | No task orchestration |
| **VPS Bot** | 24/7 autonomous development on remote server | Cloud-only |

### 3.2 What LobeHub Has That We Don't

| Capability | LobeHub | Claude-Super-Setup |
|-----------|---------|-------------------|
| **Agent Marketplace** | 217,527+ skills, public discovery | No public marketplace |
| **MCP Marketplace** | 39,603+ MCP servers, one-click install | 2 custom MCP servers |
| **Web UI** | Rich chat interface with file uploads, artifacts | CLI-only |
| **Knowledge Base/RAG** | pgvector, file parsing, semantic search | No built-in RAG |
| **Multi-Provider Support** | 50+ LLM providers (OpenAI, Claude, Gemini, Ollama) | Claude-only |
| **Agent Builder UI** | Natural language agent creation | Manual YAML/MD editing |
| **Community Contributions** | Automated i18n, PR workflow, marketplace listing | No contribution flow |
| **Plugin SDK** | @lobehub/chat-plugin-sdk with manifest schema | No plugin SDK |
| **OAuth Integration** | 30+ pre-authenticated services via Klavis | Manual API key management |
| **Desktop App** | Electron app with native MCP support | CLI + terminal |
| **Collaboration** | Agent-to-agent messaging, parallel responses | Sequential agent calls |
| **Monetization** | Skills/MCP marketplace economy | No monetization |

### 3.3 Overlap / Compatible Areas

| Area | Status |
|------|--------|
| **SKILL.md Format** | IDENTICAL — both use YAML frontmatter + Markdown |
| **MCP Protocol** | Both support MCP servers (we have 2, they have 39K+) |
| **Agent Definitions** | Different formats but similar concepts (system prompt + tools + config) |
| **Multi-Agent** | Both support agent teams, different orchestration models |

---

## Part 4: Key Insights

### Insight 1: SKILL.md Compatibility is Our Trojan Horse

**Finding:** LobeHub's skills marketplace uses the exact same SKILL.md format we already use.

**Implication:** Our 6 skills and 89 commands can be published to LobeHub's marketplace with minimal adaptation. Similarly, we can consume any of their 217K+ skills.

**Recommendation:** Build a bidirectional skill sync — publish our skills to LobeHub, consume theirs locally.

**Priority:** HIGH — immediate capability multiplier

### Insight 2: MCP Registry Integration is Low-Hanging Fruit

**Finding:** The official MCP Registry at registry.modelcontextprotocol.io has a stable API (v0.1 frozen) and ~2,000 curated servers. LobeHub indexes 39K+ across multiple sources.

**Implication:** We can build an MCP discovery and install layer that searches across registries and installs MCP servers into our settings.json.

**Recommendation:** Build `/mcp-install` command that searches registries and auto-configures MCP servers.

**Priority:** HIGH — transforms our tool capabilities

### Insight 3: Our Agent Format Should Support Export to LobeHub

**Finding:** LobeHub agents are simple JSON (system prompt + model config + metadata). Our agents are richer Markdown files with tool lists, capabilities, and team assignments.

**Implication:** We can build an export pipeline that converts our agent Markdown to LobeHub JSON format for publishing.

**Recommendation:** Create agent format converter + submission pipeline to LobeHub marketplace.

**Priority:** MEDIUM — community building opportunity

### Insight 4: Agent Builder UI via Chat Interface

**Finding:** LobeHub's Agent Builder lets users describe what they want in natural language and auto-generates agents. We have similar capability via `/new-agent-app` and skill-creator but it's CLI-only.

**Implication:** Adding a natural language agent builder to our Telegram dispatch would enable mobile agent creation.

**Recommendation:** Build `/create-agent` Telegram command for voice/text-driven agent creation.

**Priority:** MEDIUM — UX improvement

### Insight 5: Knowledge Base / RAG is Our Biggest Gap

**Finding:** LobeHub has a full RAG pipeline (pgvector, file parsing, chunking, semantic search). We have basic file reading and the learning MCP server.

**Implication:** For complex projects, we can't do semantic search across documentation or codebase knowledge.

**Recommendation:** Build a knowledge-rag MCP server with pgvector for project-level semantic search.

**Priority:** HIGH — fundamental capability gap

### Insight 6: Marketplace Monetization is Greenfield

**Finding:** MCP monetization models are immature — 85% revenue share on MCPize, 80% on Apify. The market resembles early mobile app stores.

**Implication:** Building premium skills/agents/pipelines (e.g., our /auto-dev pipeline, /ghost mode) as paid marketplace offerings could generate revenue.

**Recommendation:** Package our best pipelines as premium marketplace offerings on MCPize or our own marketplace.

**Priority:** LOW (for now) — focus on building first, monetize later

### Insight 7: Our Autonomous Pipeline is Unique

**Finding:** No competing platform (LobeHub, Manus, or any MCP marketplace) offers anything like our /auto-dev or /ghost pipeline — idea-to-PR autonomous development.

**Implication:** This is our strongest differentiator. Packaging it as a marketplace product would be compelling.

**Recommendation:** Position autonomous development pipelines as the premium tier of our marketplace offering.

**Priority:** HIGH — competitive moat

### Insight 8: Community Contribution Workflow Needed

**Finding:** LobeHub has automated i18n, PR-based submission, and marketplace listing for community contributions. We have none of this.

**Implication:** Without a contribution workflow, our agent/skill ecosystem can't grow beyond what we build ourselves.

**Recommendation:** Build a GitHub-based contribution pipeline with PR templates, validation, and auto-indexing.

**Priority:** MEDIUM — scale enabler

---

## Part 5: Competitive Feature Matrix

| Feature | Claude-Super-Setup | LobeHub | Smithery | Composio |
|---------|-------------------|---------|----------|----------|
| Agent Definition | Markdown + YAML | JSON + metadata | N/A | N/A |
| Agent Count | 71 | 217,527+ skills | N/A | N/A |
| MCP Server Count | 2 | 39,603+ | 3,305+ | 500+ |
| MCP Install | Manual config | One-click | CLI + hosted | Managed |
| Agent Marketplace | No | Yes (huge) | No | No |
| Skill Marketplace | No | Yes (SKILL.md) | No | No |
| Multi-Agent | Teams (sequential) | Groups (parallel/seq) | No | No |
| Autonomous Pipeline | Yes (full SDLC) | No | No | No |
| Hook System | Yes (17 hooks) | No | No | No |
| Remote Dispatch | Yes (Telegram) | No | No | No |
| Knowledge Base / RAG | No | Yes (pgvector) | No | No |
| Web UI | No (CLI only) | Yes (rich) | Minimal | Yes |
| Desktop App | No | Yes (Electron) | No | No |
| Community Contributions | No workflow | Automated i18n + PR | Open PRs | Closed |
| Monetization | None | Early marketplace | No | Usage-based |
| OAuth Management | Manual | 30+ via Klavis | No | 500+ managed |

---

## Part 6: Strategic Recommendations

### Immediate Actions (Week 1-2)

1. **Build MCP Registry Client** — `/mcp-search` and `/mcp-install` commands that search the official MCP Registry + LobeHub's index and auto-configure MCP servers in settings.json
2. **Skill Sync Pipeline** — Publish our 6 skills + best commands to LobeHub's Skills Marketplace in SKILL.md format
3. **Agent Export Format** — Build converter from our Markdown agent format to LobeHub's JSON format

### Short-Term (Month 1-2)

4. **Agent/Skill Marketplace** — Build a local marketplace index (catalog.json v2) with search, install, rate capabilities
5. **Knowledge RAG MCP Server** — pgvector-backed semantic search for project docs and codebase
6. **Community Contribution Pipeline** — GitHub PR templates, validation scripts, auto-indexing for agents/skills/commands
7. **MCP Server Builder** — `/mcp-create` command to scaffold new MCP servers from templates

### Long-Term (Month 3+)

8. **Public Marketplace** — Web-based marketplace for claude-super-setup agents, skills, pipelines, and hooks
9. **Premium Pipeline Offerings** — Package /auto-dev, /ghost, /team-build as premium products
10. **LobeHub Plugin Integration** — Build a LobeChat plugin that brings claude-super-setup's autonomous pipelines into LobeHub
11. **Multi-Registry Aggregation** — Single search across LobeHub, Smithery, mcp.so, official registry, Composio
12. **OAuth Broker** — Managed OAuth integration for MCP servers (like Klavis but for CLI)

---

## Research Gaps

**What we still don't know:**
- Exact API for LobeHub's agent/skill submission (need to inspect their PR workflow)
- LobeHub's revenue model and sustainability (is the marketplace monetized?)
- How LobeHub handles MCP server security vetting and trust
- Performance characteristics of their RAG pipeline at scale
- Detailed Klavis OAuth integration architecture

**Recommended follow-up research:**
1. Deep-dive into LobeHub's GitHub Actions workflow for agent submission
2. Analyze the official MCP Registry API specification
3. Research Klavis OAuth architecture for potential integration
4. Benchmark pgvector-based RAG approaches for CLI environments

---

## Sources

1. [LobeHub GitHub Repository](https://github.com/lobehub/lobehub) — Main project repo (49K+ stars)
2. [LobeHub Architecture Wiki](https://github.com/lobehub/lobe-chat/wiki/Architecture) — Technical architecture
3. [LobeHub Agent System (DeepWiki)](https://deepwiki.com/lobehub/lobehub/3-ai-agent-system) — Agent architecture deep dive
4. [LobeHub Agent Builder (DeepWiki)](https://deepwiki.com/lobehub/lobehub/3.1-agent-builder-and-configuration) — Agent configuration details
5. [LobeHub MCP Marketplace](https://lobehub.com/mcp) — MCP server directory
6. [lobe-chat-agents Repository](https://github.com/lobehub/lobe-chat-agents) — Agent index and templates
7. [lobe-chat-plugins Repository](https://github.com/lobehub/lobe-chat-plugins) — Plugin index
8. [Agent Template Full (GitHub)](https://github.com/lobehub/lobe-chat-agents/blob/main/agent-template-full.json) — Complete agent schema
9. [LobeHub Skills Marketplace](https://lobehub.com/skills) — Skills directory
10. [MCP Platforms Comparison (MCPize)](https://mcpize.com/alternatives) — Platform comparison matrix
11. [State of MCP 2025 (Glama)](https://glama.ai/blog/2025-12-07-the-state-of-mcp-in-2025) — Ecosystem overview
12. [MCP Registry Preview Blog](https://blog.modelcontextprotocol.io/posts/2025-09-08-mcp-registry-preview/) — Official registry launch
13. [Building the MCP Economy (Cline)](https://cline.bot/blog/building-the-mcp-economy-lessons-from-21st-dev-and-the-future-of-plugin-monetization) — Monetization strategies
14. [Engineer's Guide to LobeHub (TypeVar)](https://typevar.dev/articles/lobehub/lobehub) — Deployment and scaling guide
15. [Best MCP Platforms (Composio)](https://composio.dev/blog/hosted-mcp-platforms) — Hosted MCP comparison
16. [MCP Server Economics (Zeo)](https://zeo.org/resources/blog/mcp-server-economics-tco-analysis-business-models-roi) — TCO analysis
17. [Composio MCP Platform](https://composio.dev/blog/smithery-alternative) — Composio features and comparison
18. [LobeHub Plugin Development](https://lobehub.com/docs/usage/plugins/development) — Plugin SDK docs
19. [Plugin Manifest Schema](https://chat-plugin-sdk.lobehub.com/guides/plugin-manifest) — Plugin schema specification
20. [MCP Registry GitHub](https://github.com/modelcontextprotocol/registry) — Registry source code
21. [LobeHub Homepage](https://lobehub.com) — Product overview and stats
22. [LobeHub Changelog](https://lobehub.com/changelog) — Release history
23. [MCP in LobeHub Blog](https://lobehub.com/blog/mcp-in-lobehub-what-is-it-and-how-to-set-it-up) — MCP setup guide
24. [Apify MCP Marketplace](https://apify.com/mcp/developers) — Developer monetization
25. [Future of MCP (Knit.dev)](https://www.getknit.dev/blog/the-future-of-mcp-roadmap-enhancements-and-whats-next) — MCP roadmap

---

## Appendix A: LobeHub Numbers at a Glance

| Metric | Value |
|--------|-------|
| GitHub Stars (lobe-chat) | 64,300+ |
| GitHub Stars (lobehub v2) | 49,820+ |
| GitHub Forks | 10,793+ |
| Skills in Marketplace | 217,527+ |
| MCP Servers Listed | 39,603+ |
| Built-in Tools | 6 |
| OAuth Services (Klavis) | 30+ |
| LLM Providers Supported | 50+ |
| Desktop Platforms | Mac, Windows, Linux |
| Deploy Targets | Vercel, Docker, Desktop |

## Appendix B: Claude-Super-Setup Numbers

| Metric | Value |
|--------|-------|
| Slash Commands | 89 |
| Core Agents | 23 |
| Community Agents | 18 |
| Total Agents (all categories) | 71 |
| Hooks | 17 |
| Skills | 6 |
| Stack Templates | 16 |
| MCP Servers | 2 |
| Agent Teams | 10 |
| BMAD Workflows | 12+ |
| Autonomous Pipelines | 5 (/auto-dev, /ghost, /auto-ship, /auto-build, /auto-build-all) |

## Appendix C: Integration Architecture Overview

```
claude-super-setup
       |
       +--- MCP Registry Client -------> Official MCP Registry (2K+ servers)
       |                                  LobeHub MCP Index (39K+ servers)
       |                                  Smithery (3.3K+ servers)
       |                                  Glama (12K+ servers)
       |
       +--- Skill Sync Pipeline -------> LobeHub Skills Marketplace (217K+)
       |    (SKILL.md bidirectional)      (publish ours, consume theirs)
       |
       +--- Agent Export/Import --------> LobeHub Agent Marketplace
       |    (MD <-> JSON converter)       (publish our agents as LobeHub agents)
       |
       +--- Knowledge RAG MCP ---------> Project docs, codebase semantic search
       |    (pgvector + file loaders)
       |
       +--- Marketplace Layer ----------> Our own catalog (agents, skills, commands, hooks)
       |    (catalog.json v2)             Search, install, rate, share
       |
       +--- Community Pipeline ---------> GitHub PR submission + auto-indexing
            (templates + validation)       Automated i18n (optional)
```

---

*Generated by BMAD Method v6 - Creative Intelligence*
*Research Duration: ~60 minutes*
*Sources Consulted: 25+*
