# Self-Improving Agent Architectures: Research Findings

## Overview

This document captures research findings on self-improving agent architectures, with focus on patterns applicable to coding agents. The core insight: agents that learn from experience compound their effectiveness over time — this is the fundamental advantage we aim to build into the claude_super_setup system.

---

## Three-Tier Taxonomy of Self-Improvement

Self-improvement in AI agents can be classified into three tiers based on the learning signal source:

### Tier 1: Extrinsic Self-Improvement
Learning from external feedback and explicit reward signals.

- **Source**: Human corrections, test pass/fail, linter output, CI results
- **Mechanism**: Supervised fine-tuning, RLHF, correction capture
- **Latency**: Immediate (can update behavior in same session)
- **Examples**: Recording user corrections to the learning ledger, capturing successful patterns from CI passing
- **Relevance to our system**: The `record_learning` MCP pattern — corrections captured at the moment of user feedback

### Tier 2: Intrinsic Self-Improvement
Learning from internal evaluation without external ground truth.

- **Source**: Self-consistency checks, uncertainty estimation, internal critics
- **Mechanism**: Constitutional AI, self-critique, uncertainty-weighted sampling
- **Latency**: Within-session (no human required)
- **Examples**: Generator-Verifier-Updater (GVU) pattern, self-reflection before committing code
- **Relevance to our system**: Pre-commit hooks as verifiers, the `/check` command as an internal critic

### Tier 3: Self-Play Improvement
Learning from agent-vs-agent or agent-vs-environment competition.

- **Source**: Adversarial agent pairs, environment exploration
- **Mechanism**: Self-play reinforcement learning, multi-agent debate
- **Latency**: Async (requires evaluation harness)
- **Examples**: SWE-RL, AlphaCode, code review agent vs implementation agent
- **Relevance to our system**: Benchmark runner evaluating agent against SWE-bench-style tasks

---

## Manus: Context Engineering Patterns

Manus published their production context engineering patterns. These are battle-tested optimizations from a deployed multi-agent system.

### KV-Cache Optimization (100:1 Cost Ratio)
The single most impactful optimization in Manus's system.

- **Cache hits**: $0.30 per million tokens
- **Cache misses**: $3.00 per million tokens
- **Ratio**: 10x difference in cost per token
- **Strategy**: Structure prompts so the static prefix (system prompt, tools, persistent context) is always at the beginning of the context window. Dynamic content (user messages, tool results) goes at the end.
- **Implementation**: Never randomize prompt prefixes. Use consistent, stable system prompts. Append-only context updates.
- **Impact**: At scale, this difference is the line between a profitable and unprofitable agent.

### Error Retention in Context
Counter-intuitive finding: keeping failed attempts in context improves performance.

- **Naive approach**: Remove failed tool calls to save tokens
- **Manus finding**: Failed attempts should stay in context — they prevent re-trying the same failed approach
- **Mechanism**: The error provides an implicit negative example. "I tried this and it failed" is valuable information.
- **Implementation**: Do not truncate error messages. Keep the last N attempts (succeeded or failed) in context.

### todo.md Attention Anchoring
Manus uses a `todo.md` file as a persistent attention anchor in long-horizon tasks.

- **Problem**: LLMs lose track of the overall goal during long multi-step tasks
- **Solution**: Maintain a `todo.md` with current task state. Update it after each step.
- **Mechanism**: The model attends to the file in every context window, reinforcing the goal
- **Implementation**: At task start, write todo.md. After each step, update the checkbox. Reference it explicitly in the system prompt.
- **Our system**: This maps to the task queue / tasks.json pattern already in use

### Filesystem as Memory
Manus treats the filesystem as an external memory store rather than trying to fit everything into context.

- **Problem**: Context windows have limits. Long-running tasks accumulate more state than fits.
- **Solution**: Write intermediate results to files. Read only what's needed.
- **Patterns**:
  - Research results → `research/topic.md`
  - Decision rationale → `decisions/YYYY-MM-DD-feature.md`
  - Partial outputs → `outputs/step-N.json`
- **Retrieval**: Use search tools (grep, glob) to pull specific information from files rather than loading everything into context
- **Our system**: This is already partially in place — `docs/` directory for research, `tasks.json` for task state

### Controlled Diversity via Temperature
Manus found that fixed-low-temperature outputs are suboptimal for debugging tasks.

- **Standard approach**: Low temperature (0.2-0.4) for consistent outputs
- **Manus finding**: When stuck in a failure loop, inject controlled diversity by raising temperature
- **Mechanism**: The agent detects repeated failures and switches to higher-temperature sampling to escape local minima
- **Implementation**: Track retry count. If retries > 3 with same approach, raise temperature to 0.7-0.9 for next attempt.
- **CASCADE connection**: This is one of CASCADE's three parallel debug strategies

---

## CASCADE: Skill Lifecycle and Accumulation

CASCADE (Compositional Agent Skill Acquisition via Dynamic Evolution) demonstrated dramatic performance improvements through systematic skill accumulation.

### Performance Results
- **Without skill accumulation**: 35.4% task success rate
- **With skill accumulation**: 93.3% task success rate
- **Improvement**: +57.9 percentage points — a 2.6x improvement
- **Implication**: Skills aren't a nice-to-have; they're the primary driver of agent capability over time

### Dual-Store Architecture
CASCADE uses two complementary stores for skill retrieval:

**Semantic Store (Vector Search)**
- Stores skill descriptions as embeddings
- Retrieves by semantic similarity to current task
- Fast, approximate matching
- Best for: "find skills similar to what I'm trying to do"

