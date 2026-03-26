# Benchmark Systems for Coding Agents: Research Findings

## Overview

Benchmarks are the measurement layer for agent self-improvement. Without measurement, there is no improvement — only activity. This document covers the current benchmark landscape, saturation analysis, and the recommended benchmark stack for tracking agent quality over time.

---

## The Full Benchmark Landscape

### Standard Coding Benchmarks

| Benchmark | Tasks | Focus | Saturation Status | Best Score (2025) |
|-----------|-------|-------|-------------------|-------------------|
| HumanEval | 164 | Python function completion | Saturated (>95%) | ~98% |
| MBPP | 500 | Python programming problems | Saturated (>90%) | ~95% |
| HumanEval+ | 164 | HumanEval + edge cases | Near-saturated | ~91% |
| MBPP+ | 399 | MBPP + stricter tests | Near-saturated | ~88% |
| LiveCodeBench | Rolling | Real competitive problems | Active | ~65% |
| SWE-bench | 2294 | GitHub issue resolution | Active | ~49% |
| SWE-bench Verified | 500 | Human-verified subset | Active | ~55% |
| SWE-EVO | Variable | Long-horizon evolution | Emerging | ~21% |
| BigCodeBench | 1140 | Library API usage | Active | ~72% |
| EvoEval | 828 | Evolved difficulty variants | Active | ~70% |

### Saturation Analysis

**Saturated benchmarks** (avoid as primary metrics):
- HumanEval: All frontier models score >95%. Discriminates nothing. Do not use.
- MBPP: Same situation. Useful only for regression detection in tiny models.

**Active benchmarks** (good for tracking):
- SWE-bench Verified: The current gold standard for real-world code changes. 500 human-verified GitHub issues. Correlates with actual developer utility.
- LiveCodeBench: Rolling window of competitive programming problems. Prevents contamination.

**Emerging benchmarks** (watch carefully):
- SWE-EVO: The most interesting new benchmark — see gap analysis below.

---

## SWE-EVO Gap Analysis: The Long-Horizon Problem

### The Gap

SWE-EVO was designed to measure long-horizon software evolution: making a series of related changes to a codebase over time, mimicking how real development works.

**Isolated task performance**: 65-80% on single, well-scoped tasks
**Long-horizon evolution performance**: 21% on multi-step SWE-EVO sequences

This 44-59 percentage point gap reveals a fundamental problem: agents that perform well on isolated tasks collapse when tasks require:
1. Maintaining consistent design decisions across multiple changes
2. Not breaking previous changes when making new ones
3. Understanding accumulated context from earlier in the sequence
4. Managing technical debt introduced by earlier steps

### Why the Gap Exists

**Context degradation**: As the task sequence grows, early context fades or gets compressed. The agent "forgets" design decisions made in step 1 when working on step 8.

**Error compounding**: Mistakes in early steps create technical debt that compounds. A slightly wrong abstraction in step 2 makes step 5 much harder.

**Coordination failure**: Multi-step tasks require maintaining an implicit "project model" — an understanding of what the codebase is trying to be. Agents don't reliably maintain this.

### Implications for Our System

This gap is the key insight for the benchmark framework:
1. Don't just measure isolated task performance — measure multi-step sequences
2. The todo.md attention anchoring pattern (from Manus) directly addresses context degradation
3. The skill evolution pattern (from CASCADE) helps prevent error compounding
4. Our benchmark framework should include both isolated and sequence tasks

---

## LiveCodeBench: Anti-Contamination Design

LiveCodeBench solves the contamination problem by using a rolling window of problems from competitive programming contests (Codeforces, LeetCode, AtCoder).

**Key properties**:
- Problems are added as they are published (no training contamination)
- Problems are removed after 6 months (keeps difficulty distribution stable)
- Provides easy/medium/hard splits
- Includes execution-based evaluation (not just string matching)

**For our system**: LiveCodeBench tasks are a good source of benchmark problems that won't be "known" by the model. We can use easy/medium problems for regression testing.

---

## Recommended Benchmark Stack

Given the analysis above, here is the recommended three-tier benchmark stack:

