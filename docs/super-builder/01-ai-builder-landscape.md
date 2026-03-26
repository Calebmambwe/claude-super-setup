# AI App Builder Landscape: Deep Research Brief

**Researched:** March 2026
**Purpose:** Understand winning patterns across 10 leading AI app builders to inform claude-super-setup's Super Builder design.

---

## 1. Cursor IDE

### Architecture / Approach
Cursor is a VS Code fork — not an extension. Anysphere forked the editor at the kernel level to gain capabilities the VS Code extension API blocks: codebase-wide indexing, atomic multi-file diffs, background cloud agents, and sub-keystroke Tab autocomplete. The codebase is indexed via AST parsing plus semantic embeddings stored in Turbopuffer (their proprietary vector DB), giving up to 272k tokens of retrieval context per task.

The five interaction layers operate at different autonomy levels:
1. **Tab** — ambient, RL-trained autocomplete (sparse MoE architecture, KV-cache optimized, 400M+ requests/day)
2. **Cmd+K** — inline single-file editing with inline diff
3. **Chat** — Q&A with @symbol-driven context injection
4. **Composer** — multi-file atomic editing
5. **Agent** — full autonomous task execution with tool use

### Quality Assurance
- **Checkpoints:** Auto-saves codebase snapshots before major agent changes; hooks trigger git commits at defined steps
- **Cursor Rules (.mdc files):** Project-level instructions in `.cursor/rules/` enforced at every generation. Four rule types: Always Apply, Apply Intelligently, Glob-scoped, Manual. Hierarchy: Team > Project > User.
- **BugBot (2025–2026):** Reviews every PR automatically. Since Feb 2026, BugBot also spins up a cloud fix-agent when it finds a problem — 35%+ of BugBot Autofix suggestions get merged. Resolution rate went from 52% to 76% over six months.

### Iteration Strategy
- Queued messages let developers plan next steps while the agent is running
- Up to 8 parallel agents in isolated git worktrees
- Async subagents can spawn their own subagents (Feb 2026)
- Mid-task clarification: agent can pause and ask a question before proceeding

### Template / Scaffold System
- No built-in template gallery; relies on `.cursor/rules/` to encode scaffold conventions
- AGENTS.md in project root as plain-markdown alternative to .mdc
- Team/Enterprise: org-wide rules pushed via dashboard

### Testing Approach
- Hooks trigger post-write typecheck/lint and pre-commit test runs
- No built-in test generation; relies on the developer or agent to write tests
- BugBot as automated PR reviewer fills the review gap

### Visual Verification
- Agent mode includes browser control (screenshots) via Playwright-style tooling
- No dedicated visual regression pipeline out of the box

### Error Recovery Pattern
- Checkpoints allow rollback to pre-change state
- Agent reads terminal output and self-corrects on compile/test failures
- Max 3 re-attempts configurable via hooks; beyond that the agent surfaces the error to the developer

### Deployment Pipeline
- No built-in deployment. Relies on CI/CD (GitHub Actions, etc.) already present in the repo
- Background agents can open PRs against GitHub, which triggers existing deployment pipelines

### What Makes It Better
The VS Code fork architecture is the key advantage. It gives Cursor a level of integration no extension can match: codebase-wide semantic search, per-keystroke Tab that learns from accept/reject signals, and cloud VMs that check out your actual repo. BugBot closing the PR review loop autonomously is 2026's biggest differentiator.

---

## 2. Same.new (now Same.dev, acquired by Meta 2025)

### Architecture / Approach
Same.dev is a prompt-to-app and URL-to-app platform built on Next.js as the default full-stack output. Its signature feature is **URL cloning at 95% visual accuracy** — you paste a URL, Same screenshots it with Playwright, analyzes the DOM, extracts design tokens (colors, fonts, spacing), and scaffolds a Next.js project that reproduces the visual structure.

Default stack: Next.js + TypeScript + Tailwind CSS. Integrations: GitHub, Neon (Postgres), Supabase, Clerk (auth).

