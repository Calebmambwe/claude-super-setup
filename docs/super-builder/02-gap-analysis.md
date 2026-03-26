# Gap Analysis: claude-super-setup vs. Best AI App Builders

**Researched:** March 2026
**Purpose:** Identify exactly what claude-super-setup lacks compared to the 10 leading AI builders, prioritized by impact.

---

## How to Read This Document

Each section names a competitor's **winning pattern**, assesses what claude-super-setup has today, and then specifies the exact gap with a priority rating.

Priority scale:
- **P0** — Blocks the "best autonomous app builder" goal. Build immediately.
- **P1** — Significantly degrades output quality. Build in Sprint 1.
- **P2** — Meaningful UX/DX improvement. Build in Sprint 2.
- **P3** — Nice-to-have polish. Backlog.

---

## Gap 1: Real-Runtime Error Feedback (vs. Bolt.new)

**What Bolt has:** WebContainers run actual Node.js in the browser. Every error is a real runtime error with a real stack trace fed directly into the agent context. Bolt v2 reduced error loops by 98% because errors are real, not hypothetical.

**What claude-super-setup has:** Static analysis hooks (typecheck, lint, tsc) run after every file write via PostToolUse hooks. We catch type errors and lint violations early. We do NOT have a running dev server that the agent can query.

**The gap:** We never run the app during the build phase. An app can pass all type checks and still have runtime errors (missing env vars, wrong API endpoints, broken hydration, CORS failures) that only appear when actually executed. There is no running process the agent can observe.

**Impact:** The most critical class of errors — runtime failures — are invisible until `/visual-verify` runs at the end of the pipeline. By then, the agent must trace backward through many files to find the cause.

**Fix:** `/auto-build` should start a background dev server at the beginning of Phase 3 (Build). PostToolUse hooks should check server health (HTTP 200) after every component write. Console errors should be captured via Playwright and fed back to the agent in the same loop. This mirrors Bolt's "instrumented at every layer" model.

**Priority: P0**

---

## Gap 2: Visual Edit / Click-to-Fix UX (vs. Lovable, v0)

**What they have:** Lovable's Visual Edits let you click any element on the live preview and describe a change — no prompt needed. v0's "select and refine" lets you highlight any generated section and re-prompt only that part.

**What claude-super-setup has:** `/visual-verify` takes screenshots and reports errors textually. The developer must describe what they see in a follow-up prompt. There is no click-to-target mechanism.

**The gap:** After `/visual-verify` captures a screenshot showing a misaligned button, the developer must describe it in natural language: "the submit button has 8px padding instead of 12px." In Lovable/v0, they click the button and say "fix the padding." The cognitive load gap is significant.

**Impact:** Visual fix iteration is the most common action after first generation. Making it harder slows the pipeline's inner loop.

**Fix (pragmatic):** Playwright DOM snapshot pinpoints elements by CSS selector. The agent can pair the screenshot with the DOM snapshot, identify the misaligned element's selector, and generate a targeted fix prompt automatically. The developer sees "I found the issue in `Button.tsx` at selector `#submit-btn` — applying fix." This approximates the click-to-fix UX within the CLI model.

**Priority: P1**

---

## Gap 3: Pre-Execution Planning Gate (vs. Devin)

**What Devin has:** Interactive Planning — before Devin writes a single line, it researches the codebase, proposes a detailed step-by-step plan with file names and decisions, and waits for the engineer to approve or modify it.

**What claude-super-setup has:** `/auto-plan` generates a PRD + architecture doc + tasks.json. The human approves the plan before `/auto-ship` starts. This is structurally similar.

**The gap (subtle but important):** Devin's plan is codebase-specific — it reads your actual files, identifies the specific functions to modify, and cites them in the plan. Our `/auto-plan` produces an abstract plan (task names + acceptance criteria) without grounding in which specific files/functions will be touched. This creates a divergence between planned and actual scope.