### Tier 1: Regression Tests (Run on Every Commit)
**Purpose**: Detect when agent changes break existing capabilities
**Source**: Our own successful past tasks, converted to repeatable tests
**Size**: 20-50 tasks
**Run time**: < 5 minutes
**Threshold**: Must maintain 100% pass rate

### Tier 2: Capability Benchmarks (Run Weekly)
**Purpose**: Track absolute capability level over time
**Source**: SWE-bench Verified (50-task sample), LiveCodeBench (20-task rolling sample)
**Size**: 70-100 tasks
**Run time**: 2-4 hours
**Output**: Improvement curve, per-category scores

### Tier 3: Long-Horizon Benchmarks (Run Monthly)
**Purpose**: Measure the SWE-EVO gap in our specific use cases
**Source**: SWE-EVO sequences, custom multi-step tasks derived from real past work
**Size**: 10-20 sequences
**Run time**: 4-8 hours
**Output**: Sequence completion rate, error compounding rate

---

## Agent Quality Metrics (Beyond Benchmarks)

Benchmarks measure capability in controlled settings. We also need to measure real-world quality:

### Task-Level Metrics
- **Task success rate**: Fraction of tasks completing without manual intervention
- **First-attempt success rate**: Fraction succeeding on the first try (vs. requiring retries)
- **Mean retries to success**: Average number of attempts before success
- **Error rate by category**: Which types of errors occur most frequently

### Efficiency Metrics
- **Time to completion**: Wall clock time from task start to task done
- **Token consumption per task**: Track cost trends over time
- **Cache hit rate**: Fraction of tokens served from cache (should trend toward 1.0)
- **Tool call efficiency**: Ratio of useful tool calls to total tool calls

### Learning Metrics
- **Correction frequency**: How often the user needs to correct the agent
- **Repeated mistake rate**: Same mistake made twice in one session (should trend to 0)
- **Skill reuse rate**: Fraction of tasks where existing skills were used vs. invented from scratch
- **Learning velocity**: Rate at which new learnings are added to the ledger

---

## Benchmark Infrastructure Requirements

### Evaluation Harness
An evaluation harness needs:
1. Task loader (reads benchmark tasks in standard format)
2. Agent runner (executes the task in a sandboxed environment)
3. Verifier (checks the output against expected results)
4. Score aggregator (combines individual scores into summary metrics)
5. History store (persists scores over time for trend analysis)

### Standard Task Format
```json
{
  "id": "task-001",
  "category": "bug-fix",
  "difficulty": "medium",
  "description": "Fix the null pointer exception in UserService.getById()",
  "repo_url": "https://github.com/example/repo",
  "base_commit": "abc123",
  "expected_patch": "...",
  "test_command": "npm test",
  "success_criteria": {
    "tests_pass": true,
    "no_new_failures": true,
    "patch_applies": true
  }
}
```

### Score History Format
```json
{
  "run_id": "run-2025-03-25-001",
  "timestamp": "2025-03-25T10:00:00Z",
  "benchmark": "swe-bench-verified",
  "sample_size": 50,
  "score": 0.54,
  "per_category": {
    "bug-fix": 0.67,
    "feature-addition": 0.41,
    "refactoring": 0.62
  },
  "agent_config": {
    "model": "claude-sonnet-4-6",
    "skills_loaded": ["create-react-component", "write-tests"],
    "skill_count": 12
  }
}
```

---

## Anti-Patterns to Avoid

**Don't use HumanEval as a primary metric**: It's saturated and doesn't correlate with real-world usefulness. Any metric above 95% is noise.

**Don't self-report benchmark scores**: The agent should never evaluate its own benchmark performance. Use a separate verifier (different model or deterministic checks).

**Don't benchmark without isolation**: Each benchmark task must run in a clean environment. Prior task state must not leak into subsequent tasks.

**Don't over-optimize for benchmarks**: The goal is real-world improvement, not benchmark score maximization. If scores improve but the agent feels worse to use, something is wrong.

**Don't run benchmarks too frequently**: Daily benchmark runs create noise and burn tokens. Weekly (Tier 2) and monthly (Tier 3) cadences are appropriate.
