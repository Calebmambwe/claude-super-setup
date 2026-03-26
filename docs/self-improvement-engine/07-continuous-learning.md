# Continuous Learning in Production

## Overview

Continuous learning means the system improves based on production feedback without requiring manual intervention or redeployment. This is the industrialization of the self-improvement loop. This document covers the Netflix/Google/Uber three-layer model and the specific patterns (shadow mode, canary, champion/challenger) applicable to our agent system.

---

## The Three-Layer Model (Netflix/Google/Uber)

The industry consensus from large-scale ML systems converges on a three-layer architecture:

### Layer 1: Monitoring (What's Happening)

**Purpose**: Detect drift, degradation, and anomalies in real time.

**Netflix's approach**: Every recommendation model has real-time dashboards tracking:
- Click-through rates (CTR) per model variant
- Watch completion rates
- Error rates by error type
- Latency percentiles (p50, p95, p99)

**Google's approach**: ML monitoring with automatic alerting on:
- Prediction distribution drift (model outputs are changing character)
- Feature distribution drift (inputs are changing, model may be stale)
- Concept drift (relationship between inputs and correct outputs is changing)

**For our agent system**:
- Task success rate (rolling 7-day window)
- Error rate by error type (API errors, code errors, context errors)
- Token usage per task (cost monitoring)
- User correction rate (proxy for quality degradation)
- Skill retrieval hit rate (are the right skills being found?)

### Layer 2: Experimentation (What Works Better)

**Purpose**: Test changes safely before full rollout.

**Uber's approach**: Every ML model change goes through:
1. Offline evaluation (backtesting on historical data)
2. Shadow mode (run in parallel, compare outputs)
3. A/B test (route X% of traffic to new model)
4. Gradual rollout (0% → 5% → 25% → 50% → 100%)

**For our agent system**:
- Can't A/B test at traditional scale (too few tasks)
- Use champion/challenger: one "champion" configuration vs. one "challenger" per week
- Track which produces better outcomes on the same task types

### Layer 3: Zero-Downtime Deploy (How to Update)

**Purpose**: Update the model/agent without interrupting service.

**Patterns**: Blue-green (see `06-uptime-architecture.md`), canary deploy, rolling update.

---

## Feedback Loops

A feedback loop is a cycle where outputs become inputs. In learning systems, the output (agent behavior) generates signals (success/failure, user corrections) that feed back as inputs (learning data) to improve future outputs.

### Fast Feedback Loop (Seconds to Minutes)

**In-session correction loop**:
1. User sends task
2. Agent produces output
3. User corrects output ("no, do X instead")
4. Correction is recorded to ledger (via `record_learning` hook)
5. In same session, agent applies correction to remaining work

This loop closes in < 1 minute. The agent gets smarter within a session.

**How to implement**:
```python
# Pseudo-code for in-session learning
def handle_user_message(message: str, session: Session):
    if is_correction(message):
        # Extract the correction
        correction = extract_correction(message)
        # Add to in-session memory
        session.learnings.append(correction)
        # Update current task context
        session.active_task.constraints.append(correction)

    # Generate response with session learnings in context
    return generate_response(
        message,
        system_context=format_learnings(session.learnings)
    )
```

### Medium Feedback Loop (Hours to Days)

**Cross-session learning**:
1. Session ends
2. `post-session` hook summarizes what was built, what failed, what was corrected
3. Summary is recorded to the learning ledger (persistent store)
4. Next session starts by loading relevant past learnings
5. Agent behavior is informed by accumulated experience

This loop closes in < 24 hours. The agent gets smarter across sessions.

**Current implementation**: The `mcp__learning__record_learning` and `mcp__learning__search_learnings` tools implement this. The gap is the `post-session` hook to automatically trigger the summary.

### Slow Feedback Loop (Weeks to Months)

**Benchmark-driven improvement**:
1. Weekly benchmark run measures absolute capability
2. Results stored in benchmark history
3. Improvement curves visualized (are we getting better?)
4. Low scores in specific categories trigger targeted skill creation
5. New skills deployed, benchmark re-run to validate improvement

This loop closes in 1-2 weeks. The agent gets smarter at the category level.

---

## Shadow Mode

### The Concept

Shadow mode runs a new version of a system in parallel with the current version, but doesn't use the new version's outputs. Instead, it captures them for comparison.

```
Request → [Current Version] → Response (served to user)
       → [Shadow Version]  → Response (captured, not served)

Then: compare current_response vs shadow_response
```

**Use case**: Test a new agent configuration on real tasks without risk.

### For Our Agent System

```python
class ShadowModeAgent:
    def __init__(self, champion: Agent, challenger: Agent):
        self.champion = champion  # Current production agent
        self.challenger = challenger  # New version being tested

    async def execute(self, task: Task) -> TaskResult:
        # Run champion (returns result to user)
        champion_result = await self.champion.execute(task)

        # Run challenger in background (result is captured, not used)
        asyncio.create_task(
            self._shadow_execute(task, champion_result)
        )

        return champion_result

    async def _shadow_execute(self, task: Task, champion_result: TaskResult):
        try:
            challenger_result = await self.challenger.execute(task)
            # Store comparison for later analysis
            await store_comparison(task, champion_result, challenger_result)
        except Exception as e:
            # Shadow failures don't affect the user
            logger.warning(f"Shadow execution failed: {e}")
```