**Impact:** Developers discover scope surprises mid-build rather than at planning time. The human approval gate is less useful if the plan doesn't name the files.

**Fix:** Enhance `/auto-plan` to include a "File Impact Map" phase: after task decomposition, run Grep across the codebase to identify which files each task will modify. Append the file list to each task in tasks.json. The human reviews "Task 3: add payment form — will modify `src/components/PaymentForm.tsx`, `src/api/payments.ts`, `src/lib/stripe.ts`."

**Priority: P1**

---

## Gap 4: Dedicated Codebase Knowledge Base (vs. Devin Wiki)

**What Devin has:** Devin Wiki auto-generates comprehensive documentation for any repository — architecture diagrams, component explanations, data flow diagrams — and updates it as the codebase evolves. This becomes a shared knowledge base that every future Devin session inherits.

**What claude-super-setup has:** AGENTS.md captures gotchas and patterns from past sessions (manually). PROJECT_ANCHOR.md captures the current goal. HANDOVER.md captures session state. The knowledge-rag MCP provides per-project SQLite RAG over files in `docs/`.

**The gap:** Our knowledge is written by humans (AGENTS.md) or requires the developer to put documents in `docs/`. There is no automatic extraction of architectural knowledge from the codebase itself. A new session has no understanding of why the code is structured the way it is — only what the developer bothered to document.

**Impact:** Every new session re-reads the codebase from scratch. Context budget is consumed re-discovering what Devin Wiki would surface instantly. More importantly, undocumented architectural decisions get violated by agents who don't know about them.

**Fix:** Implement a `/codegen-wiki` command that runs at the end of `/auto-ship`: read the key files, generate a Mermaid component diagram, document the data flow, extract all env var requirements, and write to `docs/architecture.md`. The knowledge-rag MCP then auto-indexes this. Future sessions start with architectural context without reading code.

**Priority: P1**

---

## Gap 5: Edit-Time Linting / Validation (vs. OpenHands / SWE-agent)

**What they have:** An integrated linter that fires at edit time — before the file is saved. If the agent generates syntactically invalid code, the linter blocks the write immediately and forces a correction. Errors never propagate into the file system.

**What claude-super-setup has:** PostToolUse hooks run `pnpm typecheck` and `pnpm lint` AFTER the file is written. This means an invalid file exists on disk briefly. In a multi-file agent session, subsequent tool calls may read the broken file and compound the error.

**The gap:** Write → lint is correct, but lint-before-write is more precise. If Task 3 writes a broken import and Task 4 reads that file before the PostToolUse hook fires, Task 4 inherits the error. The hook fires after each individual tool call, but subagents running in parallel can observe the broken intermediate state.

**Impact:** In parallel agent runs (`/auto-build-all` with 3 agents), agent B can read a file that agent A just wrote but whose PostToolUse hook hasn't fired yet. This is a race condition that causes cascading errors in parallel builds.

**Fix:** For parallel builds, implement a file-write lock pattern: each agent writes to a `.pending` temp file, runs lint/typecheck on it, and only moves it to the actual path on success. The lock ensures the real file path always contains valid code. For serial builds, the existing PostToolUse approach is sufficient.

**Priority: P2** (only affects parallel builds; serial builds are fine)

---

## Gap 6: In-Browser / Sandboxed Runtime (vs. Bolt.new, Replit)

**What they have:** Bolt has WebContainers (Node.js in the browser, no server). Replit has persistent cloud VMs where the app runs continuously alongside the agent.

**What claude-super-setup has:** The agent runs locally on the Mac or VPS. Development servers must be started manually or via the `/visual-verify` command. There is no persistent sandbox that runs the app between sessions.

**The gap:** App state between agent sessions is not preserved. Each `/visual-verify` starts a fresh dev server, which may take 10-30 seconds. There is no equivalent of Replit's "always-on" app that the agent can probe at any time.

**Impact:** The feedback cycle between "write code" and "see it running" is longer than in Bolt/Replit. This is a fundamental architectural difference, not a feature gap.

