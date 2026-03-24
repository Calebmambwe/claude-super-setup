# Research: Manus.ai Super Agent Architecture

**Date:** 2026-03-24
**Sources:** 7 (engineering blog, system prompt gist, arXiv paper, E2B case study, OpenManus)
**Confidence:** High

---

## Top 3 Patterns to Implement

### 1. Attention Anchoring (Priority: IMMEDIATE)

**What Manus does:** Re-reads `todo.md` every single iteration to keep goals in active attention window. LLMs suffer "lost in the middle" — facts 50K tokens back are recalled poorly.

**Our gap:** Task acceptance criteria read once at start, drifts out of attention in long runs.

**Fix:** Add to `/auto-build`: "Before each reasoning step, re-read your task's `acceptance_criteria` from tasks.json." Pure prompt change, 5 minutes.

### 2. KV-Cache Prefix Stability (Priority: HIGH)

**What Manus does:** Treats cache hit rate as #1 production metric. Stable prefix = 10x cheaper ($0.30 vs $3.00/MTok). Rules: never change prefix shape, append-only context, consistent serialization.

**Our gap:** Agent prompts include dynamic content (timestamps, file counts) at the top. `/compact` rewrites prefix mid-task = cache-hostile.

**Fix:** Audit `agents/core/*.md` — move dynamic content to tail. Structure each task as a clean invocation with stable prefix rather than compacting within one thread.

### 3. Independent Verifier Agent (Priority: HIGH)

**What Manus does:** Three-agent model: Planner → Executor → Verifier. Verifier is independent — different context, catches blind spots.

**Our gap:** `/auto-build` self-reviews (same context = same blind spots). Ghost Mode review loop is the same agent re-reviewing its own work.

**Fix:** Create `agents/core/verifier.md` accepting `acceptance_criteria + git diff`, returns PASS/FAIL verdict. Wire into `/auto-build` after implement step.

---

## All 9 Patterns

| # | Pattern | What Manus Does | Priority |
|---|---------|-----------------|----------|
| 1 | Attention Anchoring | Re-reads todo.md every iteration | Immediate |
| 2 | KV-Cache Stability | Stable prefix, append-only context, 10x cost savings | High |
| 3 | Independent Verifier | 3-agent model (Planner/Executor/Verifier) | High |
| 4 | File-Based Context | Write observations to files, not keep in context window | Medium |
| 5 | CodeAct | Compose Python scripts as primary action language | Low |
| 6 | Error Preservation | Never erase failed attempts from context | Medium |
| 7 | Complexity Routing | Route high→Opus, medium→Sonnet, low→Haiku per task | Medium |
| 8 | Tool Name Consistency | Prefix-based naming, never change tool list mid-task | Low |
| 9 | Sandbox Isolation | Firecracker microVM per parallel agent | Low (worktrees cover this) |

---

## Comparison: Our System vs Manus

| Capability | Manus | Our System | Gap |
|------------|-------|------------|-----|
| Planner/Executor split | Explicit 3-agent | Single /auto-build loop | Medium |
| Independent Verifier | Yes | Embedded in same loop | Medium |
| KV-cache optimization | Obsessive (10x lever) | Not addressed | High |
| File-based context offload | Primary strategy | Checkpoint only | Medium |
| Attention anchoring | Re-reads every iteration | Reads task once | High |
| Multi-model routing | Complexity-based | Role-based (Opus/Sonnet) | Medium |
| Sandbox isolation | Firecracker microVM | Git worktrees | Low |

---

## Sources

1. [Manus Engineering Blog: Context Engineering for AI Agents](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)
2. [System Prompt Reverse-Engineering (GitHub gist)](https://gist.github.com/renschni/4fbc70b31bad8dd57f3370239dccd58f)
3. [arXiv 2505.02024: From Mind to Machine](https://arxiv.org/html/2505.02024v1)
4. [E2B: How Manus Uses Virtual Computers](https://e2b.dev/blog/how-manus-uses-e2b-to-provide-agents-with-virtual-computers)
5. [OpenManus Architecture Deep Dive](https://dev.to/jamesli/openmanus-architecture-deep-dive-enterprise-ai-agent-development-with-real-world-case-studies-5hi4)
