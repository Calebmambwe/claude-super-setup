# Benchmark Framework: Detailed Specification

## Purpose

The benchmark framework is the measurement layer for the self-improvement engine. It answers the question: "Is our agent system getting better over time?" Without this measurement infrastructure, all other self-improvement work is faith-based.

---

## 1. Agent Quality Metrics

### 1.1 Primary Metrics (What We Care About Most)

**Task Success Rate (TSR)**
Definition: Fraction of tasks completing correctly without manual intervention.
Formula: `TSR = successful_tasks / total_tasks`
Target: > 85%
Measurement window: Rolling 30-day

**First-Attempt Success Rate (FASR)**
Definition: Fraction of tasks succeeding on the first attempt (no retry or correction).
Formula: `FASR = tasks_succeeding_first_try / total_tasks`
Target: > 70%
Why it matters: Retries are expensive (tokens + time). FASR is a leading indicator of efficiency.

**Mean Time to Completion (MTTC)**
Definition: Average wall-clock time from task submission to successful completion.
Target: Trending downward (faster with experience)
Tracked by: task category (some are inherently slower)

### 1.2 Secondary Metrics (Efficiency and Cost)

**Token Cost per Task (TCPT)**
Definition: Average tokens (input + output) consumed per task.
Formula: `TCPT = total_tokens / total_tasks`
Target: Trending downward (more efficient context use)
Note: Absolute value is less important than trend.

**Cache Hit Rate (CHR)**
Definition: Fraction of input tokens served from KV-cache.
Formula: `CHR = cached_tokens / total_input_tokens`
Target: > 80%
How to improve: Stable system prompt, consistent tool ordering, progressive skill loading.

**Tool Call Efficiency (TCE)**
Definition: Ratio of tool calls that produce useful output to total tool calls.
Formula: `TCE = productive_tool_calls / total_tool_calls`
Target: > 80%
What counts as "productive": Tool call returns usable data (not empty, not error).

### 1.3 Learning Metrics (Quality of Improvement)

**Correction Rate (CR)**
Definition: Fraction of tasks requiring at least one user correction.
Formula: `CR = corrected_tasks / total_tasks`
Target: < 15% and trending downward
Connection to learning: High CR = the learning ledger isn't being applied effectively.

**Repeated Mistake Rate (RMR)**
Definition: Same type of mistake made more than once in a 7-day window.
Target: < 5% and trending toward 0
Connection to learning: Mistakes should be recorded and avoided.

**Skill Reuse Rate (SRR)**
Definition: Fraction of tasks where an existing skill was loaded and used.
Formula: `SRR = tasks_with_skill_used / total_tasks`
Target: > 60% and trending upward
Why it matters: High SRR means the skill database is valuable. Low SRR means skills aren't being found or aren't useful.

---

## 2. Benchmark Suite

### 2.1 Tier 1: Regression Suite

**Purpose**: Detect when agent changes break existing capabilities.

**Task Sources**:
- Every successful past task that can be deterministically evaluated
- Format: task description + expected output (patch, file content, or test pass/fail)

**Task Format**:
```json
{
  "id": "reg-001",
  "tier": 1,
  "category": "component-creation",
  "description": "Create a TypeScript React Button component with variant prop",
  "expected_output": {
    "type": "file",
    "path": "src/components/Button.tsx",
    "contains": ["ButtonVariant", "variant: ButtonVariant", "export default Button"]
  },
  "success_criteria": {
    "typescript_valid": true,
    "all_contains_present": true
  },
  "max_attempts": 2,
  "time_limit_seconds": 120
}
```

**Execution**:
- Run: Daily at 2 AM UTC (low traffic)
- Environment: Fresh clone of project template
- Pass threshold: 100% (any failure is investigated)

### 2.2 Tier 2: Capability Benchmarks

**Purpose**: Measure absolute capability level vs. established standards.

**Sources**:

*SWE-bench Verified (primary)*
- 500 human-verified GitHub issue tasks
- Sample 50 tasks per run (covers enough variety without excessive runtime)
- Tasks represent real-world bug fixes and feature additions
- Evaluation: does the generated patch make the tests pass?

*LiveCodeBench (secondary)*
- Rolling window of competitive programming problems
- Sample 20 problems per run (easy: 10, medium: 10)
- Anti-contamination: problems are from after training cutoff
- Evaluation: does the code produce correct output on test cases?

**Execution**:
- Run: Weekly on Sundays at 1 AM UTC
- Environment: Sandboxed Docker containers per task
- Output: Score + per-category breakdown + comparison to last run

### 2.3 Tier 3: Long-Horizon Benchmarks

**Purpose**: Measure the SWE-EVO gap — can we handle multi-step evolving tasks?

**Sources**:

*SWE-EVO sequences*
- Multi-step sequences: 5-10 related changes to the same codebase
- Measures: does change N break change N-1?
- The key metric: sequence completion rate (all steps correct)