**Fix (pragmatic, not full WebContainers):** The VPS already runs 24/7. Define a pattern where `/auto-build` keeps the dev server running in a tmux session throughout the build phase. `/visual-verify` connects to the already-running server instead of starting a new one. This gives ~90% of the benefit without needing WebContainers. Add a `DEV_SERVER_PID` tracker to the build session state.

**Priority: P1** (significant friction reduction)

---

## Gap 7: Template Gallery with Visual Previews (vs. v0, Bolt)

**What they have:** v0 and Bolt have visual template browsers where you can see a screenshot of what the template looks like before selecting it. Bolt's Team Templates let any project become a reusable starter.

**What claude-super-setup has:** 22+ stack templates in `~/.claude/config/stacks/` as YAML files. `/preview-templates` and `/capture-preview` commands exist and use Playwright to capture screenshots. The gallery is functional but not surfaced in the main workflow.

**The gap:** The gallery is not integrated into the main user-facing workflow. When a developer runs `/auto-dev "build a SaaS dashboard"`, they don't see template previews before the agent selects `saas-starter.yaml`. The selection is invisible.

**Impact:** Developers cannot validate template selection before a build starts. If the wrong template is chosen, they discover it after generation.

**Fix:** Modify `/auto-plan`'s first step to: (1) identify 2-3 candidate templates from the description, (2) render their preview images in the terminal (iTerm2 inline images) or describe them concisely, (3) present the selection as a human gate. This adds one interaction point but prevents template mismatch surprises.

**Priority: P2**

---

## Gap 8: Automated PR Review + Fix Agent (vs. Cursor BugBot)

**What Cursor has:** BugBot reviews every PR automatically and, since Feb 2026, spins up a cloud fix-agent when it finds problems. 35%+ of fixes get merged. The human never needs to context-switch back into the code.

**What claude-super-setup has:** `/check` runs code-review + security-audit + test/lint/typecheck in parallel before every PR. These are agent-based reviews but they run once at ship time, not continuously on every PR update.

**The gap:** Once a PR is created, there is no ongoing review agent watching it. If a reviewer requests changes or CI fails after the PR is opened, there is no automated agent to address the feedback. The developer must context-switch back manually.

**Impact:** For teams doing multiple PRs per day, the manual re-engagement after PR feedback is a recurring friction point. BugBot eliminates this entirely.

**Fix:** Add a `/watch-pr PR#` command that runs as a background process: poll the PR every N minutes for new review comments, failed CI runs, or merge conflicts. When detected, spawn a subagent to address the specific comment or fix the CI failure and push a new commit. This is automatable via `gh pr view --json reviews,checks`.

**Priority: P2**

---

## Gap 9: One-Command Full-Stack with No External Accounts (vs. Lovable Cloud, Replit)

**What they have:** Lovable Cloud and Replit provide database + auth + storage + hosting all in one command — no Supabase account, no Vercel account, no configuration. Zero external dependencies.

**What claude-super-setup has:** The `/auto-dev` pipeline scaffolds the full stack but requires the developer to have Supabase, Clerk, and Vercel accounts set up, environment variables configured, and external services linked. The scaffold is complete but the wiring is manual.

**The gap:** `claude-super-setup` produces production-grade code but requires production-grade infrastructure setup. Lovable produces simpler code but zero-friction deployment. For the target persona (solo builders, rapid MVPs), the setup cost of external services is a real barrier.

**Impact:** Time-to-first-running-app is significantly longer for claude-super-setup than for Lovable or Replit. This is partly intentional (we build more production-grade output) but the friction should be acknowledged and reduced.

**Fix:** Create a `/quick-start` command that automatically provisions Supabase (via Supabase MCP), Vercel (via Vercel CLI), and generates the `.env` file with all keys — effectively automating the "go set up your external accounts" step. Not zero accounts, but zero manual configuration. Every service gets provisioned in one command.

**Priority: P1**

---

