---
name: evolve-skills
description: Scan all skills for quality metrics, identify low-performing candidates, run the skill-curator agent on each, and report evolution results.
---

Evolve underperforming skills: $ARGUMENTS

## Process

### Step 1: Parse Arguments

Parse `$ARGUMENTS` for options:
- `--skill <name>` — evolve only a specific skill by name
- `--dry-run` — identify candidates and diagnose failure modes, but do not modify any files
- `--force <name>` — evolve a specific skill regardless of its quality score
- No arguments — scan all skills and evolve candidates automatically

### Step 2: Scan Skills for Quality Metrics

Locate all SKILL.md files across the skill library:

```bash
find ~/.claude/skills -name "SKILL.md" -type f 2>/dev/null
find "$(pwd)/skills" -name "SKILL.md" -type f 2>/dev/null || true
```

For each skill, extract quality metadata from frontmatter:
- `name`
- `quality_score` (float 0.0–1.0, or null if unset)
- `failure_count` (integer, or 0 if unset)
- `version` (integer, or 1 if unset)
- `last_benchmarked` (ISO timestamp, or "never")

Display the full inventory before taking any action:

```
Skill Inventory
===============
Skill                 | Score  | Failures | Version | Status
----------------------|--------|----------|---------|--------
design-system         | 0.87   | 2        | 3       | HEALTHY
backend-architecture  | 0.55   | 8        | 1       | CANDIDATE
reflect               | 0.42   | 12       | 1       | CANDIDATE
meta-rules            | -      | -        | 1       | UNSCORED
```

### Step 3: Identify Candidates

Mark a skill as a **candidate** if:
- `quality_score < 0.6` (explicitly set and below threshold)
- `failure_count >= 5` with no upward trend in recent benchmarks
- `--force <name>` flag was passed, regardless of score

Mark a skill as **SKIP** if:
- `quality_score >= 0.7`
- No benchmark tasks cover this skill (untestable — log as `SKIP: no coverage`)
- It is in `~/.claude/skills/_archived/` (already archived)

If `--skill <name>` was passed, operate only on that skill. Skip the full scan.

### Step 4: Check Benchmark Coverage

Before evolving any candidate, verify benchmark tasks exist for it:

```bash
grep -rl '"category": "<skill-name>"' benchmarks/tasks/ 2>/dev/null | wc -l
```

If zero tasks cover the skill:
- Do NOT evolve it
- Log: `SKIP <skill-name>: no benchmark tasks — fix coverage gap first`
- Continue to next candidate

### Step 5: Run Skill-Curator Agent on Each Candidate

For each confirmed candidate (with benchmark coverage):

```
Invoking skill-curator for: <skill-name>
  Quality score: <score>
  Failure count: <count>
  Last benchmarked: <date>
```

Invoke the skill-curator agent, passing the skill path and diagnosis context.

The agent will:
1. Diagnose the dominant failure mode
2. Select the appropriate evolution strategy (refinement / augmentation / decomposition)
3. Apply the strategy
4. Run Tier 1 benchmarks to validate
5. Promote, hold, or revert based on score delta
6. Append result to `benchmarks/evolution-log.jsonl`

If `--dry-run` is active: run only the diagnosis phase, skip modification and benchmarking.

### Step 6: Aggregate Results

After all candidates have been processed, collect results from `benchmarks/evolution-log.jsonl` (entries with the current run's timestamp).

Display the evolution report:

```
Skill Evolution Summary
=======================
Candidates identified: N
Evolved: N  |  Skipped: N  |  No coverage: N

Results:
Skill                  | Strategy     | Before | After  | Delta | Outcome
-----------------------|--------------|--------|--------|-------|----------
backend-architecture   | refinement   | 0.55   | 0.72   | +0.17 | PROMOTED
reflect                | augmentation | 0.42   | 0.38   | -0.04 | REVERTED
```

### Step 7: Surface Action Items

After the report, list explicit next steps:

- Any skills that were **reverted** (need manual review or different strategy)
- Any skills that were **held** (borderline improvement, needs another benchmark cycle)
- Any skills flagged as **untestable** (benchmark coverage must be added before next run)
- Overall system health: healthy / degraded / critical based on % of skills above 0.7

If `--dry-run` was passed, show the diagnosis and recommended strategies without any file changes.

## Rules

- NEVER evolve a skill with `quality_score >= 0.7` — no exceptions
- ALWAYS display the full inventory before taking action, even on `--skill` targeted runs
- If the skill-curator agent fails for a candidate, log the error and continue to the next — do not abort the full run
- NEVER run this command without an existing `benchmarks/history.jsonl` — check first and instruct the user to run `/benchmark` if missing
- The `--dry-run` flag is safe for CI and can be used to audit skills without risk
