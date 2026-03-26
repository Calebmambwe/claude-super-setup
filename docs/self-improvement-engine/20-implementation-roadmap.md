# Implementation Roadmap

## Overview

Four-week phased implementation plan. Each phase has clear tasks, acceptance criteria, and dependencies. The phases are designed so that each builds on the previous, and early phases deliver immediate value (fixes and improvements) while later phases deliver the more complex self-improvement infrastructure.

---

## Phase 1: Core Engine + Benchmark Framework (Week 1)

**Theme**: Measurement first. Fix what's broken. Establish the feedback baseline.

**Goal**: By end of Week 1, we can measure agent quality and have the improvement loop skeleton in place.

---

### Phase 1 Tasks

#### P1.1: Fix Template Bugs (Day 1, ~2 hours)

**Files**:
- `~/.claude/config/stacks/mobile-expo-revenucat/` — Fix PaywallScreen purchasePackage → purchase
- `~/.claude/config/stacks/mobile-nativewind/` — Remove styled() wrappers, update to NativeWind v4 API

**Steps**:
1. Find the paywall component in mobile-expo-revenucat
2. Update RevenueCat v7 API calls (see `19-existing-template-upgrades.md` §7)
3. Find all `styled()` usages in mobile-nativewind
4. Replace with direct `className` prop usage
5. Test that both templates scaffold without TypeScript errors

**Acceptance criteria**:
- `npx create-expo-app --template mobile-expo-revenucat` → no RevenueCat type errors
- `npx create-expo-app --template mobile-nativewind` → no `styled()` import errors

**Dependencies**: None

---

#### P1.2: Enhance Skill Metadata (Day 1-2, ~4 hours)

**Files**:
- All 30+ SKILL.md files in `~/.claude/skills/`

**Steps**:
1. Run `find ~/.claude/skills -name "SKILL.md"` to list all skills
2. For each skill, add missing header fields: `tags`, `version: 1.0.0`, `status: active`
3. Add `failure_modes: []` section (empty if none known)
4. Add `related_skills: []` section
5. Validate YAML frontmatter is valid in each file

**Script to help**:
```bash
#!/bin/bash
# check-skill-metadata.sh
for skill in ~/.claude/skills/*/SKILL.md; do
  echo "=== $skill ==="
  grep -E "^(name|description|tags|version|status|failure_modes):" "$skill" || echo "MISSING FIELDS"
done
```

**Acceptance criteria**:
- All SKILL.md files have: `name`, `description`, `tags`, `version`, `status`
- No SKILL.md has invalid YAML frontmatter
- `search_learnings` MCP retrieves skills correctly

**Dependencies**: None

---

#### P1.3: Add CI/CD to Top 5 Templates (Day 2-3, ~6 hours)

**Files**:
- `~/.claude/config/stacks/web-app/`
- `~/.claude/config/stacks/saas-starter/`
- `~/.claude/config/stacks/ai-ml-app/`
- `~/.claude/config/stacks/web-t3/`
- `~/.claude/config/stacks/api-service/`

**Steps** (for each template):
1. Copy the standard CI yml from `17-ci-cd-template.md`
2. Adapt for the template's package manager and commands
3. Add `.github/dependabot.yml`
4. Add `.devcontainer/devcontainer.json`
5. Test: scaffold from template, verify CI yml is present and valid

**Acceptance criteria**:
- Each template's scaffolded project has `.github/workflows/ci.yml`
- CI yml syntax is valid (`actionlint` passes)
- Each template has `.devcontainer/devcontainer.json`

**Dependencies**: None

---

#### P1.4: Implement Benchmark Framework Core (Day 3-5, ~8 hours)

**Files to create**:
- `~/.claude-super-setup/agents/benchmark-runner/AGENT.md`
- `~/.claude-super-setup/benchmarks/tasks/regression/` — 10 initial regression tasks
- `~/.claude-super-setup/benchmarks/history.jsonl` — Empty file to start
- `~/.claude-super-setup/scripts/run-benchmark.sh` — CLI entry point

**Steps**:
1. Create `AGENT.md` for benchmark-runner agent
2. Convert 10 recent successful tasks to benchmark format (see `13-benchmark-framework-spec.md`)
3. Implement `run-benchmark.sh` that runs the agent on Tier 1 tasks
4. Implement score calculation and storage to `history.jsonl`
5. First run: establish baseline scores

**Regression task format**:
```json
{
  "id": "reg-001",
  "tier": 1,
  "category": "component-creation",
  "description": "Create a TypeScript interface for a User type with id, email, name, role",
  "expected_output": {
    "type": "code",
    "contains": ["interface User", "id: string", "email: string", "role:"]
  },
  "time_limit_seconds": 60
}
```

