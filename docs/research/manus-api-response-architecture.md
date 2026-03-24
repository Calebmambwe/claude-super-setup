# Manus.ai Agent — Direct API Response on Architecture

**Date:** 2026-03-24
**Source:** Direct interaction with Manus API (task fmpbGziE44mtAW3v5Zg6EE)
**Model:** manus-1.6-lite-adaptive
**Cost:** 34 credits

---

## Key Patterns from Manus's Own Description

### 1. Task Decomposition: Hierarchical Plan-and-Execute
- Goal → Phases → Atomic Actions (ReAct loop: Thought → Action → Observation)
- **Dynamic re-planning** after each observation — plan is never static
- Three persistence levels: Goal (permanent), Phase (updated on progress), Step (transient)

### 2. Context Management: Layered Memory
- **Working Memory:** immediate LLM context window (last few Thought-Action-Observation rounds)
- **File-Based Memory:** sandbox filesystem as primary persistent store — offload and reload on demand
- **State Summarization:** compress old history into a "State Document" when approaching context limit
- **Knowledge Retrieval:** treat project directory as RAG source via glob/grep

### 3. Failure Handling: Diagnostic-Correction Cycle
- **Root Cause Analysis** before retry (not blind retry)
- Three strategies: retry with modification, alternative tooling, escalation
- **Max 3 consecutive failures** then halt for human input
- Switch tools if one fails consistently (e.g., browser → curl)

### 4. Key Design Patterns
- **Sandbox Pattern:** isolated VM = consistent ground truth
- **Tool-Augmented Reasoning:** "know how to find out" > "know things"
- **Explicit Planning State:** visible, mutable plan as "instruction pointer"
- **Multimodal Feedback:** screenshots + text = richer perception

### 5. Multi-Agent Coordination
- **Sequential Hand-off:** phase completes → pass state to next
- **Blackboard Architecture:** shared filesystem, agents read/write asynchronously
- **Manager-Worker:** orchestrator decomposes, workers execute, manager aggregates

### 6. Tool Selection: Capability Mapping + Least Privilege
- Priority: File/Shell tools → Search/Browser → Specialized APIs
- Use simplest tool that works (grep before browser search)
- Match tool to gap between current state and next milestone

### 7. Quality Assurance: Multi-Step Verification
- **Self-Correction Loop:** review phase before delivery
- **Execution-Based Validation:** run tests, lint, build in sandbox — observation of pass = QA
- **Consistency Checks:** cross-validate data from multiple sources
- **Final Output Formatting:** dedicated formatting phase

---

## Actionable Patterns for Our System

| Manus Pattern | Our Equivalent | Gap | Action |
|--------------|---------------|-----|--------|
| Dynamic re-planning | Static tasks.json | Plan never updates mid-execution | Add plan revision step after each task completion |
| File-based memory offload | pipeline-checkpoint.json only | No task-level scratch files | Create .claude/task-scratch/{id}.md per task |
| Max 3 failures then halt | MAX_ATTEMPTS=3 (just set) | Already aligned | Done |
| Root cause before retry | Fix cycle prompt | Needs "try different approach" guidance | Add to auto-build prompt |
| Explicit plan state | tasks.json + checkpoint | Plan not re-read each iteration | Add attention anchoring (from our earlier research) |
| Blackboard architecture | Git worktrees | Already similar pattern | No change needed |
| Execution-based QA | /check runs tests | Already covers this | No change needed |

---

## Manus vs Our System — Combined Research Summary

Combining the blog research (9 patterns) with this direct API response (7 patterns), the top 5 changes by impact:

1. **Attention anchoring** — re-read acceptance criteria every iteration (both sources confirm)
2. **KV-cache prefix stability** — move dynamic content to tail (blog source, 10x cost savings)
3. **Independent verifier agent** — separate from builder (blog source)
4. **Dynamic re-planning** — update plan after each observation, not just at start (API source)
5. **File-based context offload** — task scratch files for intermediate results (both sources confirm)