**Graph Store (Dependency Graph)**
- Stores skill relationships (skill A requires skill B)
- Retrieves by graph traversal from anchor skills
- Precise, structured matching
- Best for: "find all skills I need to complete this composite task"

**Hybrid Query**: Retrieve from both stores, re-rank by combined score, load top-K skills into context.

### Progressive Skill Loading (Three Tiers)
CASCADE discovered that loading full skill content for every skill wastes context. Instead:

**Tier 1 — Metadata Only** (always loaded)
```
name: create-react-component
description: Creates a typed React component with tests
tags: [react, typescript, testing]
success_rate: 0.94
```

**Tier 2 — Instructions** (loaded when skill is relevant)
```
## Steps
1. Read existing component patterns in src/components/
2. Create component file with TypeScript interface
3. Add JSDoc comments
4. Create co-located test file
5. Export from index.ts
```

**Tier 3 — Resources** (loaded when skill is actively executing)
```
## Examples
[Full code examples, anti-patterns, edge cases]
```

### Skill Evolution (Three Parallel Debug Strategies)
When a skill fails, CASCADE doesn't just retry — it runs three parallel debug strategies:

1. **Instruction Refinement**: Add a clarifying step to the instructions
2. **Example Augmentation**: Add a concrete example of the failing case
3. **Decomposition**: Break the skill into smaller sub-skills

The strategy that succeeds updates the master skill. This is evolutionary selection applied to agent skills.

### Skill Quality Scoring
Each skill accumulates quality metrics over time:

- `success_rate`: Fraction of successful executions (rolling window)
- `usage_count`: How often the skill is used
- `avg_tokens`: Average tokens consumed
- `last_updated`: When skill was last modified
- `failure_modes`: Known edge cases that cause failures

Skills below a quality threshold (< 0.6 success rate) are flagged for review or deprecation.

---

## SWE-RL: Self-Play for Coding Agents

SWE-RL applies reinforcement learning with self-play to software engineering tasks.

### Result
- **Baseline**: SWE-bench score before self-play training
- **After SWE-RL**: +10.4 percentage points on SWE-bench
- **Method**: Agent fixes bugs, evaluates its own fixes, improves policy based on outcomes

### Self-Play Mechanism
1. Agent attempts to fix a GitHub issue
2. Automated verifier runs tests and checks
3. Reward signal: test pass rate + code quality metrics
4. Policy gradient update applied
5. Agent retries with updated policy

### Relevance to Our System
SWE-RL requires fine-tuning, which we can't do at inference time. However, the benchmark + reward signal design is directly applicable:
- Run the agent on benchmark tasks periodically
- Track score over time (our improvement curve)
- Use failures as learning signal for the ledger
- The benchmark runner agent is our equivalent of the SWE-RL evaluation harness

---

## GVU Pattern: Generator-Verifier-Updater

The GVU pattern is a three-agent loop for reliable code generation:

```
Generator → produces candidate output
    ↓
Verifier → checks correctness against criteria
    ↓
Updater → applies targeted fixes based on verification feedback
    ↑_____________↓ (loop until verified or max retries)
```

### Why It Works
- Separates concerns: generation vs. evaluation vs. repair
- Verifier uses different context than generator (avoids shared failure modes)
- Updater applies surgical fixes rather than regenerating everything
- Loop terminates when verifier passes or max retries reached

### Implementation Notes
- Generator: full creative context, higher temperature acceptable
- Verifier: strict, low temperature, deterministic checking
- Updater: sees both generator output AND verifier feedback, applies minimal changes
- Termination: max 3 loops to prevent infinite regression

### Our Usage
The `/check` command is a partial GVU implementation (generator is `/build`, verifier is `/check`). Adding an Updater that applies the check's feedback automatically would complete the loop.

---

## Hook-Based Learning

Hooks are event triggers that fire at defined lifecycle points. They enable learning by capturing context at critical moments.

### Hook Lifecycle Points
```
pre-task     → before task starts (load relevant skills)
post-tool    → after each tool call (capture success/failure)
pre-commit   → before git commit (validate quality)
post-commit  → after successful commit (record success pattern)
post-error   → when an error occurs (capture error context)
post-session → at session end (summarize learnings)
```

### Learning Capture Strategy
Each hook point should capture:
1. What was attempted
2. What succeeded or failed
3. What context was active (which skills loaded, which files modified)
4. Time taken

This telemetry feeds the benchmark framework and the learning ledger.

### Current Hooks in Our System
- `Stop` hook: validates test coverage before allowing task completion
- `Notification` hook: macOS notifications between pipeline phases
- Pre-commit: runs tests via lint-staged

### Missing Hooks We Should Add
- `post-error`: capture error type, file context, retry count → learning signal
- `post-session`: summarize what was built, what failed, what was learned
- `post-benchmark`: after benchmark run, update improvement curve

---

## Summary: Key Patterns to Implement

| Pattern | Source | Impact | Implementation Priority |
|---------|--------|--------|------------------------|
| KV-cache optimization | Manus | Cost 10x reduction | High |
| Error retention in context | Manus | Fewer repeated failures | Medium |
| todo.md attention anchoring | Manus | Better long-horizon tasks | High |
| Filesystem as memory | Manus | Longer effective context | Already partial |
| Controlled diversity on retry | Manus | Escape failure loops | Medium |
| Dual-store skill retrieval | CASCADE | +57.9% success rate | High |
| Progressive skill loading | CASCADE | Context efficiency | High |
| Skill evolution (3 strategies) | CASCADE | Self-healing skills | Medium |
| GVU pattern | General | Reliable code gen | Medium |
| Hook-based learning capture | General | Continuous improvement | High |
| Self-play benchmarking | SWE-RL | +10.4 points | Low (requires harness) |