### Quality Assurance
- Token extraction from the live DOM rather than guessing from screenshots
- Live preview + code diffs shown side by side during generation
- Uses the actual source site's CSS variables when available as ground truth

### Iteration Strategy
- Prompt-driven customization after the initial clone
- Each iteration rerenders the live preview, showing diff of what changed
- Continuous conversation context — each prompt builds on the previous state

### Template / Scaffold System
- No static template gallery; the URL itself is the template
- For net-new apps: natural language description → AI selects appropriate Next.js patterns
- Supabase and Clerk integrations are pre-wired scaffolds the agent knows how to insert

### Testing Approach
- No built-in test generation documented
- Relies on post-generation developer testing

### Visual Verification
- Playwright screenshot of the cloned URL before generation
- Live preview of generated output for visual comparison
- The 95% accuracy claim is validated by side-by-side screenshot comparison

### Error Recovery Pattern
- Iterative prompt loop: developer describes what is wrong visually, agent patches
- No automated self-healing documented

### Deployment Pipeline
- GitHub integration for pushing generated repos
- Not a deployment platform itself — hands off to Vercel or the developer's own pipeline

### What Makes It Better
URL-to-app cloning with DOM-level token extraction is the differentiator. Rather than approximating a design from a screenshot, Same.dev reads the actual CSS and reproduces it. For competitive cloning and rapid MVP prototyping from existing inspiration, this is the fastest path.

---

## 3. Bolt.new (StackBlitz)

### Architecture / Approach
Bolt.new runs an entire Node.js development environment inside the browser via **WebContainers** — a WebAssembly-based OS kernel that boots a real Node process in the browser tab with no server required. The AI agent has direct control over the filesystem, terminal, package manager (npm), dev server, and browser console within this sandbox.

The agent generates full-stack code and immediately runs it. There is no "save and deploy" step during iteration — the app is live in the WebContainer while you are still generating it.

**Bolt v2 (October 2025):** Introduced autonomous debugging that reduced error loops by 98%. 2026 additions include team workspaces, multi-framework support, and deployment pipelines.

### Quality Assurance
- The WebContainer runs the code with real Node.js — type errors, missing modules, and runtime crashes surface immediately
- The agent is "aware of errors" through instrumented integration at every WebContainer layer
- Error traces are fed back into the agent context for self-correction
- AutoFix pass scans for common errors after generation

### Iteration Strategy
- Real-time preview: every code change is reflected in the preview panel within milliseconds
- Error messages from the real Node runtime appear in the agent context automatically
- Agent reads console output and re-generates the offending code
- "Fix my errors" button as an explicit trigger for the self-healing loop

### Template / Scaffold System
- Team Templates (2026): turn any existing project into a reusable starter
- Multi-framework: React, Vue, Svelte, Angular, Astro, Next.js, Remix all supported
- No centralized template gallery but community-contributed starters exist

### Testing Approach
- No built-in test generation
- Unit tests can be run inside the WebContainer terminal
- The real-runtime execution is itself a form of smoke testing

### Visual Verification
- The in-browser preview IS the visual verification — developers see the live app alongside the code
- No automated visual regression between versions
- Screenshot-to-code accuracy: competitive with v0 for HTML/CSS reproduction

### Error Recovery Pattern
- WebContainer surfaces real errors (not hypothetical ones) — agent gets actual stack traces
- Bolt v2's autonomous debugging loop: detect error → isolate → patch → re-run → verify (up to 98% error reduction)
- Budget guard on token usage prevents infinite loops

### Deployment Pipeline
- One-click deploy to Netlify, Vercel, or Bolt's own hosting
- GitHub push integration added in 2026
- Deployment pipelines added in early 2026 for enterprise workflows

### What Makes It Better
The WebContainer is Bolt's foundational advantage: real Node.js in the browser means real errors, real previews, and zero environment setup time. No other tool in this list gives the agent access to an actual running process during generation. The 98% error reduction in v2 proves that real-runtime feedback is more effective than static analysis.

---

## 4. v0 (Vercel)