**Analysis**: After running shadow mode for N tasks, compare:
- Success rates: champion vs challenger
- Token usage: champion vs challenger
- Output similarity: are they producing equivalent code?

---

## Canary Deployment

### The Pattern

Canary deployment routes a small percentage of traffic to the new version. Named after "canary in a coal mine" — the canary detects problems before they affect everyone.

```
100% requests → Current version
↓ (deploy canary)
95% requests → Current version
 5% requests → Canary version
↓ (canary looks good)
75% requests → Current version
25% requests → Canary version
↓ (continue monitoring)
100% requests → Canary version (becomes new current)
```

### Automated Canary Analysis

The key to safe canary deployment is automated analysis:

```yaml
# Spinnaker/Argo Rollouts canary config
canary:
  steps:
    - setWeight: 5
    - pause: { duration: 30m }
    - analysis:
        templates: [canary-analysis]
        args:
          - name: success-rate-threshold
            value: "0.95"
    - setWeight: 25
    - pause: { duration: 1h }
    - setWeight: 100
  analysis:
    successRate:
      provider: prometheus
      query: |
        sum(rate(http_requests_total{status=~"2.."}[5m])) /
        sum(rate(http_requests_total[5m]))
```

**Automated rollback**: If success rate drops below threshold during canary, the deployment automatically rolls back.

### For Our Agent System

Since our agent isn't a web service handling millions of requests, canary deployment applies differently:
- Deploy new skills to a "canary skills" store
- Route 10% of matching tasks to use canary skills
- Compare outcomes (success rate, token usage) between canary and production skills
- If canary is better: promote to production. If worse: discard.

---

## Champion/Challenger Testing

### The Pattern

Champion/challenger maintains a current best configuration (champion) and tests alternative configurations (challengers) against it on real workloads.

Unlike A/B testing (which assumes equal configurations), champion/challenger explicitly tracks which configuration is "better" and promotes the winner.

```
Champion: current best configuration
Challenger: proposed improvement

For N tasks:
  Route ~90% to champion
  Route ~10% to challenger

After N tasks:
  If challenger.success_rate > champion.success_rate + threshold:
    challenger becomes new champion
  Else:
    challenger is discarded
```

### Metrics for Agent Champion/Challenger

**Primary metric**: Task success rate (did the task complete correctly without user intervention?)

**Secondary metrics**:
- Token efficiency (tokens used per successful task)
- Time to completion (wall clock)
- User correction rate (how often was correction needed?)

### Configuration Dimensions to Test

For our agent system, champion/challenger is useful for testing:

1. **System prompt variations**: Does a different framing of the agent's role improve outcomes?
2. **Skill loading strategies**: Load top-3 vs. top-5 skills? Semantic vs. hybrid retrieval?
3. **Temperature settings**: 0.3 vs. 0.5 for code generation tasks?
4. **Tool ordering**: Does presenting tools in a different order affect which are used?
5. **Context window management**: Aggressive vs. conservative context truncation?

---

## Continuous Improvement Loop Design

### The Full Loop

```
Production Tasks
    ↓
Execution Monitoring (Layer 1)
    ↓
Feedback Capture (corrections, successes, failures)
    ↓
Learning Ledger Update (via record_learning)
    ↓
Skill Analysis (which skills are underperforming?)
    ↓
Skill Evolution (CASCADE three-strategy update)
    ↓
Champion/Challenger Test (new skills vs old)
    ↓
Weekly Benchmark Run (absolute capability measurement)
    ↓
Performance Dashboard Update
    ↓ (if regression detected)
Alert + Investigation
    ↓ (if improvement confirmed)
Promote to Production
    ↓
Back to Production Tasks
```

### Loop Cadences

| Loop | Trigger | Duration | Action |
|------|---------|----------|--------|
| In-session | User correction | Immediate | Update session context |
| Post-session | Session end hook | < 5 minutes | Record to learning ledger |
| Daily | Cron job | 1 hour | Analyze patterns, generate skill improvement candidates |
| Weekly | Cron job | 2-4 hours | Run Tier 2 benchmarks, update improvement curves |
| Monthly | Cron job | 4-8 hours | Run Tier 3 long-horizon benchmarks, major skill review |

### Dashboard Requirements

The continuous improvement loop requires a dashboard showing:
- Task success rate (rolling 7-day trend)
- Token cost per task (trend)
- Skills database size (should grow)
- Average skill success rate (should improve)
- Learning ledger size (should grow)
- Benchmark scores (weekly points on improvement curve)
- Active champion/challenger experiments

This dashboard is the primary tool for understanding whether the self-improvement engine is working.