## Gap 10: Context Engineering Discipline (vs. Manus)

**What Manus has:** Every architectural decision in Manus is optimized for KV-cache hit rate: stable prompt prefixes, file-system-as-memory (never context), append-only event streams, token budgets per session. The result is consistently fast, consistently cheap, predictable behavior.

**What claude-super-setup has:** Budget guard (200 tool calls, 20 subagents). /compact triggered at 65% context. Prompt caching via stable CLAUDE.md prefixes. These are good but ad-hoc.

**The gap:** There is no explicit token budget allocation plan per session type. A `/auto-dev` for a 50-file SaaS app and a `/scaffold` for one entity use the same defaults. There is no mechanism for the agent to "compress" older context mid-session the way Manus does.

**Impact:** Long multi-hour sessions degrade in quality as context fills. The agent starts losing track of earlier decisions. This is the most common complaint about long autonomous runs.

**Fix:** Implement session-type budgets: define `context_budget.yaml` with allocations per command type (e.g., auto-dev: 300K tokens max, scaffold: 50K tokens max). Add a `PostToolUse` hook that checks current token count against budget and triggers `/compact` automatically when approaching the limit. Adopt Manus's "write intermediate results to disk, not context" principle — after each completed task, write a summary to `docs/build-log.md` and remove the raw working context.

**Priority: P1**

---

## Gap 11: Design Quality Engine (vs. v0, Lovable)

**What they have:** v0 generates components that match the shadcn/ui Registry precisely — every component is structurally correct and visually polished by default. Lovable generates apps that are visually complete even at MVP stage.

**What claude-super-setup has:** A design-system skill (`~/.claude/skills/design-system/SKILL.md`) and PostToolUse compliance hooks. The skill enforces token usage over hardcoded values. We have design tokens for spacing, color, radius, shadow.

**The gap:** The design-system skill is a set of instructions, not a component registry. There is no built-in component library equivalent to shadcn/ui that the agent can pull from. When the agent builds a `PaymentForm`, it generates it from scratch rather than composing from a verified component library.

**Impact:** Generated components vary in quality depending on how well the model interprets the design-system instructions. Components built from scratch have more visual inconsistency than components pulled from a registry.

**Fix:** Build a local shadcn-equivalent registry at `~/.claude/skills/design-system/registry/`. Each component is a `.tsx` file with the token-compliant implementation. When the agent needs a `Button`, `Modal`, `DataTable`, etc., it reads from the registry rather than generating from scratch. This is the design-system-as-law principle from the vision doc — the registry is the law.

**Priority: P0** (this is what the vision doc calls the "Design Quality Engine")

---

## Gap 12: Codebase-Aware Session Initialization (vs. Devin, Cursor)

**What they have:** Devin automatically searches the codebase before every session. Cursor indexes the entire repo into Turbopuffer on startup and uses embedding-based retrieval. Both tools "know" the codebase before any prompt is entered.

**What claude-super-setup has:** HANDOVER.md, PROJECT_ANCHOR.md, and the session protocol (HANDOVER → tasks.json → PROJECT_ANCHOR → work). The knowledge-rag MCP provides RAG over indexed documents.

**The gap:** The session protocol requires the developer to maintain HANDOVER.md. If it goes stale, the agent starts without current context. There is no automatic codebase indexing that gives the agent a baseline understanding of the project without any human-authored document.

**Impact:** Stale HANDOVER.md is the most common cause of goal drift and repeated mistakes in long projects. The agent does work that has already been done, or makes decisions that conflict with prior choices, because HANDOVER wasn't updated.

**Fix:** Add an automatic pre-session scan: at the start of every major command (`/auto-dev`, `/auto-plan`, `/build`), run a lightweight codebase scan: read `package.json`, count files per directory, check git log for last 5 commits, read AGENTS.md, check for open tasks in `tasks.json`. Write a 200-word "Current State" summary to a temp file and include it in the session prompt. This gives a live codebase snapshot that supplements (and corrects) HANDOVER.md.

