# Feature Brief: AgentOS v2

**Created:** 2026-03-25
**Status:** Draft

---

## Problem

The current AgentOS (manus-clone at ~/manus-clone on VPS 187.77.15.168) has a working Next.js frontend and FastAPI backend but is non-functional: backend crashes due to SQLAlchemy bug, chat doesn't respond, no agent execution, no connectors work, no sandbox, no file storage. Meanwhile, all 86 commands and 50+ agents from claude-super-setup exist but are only accessible via terminal/Telegram — not through a web UI. The goal is a self-hosted Manus-level platform that brings our full Claude Code power into a beautiful web interface anyone can use.

---

## Proposed Solution

Rebuild AgentOS into a production-grade autonomous agent platform by:

1. **Fix the backend** — SQLAlchemy metadata bug, Docker networking, health checks
2. **Make chat work** — Wire Claude API via LiteLLM to the FastAPI agent endpoint with SSE streaming
3. **Add agent execution** — LangGraph Plan-Execute-Verify pipeline with Celery task queue
4. **Add sandbox** — Docker-based code execution + Playwright browser automation
5. **Add connectors** — MCP Servers for GitHub, Gmail, Calendar, Gemini (reuse our existing MCP configs)
6. **Add persistence** — Task history, file storage (MinIO), semantic search (pgvector)
7. **Add scheduling** — Celery Beat for recurring tasks
8. **Add personalization** — Custom instructions, knowledge base, project workspaces
9. **Integrate Claude Code powers** — All 86 commands accessible through the web UI as "skills"

Architecture from Manus collaboration: LangGraph state machine, SSE streaming, PostgreSQL + pgvector, MCP connectors, Docker sandbox with Control Plane pattern.

---

## Target Users

**Primary:** Caleb Mambwe — solo developer wanting a Manus-level web UI to manage autonomous agent tasks from any browser, phone, or device.

**Secondary:** Anyone who deploys AgentOS — open-source self-hosted alternative to Manus.

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Technical | Must reuse existing Next.js frontend + FastAPI backend in ~/manus-clone on VPS. PostgreSQL + Redis already running via Docker Compose. |
| Infrastructure | VPS: 187.77.15.168, Ubuntu 24.04, 16GB RAM, 193GB disk. Docker Compose for all services. |
| Auth | Claude API via OAuth token already configured on VPS. |
| Budget | Manus Pro: 3,899 credits remaining for collaboration. Claude: $50/session budget. |
| Timeline | Incremental — fix backend first, then add features sprint by sprint. |

---

## Scope

### In Scope