### Architecture / Approach
v0 (rebranded to v0.app in late 2025) is Vercel's AI UI and full-stack code generator. The original v0 was a component generator — prompt in, React + Tailwind + shadcn/ui component out. The February 2026 update evolved it into a full production platform with git integration, a VS Code-style editor, database connectivity (Neon, Snowflake, AWS), agentic workflows, and sandbox runtime.

Technical pipeline: retrieval (grounds the model in existing code), frontier LLM (reasoning, generation), streaming post-processor "AutoFix" (scans for errors and best-practice violations during and after generation). Model variants: v0-1.0-md and v0-1.5-lg (up to 512k context).

### Quality Assurance
- **AutoFix** post-processor: flags errors and pattern violations as the code streams
- Deeply integrated with shadcn/ui — every component on ui.shadcn.com is editable in v0; the registry enforces structural correctness
- Vercel Agent (public beta 2026): automated code review on PRs
- Design system support: the shadcn Registry lets you upload your own tokens; v0 generates code that matches your system without manual overrides

### Iteration Strategy
- Contextual conversation: each prompt builds on the previous, full session context retained
- "Select and refine" UX: click any part of the output and prompt again — only that section is regenerated
- Git panel (Feb 2026): create a branch per chat, open a PR, deploy on merge — iteration feeds directly into a real git workflow
- Sandbox runtime mirrors production — preview deployments behave like real Vercel deployments

### Template / Scaffold System
- shadcn/ui component library as the built-in design system (50+ components, all customizable)
- Vercel's ecosystem (Next.js, Edge Functions, Neon, Clerk, Stripe) as pre-wired scaffolds
- Design system upload: import your own Figma tokens or CSS variables; v0 respects them

### Testing Approach
- No built-in test generation
- Vercel Agent handles PR review (automated code quality gate)
- AutoFix validates patterns at generation time

### Visual Verification
- Screenshot-to-code: leaders in visual accuracy benchmarks (ties with Bolt)
- Upload a screenshot or Figma mockup as the prompt; v0 reproduces it
- Live preview in the sandbox shows the running app

### Error Recovery Pattern
- AutoFix catches errors during streaming — code is corrected before it reaches the developer
- If errors slip through: conversational correction ("this button is misaligned, fix it")
- No automated self-healing loop for runtime errors

### Deployment Pipeline
- Native Vercel deploy: sandbox → branch → PR → merge → production
- Database branches (Neon) created automatically alongside app branches
- Token-based billing aligned with Vercel's infrastructure

### What Makes It Better
v0 wins on UI quality and Vercel ecosystem integration. The shadcn/ui Registry is the best-designed constraint system in this list — it forces generated code into a known component structure, making the output actually maintainable. The Feb 2026 git panel promotion from "prototype toy" to "full git workflow" is the most important recent evolution.

---

## 5. Lovable (formerly GPT Engineer)

### Architecture / Approach
Lovable is a conversation-first, full-stack AI app builder. The LLM agent builds a change plan and generates patches across the frontend (React + TypeScript + Tailwind CSS) and backend (Supabase or Lovable Cloud) simultaneously. Agent Mode (2025) handles complex features autonomously — understanding entire application context, making architectural decisions, implementing complete features without constant prompting.

**Key metrics (March 2026):** 8 million users, $17M ARR, $6.6B valuation (Series B, Benchmark). Claude Sonnet 4.5 integration: 25% fewer errors, 40% faster generation.

Lovable Cloud (2026): built-in PostgreSQL + auth + file storage — no Supabase account required for new projects.

### Quality Assurance
- Change plan validation before execution: agent summarizes what it will change, developer can approve
- Automatic debugging and safety checks after every generation
- 25% fewer errors with Sonnet 4.5 vs prior models
- Visual Edits: click any element on the live preview → describe the change → agent patches only that element

### Iteration Strategy
- Conversation-first: every iteration is a natural language message
- Visual Edits (2025): click-to-edit any element without writing a prompt — lowers friction for visual fixes
- Agent Mode: hands off full feature implementation; only prompts when blocked
- Branching (2025): create feature branches per conversation; branch-based previews