*Custom Multi-Step Tasks*
- Derived from real past work (projects we've actually built)
- Example: "Add user authentication to this existing Next.js app"
  - Step 1: Install and configure NextAuth
  - Step 2: Add login/register pages
  - Step 3: Protect routes
  - Step 4: Add user profile page
  - Step 5: Add session-based navigation

**Execution**:
- Run: Monthly on the 1st at midnight UTC
- Environment: Docker containers with pre-built base project
- Output: Sequence completion rate, error compounding rate, comparison to previous month

---

## 3. Score History and Tracking

### 3.1 Score History Schema

```typescript
interface BenchmarkRun {
  run_id: string;                    // UUID
  timestamp: string;                 // ISO 8601
  tier: 1 | 2 | 3;
  benchmark: string;                 // "swe-bench-verified" | "livecodebench" | "regression"
  sample_size: number;
  score: number;                     // 0.0 - 1.0
  per_category: Record<string, number>;  // by task category
  agent_config: {
    model: string;                   // e.g., "claude-sonnet-4-6"
    skills_loaded: string[];         // which skills were available
    skill_count: number;
    ledger_entry_count: number;      // how many learnings in ledger
  };
  metadata: {
    run_duration_ms: number;
    tokens_used: number;
    cost_usd: number;
    failures: BenchmarkFailure[];
  };
}

interface BenchmarkFailure {
  task_id: string;
  expected: string;
  actual: string;
  error?: string;
  time_taken_ms: number;
}
```

**Storage**: `~/.claude-super-setup/benchmarks/history.jsonl` (one run per line)

### 3.2 Improvement Curves

The improvement curve is a time-series chart of benchmark scores:
- X-axis: time (run dates)
- Y-axis: score (0.0 - 1.0)
- One line per benchmark type

The curve should trend upward as the self-improvement engine works. If it plateaus or declines, investigation is needed.

**Key chart types**:
1. **Overall capability curve**: Tier 2 score over time
2. **Per-category curves**: Bug fix vs feature addition vs refactoring
3. **Skill impact curve**: Score before vs after major skill additions
4. **Learning velocity**: Rate of new ledger entries over time

---

## 4. Automated Regression Detection

### 4.1 Regression Definition

A regression is detected when:
- Tier 1 (regression suite): Any task fails that previously passed
- Tier 2 (weekly): Score drops > 5 percentage points from previous run
- Tier 3 (monthly): Score drops > 10 percentage points from previous run

### 4.2 Regression Response

**Automated actions**:
1. Send Telegram alert with specific failing task IDs and error details
2. Create a GitHub issue with the regression details (if connected)
3. Mark in benchmark history as "regression run"

**Investigation steps** (manual, triggered by alert):
1. Look at specific failing tasks — what changed recently?
2. Check if recent skill changes degraded anything
3. Check if a recent ledger entry introduced incorrect patterns
4. Rollback candidate: identify the change that introduced regression

### 4.3 Regression Prevention

Before deploying any skill changes:
1. Run Tier 1 suite against current + proposed skill configuration
2. If any Tier 1 tasks fail with new skills: block skill promotion
3. Only promote skills that maintain or improve Tier 1 score

---

## 5. Dashboard Integration

### 5.1 Metrics to Show

The benchmark dashboard (accessible via Telegram `/benchmark-status`) shows:

```
=== Benchmark Dashboard ===
Last Tier 1 run: 2025-03-24 02:00 UTC
  Regression suite: 47/50 passed (94%) ✓

Last Tier 2 run: 2025-03-23 01:00 UTC
  SWE-bench Verified: 0.54 (+0.02 from last week) ↑
  LiveCodeBench: 0.63 (+0.01 from last week) ↑

Last Tier 3 run: 2025-03-01 00:00 UTC
  Long-horizon: 0.31 (no change) →

Skills database: 47 active, 3 deprecated
Learning ledger: 234 entries (this week: +12)

Next runs:
  Tier 1: Tonight at 2:00 AM
  Tier 2: Sunday at 1:00 AM
  Tier 3: April 1 at midnight
```

### 5.2 Alert Conditions

| Condition | Severity | Action |
|-----------|----------|--------|
| Tier 1 regression | Critical | Telegram alert immediately |
| Tier 2 score drops > 5% | High | Telegram alert + GitHub issue |
| Tier 2 score drops 1-5% | Medium | Log to dashboard only |
| Tier 2 score improves > 5% | Info | Telegram success notification |
| No Tier 2 run in 10 days | Medium | Reminder alert |

---

## 6. Benchmark Runner Agent Spec

### Responsibilities
1. Load benchmark tasks from task database
2. Create isolated execution environments (Docker or sandboxed filesystem)
3. Run the agent on each task with appropriate time limits
4. Collect outputs and verify against expected results
5. Aggregate scores by category
6. Store results in benchmark history
7. Generate and send dashboard update

### Input Interface
```typescript
interface BenchmarkRunRequest {
  tier: 1 | 2 | 3;
  benchmark?: string;    // optional: run specific benchmark only
  sample_size?: number;  // optional: override default sample size
  dry_run?: boolean;     // optional: test harness without executing tasks
}
```

### Output Interface
```typescript
interface BenchmarkRunResult {
  run_id: string;
  score: number;
  regressions: string[];  // task IDs that regressed
  improvements: string[]; // task IDs that improved vs last run
  dashboard_message: string;  // formatted for Telegram
}
```

### Isolation Requirements
- Each task runs in a clean directory (no cross-task state)
- File system writes are captured and compared to expected
- Network access is controlled (allowed: Claude API, blocked: arbitrary internet)
- Time limit enforced per task (2 min for Tier 1, 10 min for Tier 2)
- Token limit enforced per task (prevent runaway costs)