**Priority: P1**

---

## Priority Summary

| # | Gap | Priority | Effort Estimate |
|---|-----|----------|-----------------|
| 1 | Real-runtime error feedback (dev server in build loop) | **P0** | Large |
| 11 | Design quality engine / component registry | **P0** | Large |
| 2 | Visual edit / click-to-fix (DOM-targeted patches) | P1 | Medium |
| 3 | Pre-execution file impact map in planning | P1 | Small |
| 4 | Auto-generated codebase wiki (architecture docs) | P1 | Medium |
| 6 | Persistent dev server during build phase (VPS tmux) | P1 | Small |
| 9 | One-command full-stack provisioning (/quick-start) | P1 | Medium |
| 10 | Context engineering discipline (session budgets + auto-compact) | P1 | Medium |
| 12 | Automatic pre-session codebase scan | P1 | Small |
| 5 | Edit-time linting for parallel builds | P2 | Medium |
| 7 | Template gallery surfaced in planning gate | P2 | Small |
| 8 | Automated PR watch + fix agent | P2 | Medium |

---

## What claude-super-setup Already Does Better

This analysis surfaces gaps, but it is equally important to know where we lead:

| Advantage | Why It Matters |
|-----------|---------------|
| 22+ production-grade templates with full CI/CD | Most builders have 5-10 templates, none with CI/CD included |
| BMAD full SDLC pipeline (brief → PRD → architecture → stories) | No other tool has a structured product engineering process |
| Context7 integration (non-negotiable, non-guessable APIs) | Prevents the hallucinated API signature problem common in all builders |
| Hooks with 21 lifecycle events | Cursor has hooks; no web-based builder has this level of pipeline control |
| ~1M token context | Enables large-codebase work that Cursor (272k) and web builders (~100k) cannot |
| Skills system (SKILL.md files) | The closest equivalent to Manus's 3-tier skill loading in any open setup |
| VPS + Mac parallel execution | No other builder has a second machine running builds simultaneously |
| Telegram-driven autonomous dispatch | No other builder has asynchronous task dispatch via messaging |
| Self-improvement ledger | Unique: the system gets better with every project via recorded learnings |
| Budget guard (200 tool calls, 20 subagents) | Prevents the $40 runaway API burn documented in the research |

---

## Recommended Build Order

**Sprint 1 (P0 + fastest P1s):**
1. Component registry (`~/.claude/skills/design-system/registry/`) — the foundation everything else depends on
2. Dev server in build loop — `/auto-build` keeps server running, PostToolUse checks health
3. File impact map in `/auto-plan` — small change, huge planning clarity improvement
4. Automatic pre-session codebase scan — small script, prevents the biggest cause of goal drift
5. Context budget config + auto-compact hook — protects long sessions

**Sprint 2 (remaining P1s + P2s):**
6. `/codegen-wiki` command — codebase knowledge base generation
7. Persistent VPS dev server pattern (tmux session)
8. `/quick-start` provisioning command
9. DOM-targeted visual patch (pair screenshot + DOM snapshot for targeted fixes)
10. Template gallery in planning gate
11. `/watch-pr` background agent
12. Parallel build file-write lock

---

## Sources

- Primary: Research from `01-ai-builder-landscape.md` in this directory
- Internal: `/Users/calebmambwe/claude_super_setup/docs/super-builder/09-vision.md`
- Internal: `/Users/calebmambwe/claude_super_setup/AGENTS.md`
- Internal: `/Users/calebmambwe/claude_super_setup/commands/` (visual-verify.md, scaffold.md, clone-app.md, capture-preview.md)
- Internal skills: `/Users/calebmambwe/.claude/skills/design-system/`
- Internal stacks: `/Users/calebmambwe/.claude/config/stacks/` (22 YAML files)
- Internal memory: `reference_cursor_ide_same_new.md`, `project_manus_architecture_research.md`, `reference_enterprise_agent_reliability.md`