### Template / Scaffold System
- No static template gallery; Lovable Cloud provides the full-stack scaffold automatically
- Auth, database, file storage pre-wired on project creation
- Supabase integration remains for teams with existing Supabase projects

### Testing Approach
- No built-in test generation documented
- Automatic debugging loop fills part of the QA gap
- Lovable's automatic safety checks flag potential issues before deploying

### Visual Verification
- Live preview alongside the conversation
- Visual Edits require visual accuracy — agent must reproduce the pointed-at element correctly
- Screenshot-to-code: competitive but behind v0 and Bolt for pixel accuracy

### Error Recovery Pattern
- Automatic debugging: after every generation, Lovable detects and fixes errors before showing the result
- For persistent errors: conversational correction
- Agent Mode retries autonomously without interrupting the developer

### Deployment Pipeline
- One-click deploy to Lovable hosting, Netlify, or Vercel
- Custom domain support
- Lovable Cloud: database and backend are hosted alongside the frontend — unified deployment

### What Makes It Better
Lovable's Visual Edits feature is uniquely usable for non-developers — pointing and clicking is more accessible than writing prompts. The unified Lovable Cloud (database + auth + frontend in one deploy) eliminates the biggest friction point in the early builder landscape: "now go set up Supabase separately." For accessibility and time-to-first-deploy, Lovable wins.

---

## 6. Devin (Cognition AI)

### Architecture / Approach
Devin is the first "AI software engineer" — not a code generator but an autonomous agent that operates a full developer environment: browser, terminal, code editor, and file system inside a sandboxed Ubuntu VM. Cognition describes Devin's architecture as a "compound system" — a swarm of specialized models orchestrating a workflow rather than a single model.

**Devin 2.0 (April 2025):** Interactive Planning, Devin Search, Devin Wiki. Price dropped from $500/month to $20/month. 83% more junior-level tasks completed per compute unit vs Devin 1.x. PR merge rate: 34% → 67% over 2025.

**Devin 3.0 (2026):** Dynamic re-planning — if Devin hits a roadblock, it alters its strategy without human intervention.

### Quality Assurance
- **Interactive Planning:** Before execution, Devin researches the codebase, proposes a detailed plan, and lets the engineer modify it
- **Devin Wiki:** Automatically generates comprehensive documentation with architecture diagrams — creates a shared understanding baseline
- **Devin Search:** Codebase exploration with citations — Devin cites its reasoning, making decisions auditable
- Test writing: Devin writes tests first-pass; human engineers validate coverage. Coverage rises from 50-60% to 80-90%

### Iteration Strategy
- Dynamic re-planning (v3.0): re-routes around blockers autonomously
- Multiple Devins in parallel: agent-native IDE lets you spin up parallel Devin sessions per task
- Session memory: maintains context across long-running tasks
- Human check-in gates: developer can review progress and redirect mid-task

### Template / Scaffold System
- No template gallery; Devin reads the existing codebase and follows its established patterns
- Devin Wiki generates documentation from the codebase — this becomes the template for future sessions

### Testing Approach
- Best testing story in this list: Devin writes unit tests, integration tests, and documents coverage
- Humans validate coverage logic; code owners still review
- Self-healing: when code fails tests, Devin reads error logs, iterates, and fixes autonomously

### Visual Verification
- Browser access: Devin navigates web apps and visually inspects output
- No automated visual regression system documented

### Error Recovery Pattern
- Self-healing core competency: read error → iterate → fix → re-test, fully autonomous
- Failure escalation: surfaces to developer when it cannot resolve after multiple attempts
- Preserves error context in session memory — doesn't lose track of what failed

### Deployment Pipeline
- Full environment access means Devin can run deployment commands directly
- Integrates with GitHub — opens PRs
- BugBot-equivalent: PR review and fix loop documented