**Phase 1: Fix & Get Running (immediate)**
- Fix SQLAlchemy `metadata` column bug in project.py
- Fix alembic migration (001_initial_schema.py)
- Fix Docker Compose networking (backend can't resolve postgres hostname)
- Run alembic migrations
- Verify backend health + frontend loads with API connected

**Phase 2: Working Chat Agent**
- Wire Claude API to the agent endpoint via LiteLLM
- Implement SSE streaming (exact code from Manus architecture)
- Basic ReAct agent loop (receive message → think → use tools → respond)
- Store conversation history in PostgreSQL

**Phase 3: Sandbox & Tools**
- Docker-based sandbox for code execution
- Playwright browser automation (web browsing tool)
- File system tools (read/write/list in sandbox workspace)
- Shell execution tool

**Phase 4: Connectors & Integrations**
- MCP Server framework for connectors
- GitHub connector (reuse existing MCP server config)
- Gmail connector
- Google Calendar connector
- Gemini connector (image/video generation)
- Web search tool

**Phase 5: Persistence & Search**
- Task history with full conversation replay
- File storage via MinIO/S3
- Semantic search via pgvector embeddings
- Library view (search across all past tasks and files)

**Phase 6: Scheduling & Personalization**
- Celery Beat for scheduled/recurring tasks
- Custom instructions per user
- Knowledge base (upload docs for RAG)
- Project workspaces

### Out of Scope
- Meeting recording/transcription (future)
- Multi-user auth (single user for now)
- WhatsApp/Messenger integration (Telegram only)
- LobeHub integration (evaluated, decided to keep current UI)
- E2B/Firecracker VMs (Docker first, E2B for production scale)

---

## Feature Name

**Kebab-case identifier:** `agentos-v2`

**Folder:** `docs/agentos-v2/`

---

## Notes

1. **Manus architecture available:** Full SQL schemas, SSE code, system diagram from direct API consultation (53 credits). Saved in session context.

2. **Research completed:**
   - `docs/research/research-agentos-rebuild.md` — Manus features, LobeHub analysis, platform comparison
   - 6 Manus API collaborations with architecture recommendations
   - Manus sandbox blog: https://manus.im/blog/manus-sandbox

3. **Key architectural decisions (from Manus):**
   - LangGraph for agent state machine (not raw ReAct loops)
   - SSE over WebSockets (unidirectional, simpler, HTTP/2 compatible)
   - PostgreSQL + pgvector (unified relational + vector, no separate vector DB)
   - MCP for all connectors (standard protocol)
   - Celery + Redis for task queue
   - Control Plane pattern for sandbox security

4. **Existing infrastructure to reuse:**
   - VPS: Docker Compose with PostgreSQL 16 + Redis 7 already running
   - Frontend: Next.js 14 with shadcn/ui components
   - Backend: FastAPI with SQLAlchemy + Alembic
   - Claude auth: OAuth token on VPS
   - All API keys: Gemini, OpenAI, Manus stored in ~/.claude/.env

5. **Implementation order:**
   Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
   Each phase independently deployable and testable.

---

## PR/FAQ: AgentOS v2

### Press Release

**LUSAKA, March 2026** — Twendai Software Development today announced AgentOS v2, a self-hosted autonomous AI agent platform that lets developers control their entire development workflow from a web browser. Starting immediately, developers can give natural language tasks to an AI agent that plans, codes, browses the web, manages files, and delivers results — all running on their own infrastructure.

Most developers today are stuck choosing between expensive hosted AI platforms they don't control, or bare terminal-based tools that require constant supervision. When you need an AI to build a feature, research competitors, or set up infrastructure, you either pay Manus $20/month for limited credits, or sit at your terminal babysitting Claude Code for hours.

"I wanted to text 'build me a habit tracker' from my phone and come back to a working app with tests and a PR," said Caleb Mambwe, founder of Twendai Software. "But I also wanted it running on my own server, with my own API keys, connected to my GitHub and email — not locked into someone else's platform."

AgentOS v2 provides a polished web interface where you describe what you want in natural language. The AI agent autonomously plans the work, executes code in a sandboxed environment, browses the web for research, and delivers results with real-time streaming updates. It connects to your existing tools — GitHub, Gmail, Google Calendar — via the open MCP protocol, and stores everything in PostgreSQL so you can search and replay any past task.

Unlike Manus or other hosted platforms, AgentOS v2 runs entirely on your VPS. Your code, your data, your API keys — nothing leaves your infrastructure. And because it's built on the same Claude Code engine that powers 86 development commands, it has enterprise-grade capabilities like automated code review, security audits, and SMURF test classification built in.

To get started: `docker compose up -d` on any Ubuntu VPS with 4GB RAM.

### Frequently Asked Questions

**Customer FAQs:**

**Q: Who is this for?**
A: Solo developers and small teams who want a self-hosted Manus alternative with full control over their data and infrastructure.

**Q: How is this different from Manus?**
A: You own it. It runs on your VPS with your API keys. No credit limits beyond what your API provider charges. And it integrates 86 Claude Code commands as built-in skills — more than any hosted platform.

**Q: What does it cost?**
A: Free (open source). You pay only for your own API usage (Claude, Gemini, etc.) and VPS hosting (~$5-15/month).

**Q: What if the agent breaks something?**
A: All code execution happens in a Docker sandbox isolated from your server. The agent can't access your database, SSH keys, or system files.

**Q: When will it be available?**
A: Phase 1 (working chat) is being deployed now. Full feature set in 4-6 sprints.

**Internal/Technical FAQs:**

**Q: How long will this take to build?**
A: 6 phases. Phase 1 (fix + chat) is a single sprint. Full platform in 4-6 sprints.

**Q: What are the biggest risks?**
A: (1) Agent execution quality — the LangGraph pipeline needs careful prompt engineering to match Manus quality. (2) Sandbox security — Docker isolation is good but not Firecracker-level. (3) Context management — long tasks can exhaust the context window.

**Q: What are we NOT building?**
A: Multi-user auth, meeting transcription, WhatsApp/Messenger, E2B VMs, LobeHub integration.

**Q: How will we measure success?**
A: (1) Chat responds to messages within 3 seconds (SSE first token). (2) Agent can complete a basic coding task end-to-end (create file, run tests, return result). (3) Task history is searchable. (4) Platform stays up for 7 days without manual intervention.

**Q: What's the rollback plan?**
A: Each phase is a separate Docker Compose service. Roll back by reverting to the previous image tag. Database migrations are forward-only but each phase is independently deployable.