**Acceptance criteria**:
- `./run-benchmark.sh --tier 1` completes without errors
- Results appear in `history.jsonl`
- At least 10 Tier 1 tasks defined
- Baseline score recorded

**Dependencies**: P1.2 (skill metadata must be in place for benchmark to work correctly)

---

#### P1.5: Add Post-Session Hook (Day 4-5, ~3 hours)

**Files**:
- Update `~/.claude/CLAUDE.md` to document the post-session behavior
- Create `~/.claude-super-setup/hooks/post-session-summary.md` — prompt for generating session summary

**Steps**:
1. Define the session summary format
2. Add instructions to `CLAUDE.md` for post-session behavior
3. Create a `/reflect` skill if not already present (or enhance existing one)
4. Test: end a session with `/reflect` and verify a learning is recorded

**Session summary format**:
```
## Session Summary [date]
**Built**: [list of components/features created]
**Modified**: [list of files changed]
**Learnings**: [corrections or patterns noted]
**Blockers**: [anything that didn't work]
**Next time**: [things to try differently]
```

**Acceptance criteria**:
- `/reflect` command produces a session summary
- Summary is automatically recorded to learning ledger
- Next session can retrieve the summary via `search_learnings`

**Dependencies**: None

---

### Phase 1 Acceptance Criteria (All)

- [ ] Template bugs fixed (RevenueCat + NativeWind)
- [ ] All 30+ skills have complete metadata headers
- [ ] Top 5 templates have CI/CD pipelines
- [ ] Benchmark framework running (Tier 1, baseline score recorded)
- [ ] Post-session hook in place

---

## Phase 2: New Templates + Template Overhaul (Week 2)

**Theme**: Ship better starting points. Every project scaffolded from now should be production-quality.

**Goal**: By end of Week 2, `web-shadcn-v4` is the primary web template and remaining 11 templates have CI/CD.

---

### Phase 2 Tasks

#### P2.1: Build `web-shadcn-v4` Template (Day 1-3, ~12 hours)

**Files**: New template directory `~/.claude/config/stacks/web-shadcn-v4/`

**Steps** (use template-generator agent or build manually):
1. Scaffold Next.js 15 with App Router and TypeScript strict
2. Install and configure Tailwind v4
3. Initialize shadcn/ui with OKLCH tokens
4. Add `globals.css` with OKLCH `@theme` block
5. Add `eslint-plugin-jsx-a11y` configuration
6. Add `vitest` + `vitest-axe` + `@testing-library/react`
7. Add `SkipNav.tsx` component
8. Add `Playwright` + axe accessibility E2E tests
9. Add `.github/workflows/ci.yml`
10. Add `.devcontainer/`
11. Add `DESIGN.md`
12. Run through full acceptance criteria

**Acceptance criteria**: See `12-new-templates-spec.md` §Template 1

**Dependencies**: P1.3 (CI/CD template established)

---

#### P2.2: Build `mobile-gluestack` Template (Day 2-4, ~10 hours)

**Files**: New template directory `~/.claude/config/stacks/mobile-gluestack/`

**Steps**:
1. Scaffold Expo SDK 54 with TypeScript
2. Install Gluestack UI v3 and NativeWind v4
3. Configure Expo Router v4 (tabs + stack)
4. Set up GluestackProvider in root layout
5. Configure NativeWind in `babel.config.js` and `metro.config.js`
6. Add Gluestack token configuration
7. Add sample screens demonstrating universal components
8. Add Jest + Testing Library tests

**Acceptance criteria**: See `12-new-templates-spec.md` §Template 2

**Dependencies**: None

---

#### P2.3: Build `monorepo` Template (Day 3-4, ~8 hours)

**Files**: New template directory `~/.claude/config/stacks/monorepo/`

**Steps**:
1. Initialize Turborepo with pnpm workspaces
2. Create `apps/web` (copy from web-shadcn-v4 minimal version)
3. Create `apps/api` (copy from api-hono-edge minimal version)
4. Create `packages/ui` (shared React components)
5. Create `packages/shared` (shared types and utilities)
6. Create `packages/config` (shared ESLint + TypeScript configs)
7. Configure `turbo.json` with correct task dependencies
8. Add GitHub Actions matrix build

**Acceptance criteria**: See `12-new-templates-spec.md` §Template 5

**Dependencies**: P2.1 (web-shadcn-v4 as base for apps/web)

---

#### P2.4: Apply CI/CD to Remaining 11 Templates (Day 4-5, ~8 hours)

Add universal upgrades (CI, devcontainer, DESIGN.md) to:
- `web-astro`, `web-sveltekit`, `web-remix`
- `api-fastapi`, `api-hono-edge`
- `mobile-flutter`, `mobile-app`
- `chrome-extension`, `cli-tool`
- `mobile-expo-revenucat` (already fixed in P1.1, now add CI)
- `mobile-nativewind` (already fixed in P1.1, now add CI)