### What Makes It Better
Devin's compound multi-model architecture and enterprise validation (Goldman Sachs, 12,000 developer pilot) set it apart from all others as a production-grade autonomous engineer. Its Interactive Planning workflow — research codebase → propose plan → human approves → execute — is the most professional collaborative model in this list. The Devin Wiki / knowledge-base pattern is unique and extremely powerful for long-lived projects.

---

## 7. OpenHands (formerly OpenDevin)

### Architecture / Approach
OpenHands is an open-source AI software developer platform (45k+ GitHub stars). Like Devin, it gives the AI agent a browser, terminal, and code editor in a sandboxed environment. The key differentiator is openness: any LLM can be plugged in, all tool calls are observable, and the security model is transparent.

**OpenHands Index (January 2026):** A continuously updated leaderboard evaluating models on issue resolution, greenfield apps, frontend development, software testing, and information gathering.

### Quality Assurance
- **SecurityAnalyzer:** Rates every tool call low/medium/high/unknown risk. ConfirmationPolicy controls which risk levels require human approval
- Automatic secrets management: pattern detection + value masking in logs
- **Three-tier testing model:**
  1. Programmatic tests (every commit): mocked LLM, fast CI
  2. LLM-based integration tests (daily): real models, validates reasoning + tool use
  3. Benchmark evaluation (on-demand): SWE-bench, GAIA, HumanEvalFix

### Iteration Strategy
- OpenHands Index drives model selection — always pick the currently best-ranked model for each task type
- Iterative task execution with full tool-call transparency
- Edit validation: integrated linter fires at edit time, blocks syntactically invalid edits before they compound

### Template / Scaffold System
- No template gallery; relies on the model's training and user instructions
- CLAUDE.md / AGENTS.md equivalent: project instructions file

### Testing Approach
- Most rigorous in this list: three distinct testing tiers with different costs and depths
- Edit validation at write time (SWE-agent pattern: integrated linter blocks invalid edits)
- LLM-as-judge combined with human judgment for agent evaluation

### Visual Verification
- Browser-based agent can screenshot web apps
- No dedicated visual regression pipeline

### Error Recovery Pattern
- SecurityAnalyzer gates dangerous operations before execution
- Edit-time linting prevents cascading errors
- Checkpoint-based state: saves successful step state, resumes without full restart
- Graceful abandonment: if agent ignores instructions or loops, restart with clean context (documented explicitly)

### Deployment Pipeline
- Environment access: agent runs deployment scripts
- Docker-native: OpenHands runs in Docker — production-grade isolation out of the box

### What Makes It Better
OpenHands' three-tier testing model and SecurityAnalyzer are the best QA architecture in the open-source space. The edit-time linting pattern (block invalid edits immediately rather than propagating errors) is underutilized by every other tool in this list. Transparency and auditability — every tool call is logged and rated — is essential for enterprise trust.

---

## 8. Manus

### Architecture / Approach
Manus is a general-purpose autonomous agent built by Butterfly Effect. Its core architecture is a **3-agent model** (Planner → Executor → Verifier) running in an E2B Firecracker microVM sandbox (150ms spin-up). The Executor uses CodeAct as its primary action language — executable Python rather than natural language instructions, making actions deterministic.

The **action engine philosophy**: Manus describes itself as "an action engine, not a chat assistant." Its loop: (1) analyze current state, (2) plan/select action, (3) execute in sandbox, (4) observe result — repeat until complete. File system is used as unlimited external memory; the agent writes intermediate results to disk, not context.

