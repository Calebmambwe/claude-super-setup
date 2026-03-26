# Continuous Learning System

## Overview

The super builder gets better with every project. It tracks what works, what fails, and evolves its strategies over time.

## Learning Sources

### 1. User Corrections
When the user says "no, do X instead" or "that's wrong":
- Record the correction immediately
- Type: correction, confidence: 0.9
- Apply in all future sessions

### 2. Build Failures
When a build fails and is auto-fixed:
- Record error pattern + fix applied
- Type: correction, confidence: 0.85
- Next time → apply fix immediately (skip diagnosis)

### 3. Visual Feedback
When the user reports visual issues:
- Record the issue + fix
- Type: correction, confidence: 0.9
- Apply to design system rules

### 4. Successful Patterns
When output is accepted without changes:
- Record the approach used
- Type: success, confidence: 0.75
- Reinforce the pattern

### 5. Benchmark Results
Regular benchmark runs measure:
- Build success rate
- Test pass rate
- Visual accuracy
- Time to completion
- Error recovery rate

## Learning Storage

### Learning Ledger (MCP)
```
record_learning({
  category: "framer-motion",
  subcategory: "ssr",
  learning: "Always use initial={false} for above-fold content",
  confidence: 0.95,
  project_dir: "/Users/calebmambwe/claude_super_setup",
})
```

### Memory Files
For cross-session persistence:
```
memory/feedback_mobile_first.md
memory/feedback_design_quality.md
memory/feedback_consistency.md
```

### AGENTS.md
Project-specific patterns and gotchas:
```
# Learned Patterns
- Framer Motion: initial={false} for above-fold, whileInView for below-fold
- Dark theme: use concrete slate values, not white/N% opacity
- Clone pipeline: always search for source repo before generating
```

## Skill Evolution

### Automatic Skill Updates
The `/evolve-skills` command:
1. Scans all skills for quality metrics
2. Identifies low-performing skills
3. Runs the skill-curator agent on each
4. Reports evolution results

### Benchmark-Driven Evolution
```
1. Run benchmark suite
2. Identify lowest-scoring areas
3. Research best practices for those areas
4. Update relevant skills/templates
5. Re-run benchmark
6. Compare scores
7. Keep improvements, revert regressions
```

## Metrics Tracked

| Metric | Target | Current |
|--------|--------|---------|
| Build success rate | > 95% | TBD |
| First-pass test rate | > 80% | TBD |
| Visual accuracy (clones) | > 90% | ~70% |
| Error recovery rate | > 85% | TBD |
| Mobile responsiveness | 100% | ~90% |
| Accessibility compliance | 100% | ~80% |
| Dead link rate | 0% | ~5% |
| Time to MVP | < 30 min | ~45 min |

## Consolidation Schedule

Weekly:
- Deduplicate learnings
- Archive stale entries (> 30 days, low confidence)
- Promote high-confidence learnings to skills/templates
- Run improvement report (`scripts/improvement-report.py`)

Monthly:
- Full benchmark suite
- Skill evolution pass
- Template enhancement pass
- Memory cleanup