**Acceptance criteria**:
- All 16 templates have `.github/workflows/ci.yml`
- All 16 templates have `.devcontainer/devcontainer.json`
- All 16 templates have `DESIGN.md`

---

### Phase 2 Acceptance Criteria (All)

- [ ] `web-shadcn-v4` template complete and passes all acceptance criteria
- [ ] `mobile-gluestack` template complete
- [ ] `monorepo` template complete
- [ ] All 16 templates have CI/CD, devcontainer, DESIGN.md
- [ ] First benchmark run using new templates shows improved scores vs baseline

---

## Phase 3: Design Token System + Accessibility (Week 3)

**Theme**: Make design and accessibility systematic.

**Goal**: By end of Week 3, all templates use the token system and pass WCAG 2.2 AA.

---

### Phase 3 Tasks

#### P3.1: Implement Design Token Pipeline (Day 1-3, ~12 hours)

**Files**:
- `tokens/tokens.json` (DTCG source — see `15-design-token-system.md`)
- `tokens/style-dictionary.config.js`
- `tokens/outputs/` (generated)

**Steps**:
1. Create `tokens/tokens.json` with full DTCG token file
2. Configure Style Dictionary v4
3. Test CSS output generation
4. Test Tailwind @theme output
5. Create `tokens:build` script in package.json
6. Add contrast ratio verification script
7. Add to CI pipeline
8. Apply to all web templates

**Acceptance criteria**:
- `pnpm tokens:build` generates all outputs without errors
- Contrast ratios all pass WCAG AA
- CSS output uses OKLCH values
- Changes to `tokens.json` automatically propagate via CI

**Dependencies**: P2.1 (web-shadcn-v4 template as primary target)

---

#### P3.2: Apply Accessibility Framework to All Web Templates (Day 2-5, ~10 hours)

**Files** (per template):
- `package.json` — add jsx-a11y
- `.eslintrc.cjs` — add jsx-a11y rules
- `src/components/layout/SkipNav.tsx` — new file
- `src/app/layout.tsx` — add `lang="en"` and `SkipNav`
- `src/test/setup.ts` — add axe-core expectations
- `tests/e2e/accessibility.spec.ts` — new file

**Templates to update**: `web-app`, `web-shadcn-v4`, `web-t3`, `saas-starter`, `ai-ml-app`, `web-astro`, `web-sveltekit`, `web-remix`

**Acceptance criteria**:
- ESLint with jsx-a11y finds zero violations in default project
- Playwright axe audit finds zero violations on all default pages
- SkipNav component present in all web templates

**Dependencies**: P1.3 (CI must exist to run a11y audit)

---

#### P3.3: Build `email-templates` Template (Day 3-4, ~6 hours)

**Files**: New template `~/.claude/config/stacks/email-templates/`

**Acceptance criteria**: See `12-new-templates-spec.md` §Template 6

**Dependencies**: None

---

### Phase 3 Acceptance Criteria (All)

- [ ] Design token pipeline running (DTCG → CSS + Tailwind)
- [ ] All 8 web templates pass WCAG 2.2 AA axe audit
- [ ] eslint-plugin-jsx-a11y in all React templates
- [ ] `email-templates` template complete
- [ ] Benchmark run after Phase 3 shows no regressions

---

## Phase 4: Observability + Continuous Learning Loop (Week 4)

**Theme**: Close the loop. Make improvement automatic.

**Goal**: By end of Week 4, the self-improvement flywheel is spinning: corrections are captured, skills evolve, benchmarks run on schedule, and the dashboard shows the improvement curve.

---

### Phase 4 Tasks

#### P4.1: Implement JSONL Observability (Day 1-2, ~6 hours)

**Files**:
- `~/.claude-super-setup/logs/` — log directory
- `~/.claude-super-setup/lib/logger.ts` — JSONL logger

**Steps**:
1. Create the logger module (see `18-observability-spec.md`)
2. Integrate into task dispatch
3. Ensure every tool call is logged
4. Every task start/complete is logged
5. Every error is logged with full context

**Acceptance criteria**:
- After running a task: `~/.claude-super-setup/logs/agent.jsonl` shows the execution
- Each log line has: timestamp, event, task_id, session_id
- Errors include: tool name, error message, retry count

**Dependencies**: None

---

#### P4.2: Implement Skill Auto-Update After Use (Day 2-3, ~8 hours)

**Files**:
- `~/.claude-super-setup/lib/skill-tracker.ts` — update metrics after each use
- Update SKILL.md parser to read/write metrics fields

**Steps**:
1. Create skill-tracker module
2. On skill success: update `success_rate`, `usage_count`
3. On skill failure: update `failure_count`, trigger evolution check
4. Write updated metrics back to SKILL.md headers
5. Implement `compute_quality_score()` function