**Context engineering (from Manus team's blog):** KV-cache hit rate is the single most important production metric. Stable prompt prefixes, file-system-as-memory, and append-only event streams all serve this goal.

### Quality Assurance
- **Verifier agent role:** Dedicated agent validates every Executor output before it's surfaced
- GAIA benchmark: Manus tops real-world problem-solving benchmarks among autonomous agents
- Failure traces preserved in context intentionally — the model updates its beliefs seeing stack traces
- Never discard error evidence from context

### Iteration Strategy
- Append-only event streams: entire history of actions + failures stays in context
- File-system checkpoints: agent can resume from any prior step
- Dynamic re-planning: Planner updates the task plan based on Executor findings
- Connectors: 64+ MCP integrations, OAuth 2.0 — agent can query external systems to unblock itself

### Template / Scaffold System
- Skills: SKILL.md files in the sandbox filesystem, loaded via 3-tier progressive disclosure (100-token metadata → 5k instructions → full resources)
- Projects: namespaced workspaces with system prompt override + RAG knowledge base
- Library: dual-index (vector DB for semantic + metadata DB for structured recall)

### Testing Approach
- Verifier agent as the primary QA mechanism
- No automated test generation documented
- GAIA benchmark as the external validation standard

### Visual Verification
- Cloud Browser (E2B Firecracker + Playwright): navigates web apps, takes screenshots, injects cookies
- Agent can visually inspect output and describe discrepancies

### Error Recovery Pattern
- SagaLLM pattern: every action has a compensating undo action; on failure, walk back through the log
- Failure traces preserved in context: model learns from stack traces implicitly
- File-system checkpoints: resume without full restart
- KV-cache stability: stable prefix design prevents context corruption from error recovery

### Deployment Pipeline
- Sandbox execution: Manus runs shell scripts, web automation, data processing in Linux sandbox
- No dedicated app deployment pipeline — Manus is a task executor, not an app builder per se
- Can execute deployment commands within the sandbox

### What Makes It Better
Manus's context engineering discipline is the most rigorous in this list. The file-system-as-memory pattern, KV-cache optimization, and append-only event streams are production-proven at scale. The 3-agent Planner/Executor/Verifier model is the cleanest separation of concerns: planning doesn't pollute execution, execution doesn't skip verification. The Skills system (3-tier loading) is the best lazy-loading pattern for large instruction sets.

---

## 9. Replit Agent

### Architecture / Approach
Replit Agent turns Replit's cloud IDE into an AI-first app builder. The agent receives a natural language description, produces a plan, and then scaffolds the entire project: file structure (React frontend + Express backend), API endpoints, database interaction logic, and configuration — all running in Replit's persistent cloud environment.

**2025 progression:** Agent v2 (February) → Agent 3 (September, 2-3x speed improvement) → Design Mode (November, visual editing). Agent 3 can test itself, work for 200 minutes autonomously, and build other agents.

### Quality Assurance
- Plan-before-code: agent outlines its approach before generating any code, giving the developer a review point
- Self-testing (Agent 3): agent runs its own tests as part of the build loop
- Design Mode: visual editor provides a feedback loop for UI correctness

### Iteration Strategy
- Conversational: each message refines the existing project
- Design Mode: click-to-edit for visual changes
- 200-minute autonomous run: agent can work through a full feature without interruption

### Template / Scaffold System
- Built-in project templates: web apps, bots, APIs across multiple languages/frameworks
- No static template gallery separate from the agent — the agent selects patterns based on the description
- Production databases (beta): dedicated databases for live apps

### Testing Approach
- Agent 3 self-testing: runs tests autonomously and iterates
- No structured test generation pipeline

### Visual Verification
- Design Mode (November 2025): visual editing interface shows the live app
- Browser preview built into the IDE

### Error Recovery Pattern
- Agent reads compilation errors and runtime crashes in the Replit console
- Autonomous iteration: agent re-runs until the app works or surfaces a question

### Deployment Pipeline
- Native Replit deploy: autoscaling, static, scheduled, and reserved VM options
- One-click from the IDE — no configuration needed
- Domain assignment: instant `.replit.app` URL, custom domain support

### What Makes It Better
Replit's advantage is **everything in one place**: IDE + database + deployment + hosting + auth (Replit Auth), all managed, no external accounts. For beginners and solo builders, eliminating every integration point is worth more than any individual feature. The 200-minute autonomous run demonstrates genuine deep-work capability that time-limited alternatives cannot match.

---

## 10. Claude Code

### Architecture / Approach
Claude Code is Anthropic's CLI-first coding agent. It runs in the terminal with access to the full filesystem, shell, and web. It is not an IDE and not a web app — it is a composable command-line tool that can be orchestrated via scripts, hooks, and subagents. The architecture is extensible by design: CLAUDE.md for project context, slash commands for custom workflows, hooks for lifecycle events, MCP for external tool integration, and subagents for parallel execution.

**Model:** Claude Sonnet 4.6 (execution) with optional Opus 4.6 for planning (opusplan mode). Context: ~1M token window. Token efficiency: 5.5x fewer tokens per task compared to Cursor (Cursor vs Claude Code benchmark 2025).

### Quality Assurance
- **Hooks (21 lifecycle events):** PreToolUse blocks dangerous operations; PostToolUse runs typecheck/lint after every edit; Stop validates completeness before session ends
- **CLAUDE.md:** Project-level behavioral contract — enforces coding conventions, forbidden patterns, required libraries
- **Budget guard:** 200 tool calls max, 20 subagents max per session — prevents runaway cost loops
- **protect-files.sh:** Guards .env, lockfiles, .git, settings.json from accidental modification
- Code review via dedicated Opus-powered review subagent

### Iteration Strategy
- Subagents for parallel execution: spawn multiple agents, each working a different task branch simultaneously
- Queued messages while agent runs
- /auto-build-all: dependency-ordered parallel task execution (max 3 agents)
- Ralph Loop: plan → implement → verify → fix per task, with max 3 fix attempts before escalating

### Template / Scaffold System
- 22+ stack templates in `~/.claude/config/stacks/` covering web, API, mobile, CLI, Chrome extension, AI/ML
- Each template includes: design tokens, CI/CD, E2E tests, Docker, README
- Skills system: `~/.claude/skills/` — reusable instruction sets (design-system, backend-architecture, docker, bmad)
- Stack preview gallery (Playwright screenshots of each template's live demo)

### Testing Approach
- PostToolUse hook runs `pnpm test && pnpm lint && pnpm typecheck` after every file write
- Three-phase verification: per-task tests → full suite → visual verification
- 166 unit tests + 5 integration test suites in claude-super-setup itself
- Test generation: `/generate-tests` command produces tests for any function/module

### Visual Verification
- Playwright MCP for browser control: navigate → screenshot → compare
- `/visual-verify` command: starts dev server, takes screenshots at 3 viewports (390px, 768px, 1440px), captures console errors, checks accessibility
- `/visual-regression` command: snapshot comparison between versions
- `/capture-preview` command: caches Playwright screenshots for all stack templates

### Error Recovery Pattern
- Ralph Loop: per-task plan → implement → verify → fix (max 3 attempts)
- Self-healing hooks: PostToolUse detects typecheck failures, triggers immediate correction
- Checkpoint pattern via git commits at hook events — rollback available
- Budget guard prevents token-burn error loops
- /rollback command: reverts merged PR, reopens affected tasks in tasks.json

### Deployment Pipeline
- `/auto-ship` → `/check` → conventional commit → `gh pr create` → deploy preview
- `/ci-setup` scaffolds the full CI/CD pipeline early in every project
- Telegram notification sent on phase completion (build done, check done, PR created)
- VPS sync: Mac ↔ VPS three-way sync for parallel work

### What Makes It Better
Claude Code's composability is its moat. No other tool in this list lets you build a custom pipeline: you compose skills, hooks, subagents, MCP tools, and slash commands into workflows that exactly match your team's process. The BMAD pipeline (researcher → product brief → PRD → architecture → sprint planning → dev story) is the most complete SDLC in any AI builder. The ~1M token context window enables working on large codebases without retrieval degradation.

---

## Synthesis: Winning Patterns Across All 10 Tools

| Pattern | Best Exemplar | How It Wins |
|---------|---------------|-------------|
| Real-runtime feedback | Bolt.new (WebContainers) | Real Node.js errors beat simulated errors every time |
| Visual QA | v0, Lovable (Visual Edits) | Click-to-verify is faster than describe-to-verify |
| Pre-execution planning | Devin (Interactive Planning) | Human approval before execution prevents wasted runs |
| Edit-time linting | OpenHands / SWE-agent | Block invalid edits immediately, don't propagate |
| Dedicated Verifier agent | Manus (3-agent model) | Separation of concerns between building and validating |
| Codebase memory | Devin (Wiki + Search) | Long-lived projects need persistent knowledge of the codebase |
| Context engineering | Manus (KV-cache, file-system-as-memory) | Cost and latency are determined by context discipline |
| Design system as constraint | v0 (shadcn Registry) | Generated code that fits a registry is maintainable code |
| One-command full-stack | Replit, Lovable | Eliminating integration friction beats any individual feature |
| BugBot loop | Cursor | Autonomous PR review + fix agent closes the ship loop |
| Skills / rules | Cursor (.mdc), Claude Code (SKILL.md) | Reusable instruction sets are compound-interest investments |
| Composable pipelines | Claude Code | Custom workflows built from primitives beat fixed workflows |

---

## Sources

- [Cursor v1.0 milestone: BugBot and background agents](https://devclass.com/2025/06/06/cursor-ai-editor-hits-1-0-milestone-including-bugbot-and-high-risk-background-agents/)
- [Cursor AI Review 2026](https://aitoolanalysis.com/cursor-ai-review/)
- [Cursor February 2026 Updates: Bugbot Autofix](https://www.theagencyjournal.com/whats-new-in-cursor-february-2026-updates-that-actually-matter/)
- [Bolt.new GitHub](https://github.com/stackblitz/bolt.new)
- [Bolt.new Review 2025](https://trickle.so/blog/bolt-new-review)
- [Bolt.new AI Builder: 2026 Review](https://www.banani.co/blog/bolt-new-ai-review-and-alternatives)
- [v0 Complete Guide 2026](https://www.nxcode.io/resources/news/v0-by-vercel-complete-guide-2026)
- [The New v0 Is Ready for Production](https://neon.com/blog/the-new-v0-is-ready-for-production-apps-and-agents)
- [v0 Design Systems Docs](https://v0.app/docs/design-systems)
- [Lovable Architecture: System Design Space](https://system-design.space/en/chapter/lovable-startup-architecture/)
- [Lovable Review 2026](https://www.taskade.com/blog/lovable-review)
- [Lovable + Supabase Integration](https://docs.lovable.dev/integrations/supabase)
- [Devin Annual Performance Review 2025](https://cognition.ai/blog/devin-annual-performance-review-2025)
- [Devin 2.0 Overview](https://cognition.ai/blog/devin-2)
- [Devin Interactive Planning Docs](https://docs.devin.ai/work-with-devin/interactive-planning)
- [OpenHands GitHub](https://github.com/OpenHands/OpenHands)
- [OpenHands Index January 2026](https://openhands.dev/blog/openhands-index)
- [Manus Architecture: GitHub Gist](https://gist.github.com/renschni/4fbc70b31bad8dd57f3370239dccd58f)
- [Context Engineering for AI Agents: Manus Blog](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)
- [How Manus Uses E2B](https://e2b.dev/blog/how-manus-uses-e2b-to-provide-agents-with-virtual-computers)
- [Replit 2025 in Review](https://blog.replit.com/2025-replit-in-review)
- [Replit Review 2026](https://www.superblocks.com/blog/replit-review)
- [Claude Code Sub-Agents Docs](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Hooks Docs](https://platform.claude.com/docs/en/agent-sdk/hooks)
- [Cursor vs Bolt vs Lovable 2026](https://lovable.dev/guides/cursor-vs-bolt-vs-lovable-comparison)
- [Screenshot to Code Benchmark](https://research.aimultiple.com/screenshot-to-code/)
- Internal: `/Users/calebmambwe/claude_super_setup/docs/super-builder/09-vision.md`
- Internal: `/Users/calebmambwe/claude_super_setup/AGENTS.md`
- Internal memory: `reference_cursor_ide_same_new.md`, `project_manus_architecture_research.md`, `reference_enterprise_agent_reliability.md`
