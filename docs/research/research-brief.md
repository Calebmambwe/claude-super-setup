# Research Brief: claude-super-setup Competitive Landscape

**Date:** 2026-03-21
**Status:** Complete
**Researcher:** Claude Code (Opus 4.6)
**Scope:** Analyzed 10 competing Claude Code setup frameworks, MCP ecosystem, template systems, and autonomous CI/CD patterns to identify gaps, opportunities, and adoptable patterns for making our setup portable, extensible, and self-improving.

---

## 1. Findings by Competitor

### 1.1 wshobson/agents
**Repository:** [github.com/wshobson/agents](https://github.com/wshobson/agents)
**Scale:** 112 specialized agents, 146 skills, 72 plugins, 16 workflow orchestrators

**What they have that we don't:**
- **4-tier model routing:** nano/haiku (trivial) → sonnet (complex) → opus (critical) → custom (specialized). Our setup only uses 2 tiers (opus for planning, sonnet for subagents).
- **Progressive disclosure in skills:** Skills reveal information incrementally to minimize token usage. Our skills are flat documents.
- **Agent Teams with presets:** Pre-configured teams (`review`, `debug`, `feature`, `fullstack`, `research`, `security`, `migration`) that auto-compose the right agents. We have agent teams enabled but no presets.
- **Plugin marketplace model:** 72 single-purpose plugins with minimal token footprint. Our plugins are monolithic.
- **24 agent categories** with deep specialization per domain (vs. our 8 departments).

**What we have that they don't:**
- Ghost Mode (overnight autonomous pipeline with screen supervisor, caffeinate, exponential backoff)
- SDLC-aware PostToolUse hooks that enforce document ordering
- Stack templates with YAML-driven full-file generation
- Self-learning system with confidence-scored corrections and consolidation
- Budget-controlled autonomous pipelines

**Adoptable patterns:** 4-tier model routing, preset team compositions, progressive disclosure in skills, agent capability tagging.

### 1.2 affaan-m/everything-claude-code
**Repository:** [github.com/affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code)
**Origin:** Hackathon winner (Cerebral Valley x Anthropic, Feb 2026)

**What they have that we don't:**
- **Cross-platform compatibility:** Works on Claude Code, Cursor, OpenCode, Codex. Our setup is Claude Code-specific.
- **AgentShield integration:** Security scanning integrated into the agent workflow. We have security-auditor agent but no dedicated scanning framework.
- **60+ skill modules** spanning Django, Laravel, Spring Boot, Go, Docker, Kubernetes — broader language/framework coverage than our TypeScript/Python focus.
- **Token optimization via model selection strategies:** Automated cost tracking per session.
- **28 specialized subagents** with per-language code reviewers (Go reviewer, Rust reviewer, etc.).

**What we have that they don't:**
- BMAD integration (full product lifecycle)
- Ghost Mode
- Stack templates
- Autonomous pipeline commands (/auto-dev, /auto-ship)
- Learning system with consolidation

**Adoptable patterns:** Per-language specialist agents, AgentShield-style security scanning, token cost tracking.

### 1.3 oh-my-claudecode
**Repository:** [github.com/Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)
**Website:** [ohmyclaudecode.com](https://ohmyclaudecode.com/)

**What they have that we don't:**
- **Ultrapilot mode:** Up to 5 concurrent workers auto-delegated by role. Our parallel execution is limited to `/team-build` (3 agents) and `/parallel-implement` (5 agents in worktrees).
- **Auto model routing:** Automatic Haiku for simple tasks, Opus for complex reasoning — saves 30-50% on tokens. Our model routing is manual (set in agent definitions).
- **Zero configuration:** Works out of the box with no setup. Our setup requires significant configuration.
- **32 auto-delegated agents** that self-select based on task type.
- **Ralph mode with Architect verification:** Ralph loop plus an architect agent that validates completion.

**What we have that they don't:**
- Hook system (lifecycle hooks, SDLC gates, protection hooks)
- Stack templates
- Custom commands (70+)
- Agent memory system
- BMAD integration
- Ghost Mode

**Adoptable patterns:** Auto model routing, Ultrapilot concurrent worker pattern, architect verification for Ralph loop, zero-config defaults.

### 1.4 VoltAgent/awesome-claude-code-subagents
**Repository:** [github.com/VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
**Scale:** 127+ specialized subagents across 10 categories

**What they have that we don't:**
- **Plugin marketplace install:** `claude plugin marketplace add VoltAgent/awesome-claude-code-subagents` — one-command agent installation. We have no marketplace or install mechanism.
- **Language specialists:** 20+ language-specific agents (Rust, Go, Java, C++, Swift, Kotlin, PHP, Ruby, Elixir, etc.). Our agents are language-agnostic or TypeScript/Python-focused.
- **Domain specialists:** Data & AI agents (ML pipeline builder, data engineer), Specialized Domain agents (blockchain, game dev, IoT, embedded). We lack these entirely.
- **Meta & Orchestration agents:** Agents that create and manage other agents. We have orchestrator but not meta-agent capabilities.

**What we have that they don't:**
- Everything in our setup that isn't agent-related (hooks, commands, templates, BMAD, Ghost Mode, learning)

**Adoptable patterns:** Plugin marketplace pattern for agent distribution, language specialist agents, domain-specific agents (AI/ML, blockchain, game dev).

### 1.5 BMAD METHOD (Official)
**Repository:** [github.com/bmad-code-org/BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD)
**Docs:** [docs.bmad-method.org](https://docs.bmad-method.org/)

**What they have that we don't:**
- **Party Mode:** Multiple agent personas collaborate in a single session (e.g., architect + developer + QA debating a design decision). We run agents sequentially or in parallel but not collaboratively.
- **Scale-adaptive planning:** Auto-adjusts planning depth from bug fix to enterprise system. Our /plan routes to 3 tiers but the routing is manual.
- **34+ built-in workflows** (vs. our ~14 BMAD commands).
- **bmad-help skill:** Contextual guidance ("I just finished architecture, what next?"). We have SDLC gate hooks but no conversational guidance.
- **Sub-modules:** BMad Builder (custom agent creation), Test Architect (risk-based testing), Game Dev Studio, Creative Intelligence Suite.

**What we have that they don't:**
- Native Claude Code integration (their install is via `npx bmad-method install`)
- Ghost Mode, stack templates, learning system
- Autonomous pipeline (/auto-dev, /auto-ship)

**Adoptable patterns:** Party Mode for collaborative agent sessions, scale-adaptive planning auto-routing, bmad-help contextual guidance, Test Architect risk-based testing.

### 1.6 aj-geddes/claude-code-bmad-skills
**Repository:** [github.com/aj-geddes/claude-code-bmad-skills](https://github.com/aj-geddes/claude-code-bmad-skills)
**Docs:** [aj-geddes.github.io/claude-code-bmad-skills](https://aj-geddes.github.io/claude-code-bmad-skills/)

**What they have that we don't:**
- **70-85% token reduction** through optimized skill format with progressive disclosure.
- **Auto-detection:** Skills activate automatically based on context rather than explicit invocation.
- **Memory integration:** Skills read/write persistent memory across sessions.
- Native Claude Code skill format (vs. our BMAD commands which are markdown-based).

**Adoptable patterns:** Token-optimized skill format, auto-detection triggers, memory-integrated skills.

### 1.7 Superset IDE
**Repository:** [github.com/superset-sh/superset](https://github.com/superset-sh/superset)
**Website:** [superset.sh](https://superset.sh)

**What they have that we don't:**
- **10+ parallel coding agents** via git worktrees — each agent gets an isolated repo copy. Our `/parallel-implement` supports max 5 and `/team-build` supports 3.
- **Agent-agnostic:** Works with Claude Code, OpenAI Codex, Gemini, Cursor Agent, any CLI agent.
- **IDE integration:** VS Code, Cursor, JetBrains, Xcode can open individual worktrees.
- **Minimal disk overhead:** Git worktrees share object store — only checkout differs.

**What we have that they don't:**
- Everything except the worktree parallelism infrastructure.

**Adoptable patterns:** Higher agent parallelism limits (10+), worktree-based isolation as first-class pattern, IDE-per-worktree model.

### 1.8 Expo Agent + MCP Server
**Docs:** [expo.dev/blog/expo-agent-beta](https://expo.dev/blog/expo-agent-beta), [docs.expo.dev/eas/ai/mcp](https://docs.expo.dev/eas/ai/mcp/)

**What they have that we don't:**
- **Expo-tuned Claude Code:** Claude Code with deep knowledge of EAS build pipeline, native APIs, SwiftUI, Jetpack Compose.
- **Expo MCP Server:** Official remote MCP server for Expo projects — build triggers, device management, OTA updates.
- **Expo Skills files:** Structured instruction files that teach AI agents Expo patterns accurately. Usable as drop-in CLAUDE.md content.

**Adoptable patterns:** Framework-tuned agent skills (Expo Skills pattern could be replicated for Flutter, Next.js, etc.), official MCP server integration for mobile CI/CD.

### 1.9 senaiverse/claude-code-reactnative-expo-agent-system
**Repository:** [github.com/senaiverse/claude-code-reactnative-expo-agent-system](https://github.com/senaiverse/claude-code-reactnative-expo-agent-system)

**What they have that we don't:**
- **7 production-grade mobile agents:** Accessibility specialist, design system agent, security agent, performance agent, testing agent — all tuned for React Native/Expo.
- **OWASP mobile security** baked into agent prompts.
- **WCAG 2.2 accessibility** as a first-class concern in the design system agent.

**Adoptable patterns:** Mobile-specific agent specializations (accessibility, performance, security), WCAG/OWASP as built-in agent constraints.

### 1.10 anthropics/claude-code-action (Official GitHub Actions)
**Repository:** [github.com/anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)
**Docs:** [code.claude.com/docs/en/github-actions](https://code.claude.com/docs/en/github-actions)

**What they provide:**
- **@claude mentions:** Trigger code review by mentioning @claude in PR comments/issues.
- **5-axis code review:** Design, readability, performance, security, testability.
- **Multi-provider auth:** Anthropic API, Amazon Bedrock, Google Vertex AI, Microsoft Foundry.
- **Scheduled runs:** Can be triggered on cron schedules — the foundation for autonomous improvement.
- **Companion action:** `anthropics/claude-code-security-review` for dedicated security review.

**What we need for our CI/CD:**
- `claude-code-action` as the engine for our `improve.yml` workflow.
- Scheduled weekly runs that analyze the setup and propose improvements as PRs.
- Security review on every PR to the config repo.

---

## 2. Feature Gap Matrix

| Feature | Our Setup | wshobson | everything-claude | oh-my-claude | VoltAgent | BMAD Official | Superset | Expo Agent |
|---------|-----------|----------|-------------------|--------------|-----------|---------------|----------|------------|
| **Portability (install script)** | NO | NO | NO | NO | NO | YES (npx) | NO | N/A |
| **CI/CD for config** | NO | NO | NO | NO | NO | NO | NO | N/A |
| **Autonomous improvement** | NO | NO | NO | NO | NO | NO | NO | NO |
| **Ghost Mode** | YES | NO | NO | NO | NO | NO | NO | NO |
| **SDLC gate hooks** | YES | NO | NO | NO | NO | NO | NO | NO |
| **Stack templates** | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **Self-learning system** | YES | NO | NO | NO | NO | NO | NO | NO |
| **4-tier model routing** | NO (2-tier) | YES | YES (3-tier) | YES (auto) | NO | NO | NO | NO |
| **Agent count** | 40+ | 112 | 28 | 32 | 127+ | 12+ | 0 | 1 |
| **Preset teams** | NO | YES | NO | NO | NO | YES (Party) | NO | NO |
| **Agent marketplace** | NO | NO | YES | NO | YES | NO | NO | NO |
| **Language specialists** | 2 (TS/Py) | 10+ | 20+ | auto | 20+ | NO | NO | NO |
| **Domain specialists** | NO | YES | YES | NO | YES | NO | NO | YES (mobile) |
| **Parallel agents** | 3-5 | team-based | sequential | 5 (Ultrapilot) | N/A | N/A | 10+ | N/A |
| **Cross-platform** | NO | NO | YES | NO | YES | YES | YES | NO |
| **Auto model routing** | NO | NO | YES | YES | NO | NO | NO | NO |
| **BMAD integration** | YES (14 cmds) | NO | NO | NO | NO | YES (34+ wf) | NO | NO |
| **Custom commands** | 70+ | varies | 24+ | 0 | 0 | varies | 0 | 0 |
| **Lifecycle hooks** | 12 | 0 | varies | 0 | 0 | 0 | 0 | 0 |
| **Token optimization** | partial | YES | YES | YES | NO | YES | N/A | N/A |

---

## 3. Key Opportunities (Ranked by Impact)

### Tier 1: Foundational (Must-Have for v1.0)

1. **Portable installation** — Nobody has a production-grade install script for a Claude Code config repo. `curl | bash` with backup, symlink mode, and --dry-run would be a first-in-market feature. This is the single highest-impact deliverable.

2. **CI/CD for configuration** — No competing setup validates its own config files. shellcheck for hooks, markdownlint for commands/agents, YAML schema validation for templates, actionlint for workflows. This ensures quality doesn't degrade as the setup grows.

3. **Autonomous self-improvement via CI** — Using `anthropics/claude-code-action` on a scheduled cron to analyze the setup and propose improvements (new agents, updated templates, refined rules) as PRs. Nobody does this. Genuine innovation.

### Tier 2: Competitive Advantage

4. **4-tier model routing** — Adopt from wshobson/agents. Map every agent to haiku/sonnet/opus/custom based on task complexity. Expected 30-50% token savings (validated by oh-my-claudecode's metrics).

5. **Agent ecosystem integration** — Import highest-value agents from VoltAgent (language specialists), wshobson (domain specialists), senaiverse (mobile agents). Build agent catalog with capability tags, model tiers, and team assignments.

6. **Template expansion to 16+ stacks** — Our 3 templates are the only ones in the market. Expanding to 16 (web, mobile, specialized, backend) extends an already unique lead. Each template carries CLAUDE.md, AGENTS.md, CI config, and starter files — nobody else does this.

7. **Preset agent teams** — Pre-configured team compositions like `review` (code-reviewer + security-auditor + test-analyzer), `frontend-sprint` (frontend-dev + ui-designer + tdd-test-writer), `fullstack` (architect + backend-dev + frontend-dev + test-writer). Reduces team setup friction.

### Tier 3: Differentiation

8. **Auto model routing** — Beyond static 4-tier assignment, implement oh-my-claudecode's pattern of dynamically selecting model based on task complexity at runtime.

9. **Progressive disclosure in skills** — Adopt wshobson's pattern where skills reveal information incrementally to minimize token usage. Particularly valuable for large agent prompts.

10. **Party Mode** — Adopt BMAD's collaborative agent sessions where multiple personas debate in a single context window. Useful for architecture reviews and design decisions.

---

## 4. What This Setup Does That Nobody Else Does

These are **unique differentiators** that should be prominently featured and protected:

1. **Ghost Mode** — Overnight autonomous pipeline with screen session supervisor, caffeinate (prevents macOS sleep), up to 5 restart attempts with exponential backoff (30→60→120→240s), ntfy.sh push notifications, emergency stop via `touch ~/.claude/ghost-stop`, and session resume on restart. No competitor has anything remotely comparable.

2. **SDLC-Aware PostToolUse Hooks** — When a research.md is written, a hook blocks and tells the user to run /plan. When a design-doc.md is written, a hook checks milestone count and routes to /milestone-prompts or /implement-design. This enforces a consistent development lifecycle through hooks, not documentation. Unique.

3. **Stack Templates with Full Generation** — YAML files that contain init commands, directory structure, starter files (with full source code), CLAUDE.md content, AGENTS.md content, env examples, gitignore additions, and package.json scripts. No other setup generates complete project scaffolds from declarative templates.

4. **Self-Learning System** — Confidence-scored learning records (correction: 0.9, success: 0.75, repeated mistake: 0.85) with search, retrieval, and weekly consolidation (/consolidate). Learnings persist across sessions and can be promoted to CLAUDE.md. Unique.

5. **Unified Workflow Commands** — /plan routes to 3 tiers (Quick Plan / Feature Spec / Full Pipeline), /build routes by size (tiny/small/medium/large), /check runs 3 parallel quality agents, /ship creates conventional commit + PR. The coherence of this system is unmatched.

6. **Budget-Controlled Autonomous Pipelines** — /ghost accepts --budget flag to cap API spending, --hours to limit runtime, and --trust to control permission scope. No competitor exposes budget controls for autonomous operation.

---

## 5. Recommendations for Next Documents

### For Brainstorm Document
1. Explore install.sh designs: symlink vs copy vs GNU Stow — each has tradeoffs
2. Design agent catalog schema: capabilities, model tier, team membership, source (core/community/project)
3. Brainstorm 13 new stack templates with specific framework versions and key differentiators
4. Design `improve.yml` workflow: what does Claude Code analyze? how does it propose changes? how are proposals reviewed?
5. Explore cross-machine learning sync (export/import learnings between machines)
6. Consider agent versioning and deprecation strategies
7. Brainstorm agent health checks (canary tasks that validate agent output structure)

### For Design Document
1. Define the YAML stack template schema formally (JSON Schema)
2. Specify the agent catalog.json schema
3. Design the personal vs. shared config split exhaustively (every file in ~/.claude/ classified)
4. Specify all 3 CI/CD workflows in detail (ci.yml, release.yml, improve.yml)
5. Design the install.sh flow with conflict resolution strategy
6. Document the agent import/adaptation process (how to adapt a VoltAgent agent for our system)

### For Templates
Priority order based on market demand and ecosystem gaps:
1. **Web:** Astro 5 (content sites) → T3 Stack (opinionated fullstack) → SvelteKit (performance) → Remix (edge)
2. **Mobile:** Expo+NativeWind (Tailwind for RN) → Flutter+Supabase (different ecosystem) → Expo+RevenueCat (monetization)
3. **Specialized:** SaaS Starter (auth+billing+dashboard) → AI/ML App (LangChain+vectors) → Chrome Extension → CLI Tool
4. **Backend:** FastAPI+Python (AI/data projects) → Hono+Cloudflare Workers (edge variant)

---

## 6. Sources

| Source | Type | URL |
|--------|------|-----|
| wshobson/agents | GitHub repo | github.com/wshobson/agents |
| everything-claude-code | GitHub repo | github.com/affaan-m/everything-claude-code |
| oh-my-claudecode | GitHub repo + website | github.com/Yeachan-Heo/oh-my-claudecode, ohmyclaudecode.com |
| VoltAgent subagents | GitHub repo | github.com/VoltAgent/awesome-claude-code-subagents |
| BMAD METHOD | GitHub repo + docs | github.com/bmad-code-org/BMAD-METHOD, docs.bmad-method.org |
| claude-code-bmad-skills | GitHub repo + docs | github.com/aj-geddes/claude-code-bmad-skills |
| Superset IDE | GitHub repo + website | github.com/superset-sh/superset, superset.sh |
| Expo Agent | Expo blog + docs | expo.dev/blog/expo-agent-beta, docs.expo.dev/eas/ai/mcp |
| senaiverse RN agents | GitHub repo | github.com/senaiverse/claude-code-reactnative-expo-agent-system |
| Claude Code Action | GitHub repo + docs | github.com/anthropics/claude-code-action |
| Claude Code Security Review | GitHub repo | github.com/anthropics/claude-code-security-review |
| Ralph Loop | GitHub + website | github.com/snarktank/ralph, ralph-wiggum.ai |
| awesome-ralph | GitHub repo | github.com/snwfdhmp/awesome-ralph |
| The Ralph Playbook | Docs | claytonfarr.github.io/ralph-playbook |
| awesome-mcp-servers | GitHub repo | github.com/punkpeye/awesome-mcp-servers |
| MCP market | Website | mcpservers.org, mcpmarket.com |
| Anthropic Agentic Coding Report | PDF | resources.anthropic.com (2026 report) |
| create-t3-app | Website | create.t3.gg |
| Vercel AI Templates | Website | vercel.com/templates/ai |