**Acceptance criteria**:
- After using a skill successfully: `usage_count` increments in SKILL.md
- After using a skill and failing: `failure_count` increments
- Quality score is recalculated and stored
- Skills below threshold 0.6 are flagged for evolution

**Dependencies**: P1.2 (skill metadata must be in place)

---

#### P4.3: Implement Skill Evolution (Day 3-4, ~10 hours)

**Files**:
- `~/.claude-super-setup/agents/skill-curator/AGENT.md`
- `~/.claude-super-setup/agents/skill-curator/strategies/instruction-refinement.md`
- `~/.claude-super-setup/agents/skill-curator/strategies/example-augmentation.md`
- `~/.claude-super-setup/agents/skill-curator/strategies/decomposition.md`

**Steps**:
1. Create `AGENT.md` for skill-curator agent
2. Implement three evolution strategies (as prompts/procedures)
3. Implement the selection mechanism (run Tier 1 benchmarks on evolved versions)
4. Implement skill promotion workflow
5. Create deprecation logic and `skills/deprecated/` directory
6. Test with a real skill that has low quality score

**Acceptance criteria**:
- `/curate-skills` command runs the curator
- A skill with failure_count > 3 triggers evolution
- The best evolution strategy is selected and promoted
- Deprecated skills are moved to `skills/deprecated/`

**Dependencies**: P4.2 (skill auto-update), P1.4 (benchmark framework for evaluation)

---

#### P4.4: Schedule Automated Benchmark Runs (Day 4-5, ~4 hours)

**Files**:
- `~/.claude-super-setup/cron/benchmark-tier2.sh`
- `~/.claude-super-setup/cron/benchmark-tier1.sh`
- Cron configuration (VPS crontab)

**Steps**:
1. Create `benchmark-tier1.sh` script (daily, < 5 minutes)
2. Create `benchmark-tier2.sh` script (weekly, 2-4 hours)
3. Add to VPS crontab:
   ```cron
   0 2 * * * ~/.claude-super-setup/cron/benchmark-tier1.sh
   0 1 * * 0 ~/.claude-super-setup/cron/benchmark-tier2.sh
   ```
4. Implement Telegram alert on regression
5. First scheduled run: verify it completes and results are stored

**Acceptance criteria**:
- Tier 1 runs daily, takes < 5 minutes
- Tier 2 runs weekly, takes < 4 hours
- Regressions trigger Telegram alert
- Results appear in `history.jsonl`

**Dependencies**: P1.4 (benchmark framework), P4.1 (logging)

---

#### P4.5: Build `saas-complete` and `ai-rag-complete` Templates (Day 3-5, ~14 hours)

These are the most complex templates. Building them in Phase 4 uses all the infrastructure from previous phases.

**Acceptance criteria**: See `12-new-templates-spec.md` §Templates 3 and 4

**Dependencies**: P2.1 (web-shadcn-v4), P3.1 (design tokens), P3.2 (accessibility)

---

### Phase 4 Acceptance Criteria (All)

- [ ] JSONL observability in place, every task and tool call logged
- [ ] Skill auto-update working (metrics update after each use)
- [ ] Skill evolution running (curator agent functional)
- [ ] Scheduled benchmarks running (Tier 1 daily, Tier 2 weekly)
- [ ] `saas-complete` template complete
- [ ] `ai-rag-complete` template complete
- [ ] Improvement curve shows at least 2 data points

---

## Summary Timeline

| Day | Phase | Task | Estimated Hours |
|-----|-------|------|----------------|
| 1 | P1 | Fix template bugs | 2 |
| 1-2 | P1 | Enhance skill metadata | 4 |
| 2-3 | P1 | Add CI/CD to top 5 templates | 6 |
| 3-5 | P1 | Benchmark framework core | 8 |
| 4-5 | P1 | Post-session hook | 3 |
| 6-8 | P2 | web-shadcn-v4 template | 12 |
| 7-9 | P2 | mobile-gluestack template | 10 |
| 8-9 | P2 | monorepo template | 8 |
| 9-10 | P2 | CI/CD remaining 11 templates | 8 |
| 11-13 | P3 | Design token pipeline | 12 |
| 12-15 | P3 | Accessibility all web templates | 10 |
| 13-14 | P3 | email-templates template | 6 |
| 15-16 | P4 | JSONL observability | 6 |
| 16-17 | P4 | Skill auto-update | 8 |
| 17-18 | P4 | Skill evolution | 10 |
| 19 | P4 | Schedule benchmark runs | 4 |
| 19-20 | P4 | saas-complete + ai-rag-complete | 14 |

**Total estimated**: ~131 hours of implementation work over 4 weeks.
