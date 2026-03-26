# Skill Acquisition: Enhanced TeachMe + CASCADE Patterns

## Overview

The current TeachMe skill and SKILL.md format provide a solid foundation. This document specs the enhancement to a CASCADE-inspired dual-store system with progressive loading, skill evolution, quality scoring, and auto-creation from successful task completions.

The goal: skills that compound. A skill used 50 times should be dramatically better than when it was first created.

---

## 1. Enhanced Skill Schema

### 1.1 Current SKILL.md Header (Baseline)
```yaml
---
name: skill-name
description: What this skill does
---
```

### 1.2 Enhanced Header (Target State)
```yaml
---
# Identity
name: create-react-component
description: Creates a typed React component with tests and Storybook story
version: 1.3.2

# Retrieval metadata
tags: [react, typescript, testing, storybook, components]
aliases: [make-component, new-component, build-component]
related_skills:
  - write-unit-tests: "Use after creating component to add tests"
  - add-to-storybook: "Use to add Storybook story for the component"
  - setup-shadcn-ui: "Prerequisite for components using shadcn/ui"

# Quality metrics (auto-updated)
quality_score: 0.87
success_rate: 0.92
usage_count: 47
failure_count: 4
avg_tokens_loaded: 1840
last_used: 2025-03-20
last_updated: 2025-03-18

# Known issues
failure_modes:
  - "Fails when component depends on complex context providers — use integration test instead"
  - "Storybook story generation fails with compound components — manual addition required"
  - "TypeScript strict: always define explicit return type for component function"

# Lifecycle
status: active  # active | deprecated | experimental
evolution_attempts: 2
promoted_from: create-react-component@1.2.1
---
```

### 1.3 Schema Explanation

**Retrieval metadata** enables the semantic store to find this skill when the query uses synonyms or related concepts.

**Quality metrics** are auto-updated after each use:
- `success_rate` = rolling 20-task window (not lifetime, prevents old failures dragging down improved skills)
- `quality_score` = composite: `0.6 * success_rate + 0.2 * (1 - avg_tokens/budget) + 0.2 * (usage_count > 10 ? 1 : usage_count/10)`

**Failure modes** are added when failures occur. They serve as in-skill warnings to prevent known mistakes.

---

## 2. Dual-Store Architecture

### 2.1 Semantic Store (Vector Embeddings)

**Purpose**: Find skills by meaning, not just keywords.

**Content**: Each skill's embedding is computed from its `name + description + tags + aliases`.

**Index**: Approximate nearest neighbor index (HNSW or IVF)

**Query**: Embed the current task description, find top-K similar skill embeddings.

**Implementation Options**:
- Local: `lancedb` (pure TypeScript, no server required)
- Light server: `chromadb` (Docker, HTTP API)
- Production: `pgvector` (if project already has Postgres)

**For our system**: Use `lancedb` for the skills store — it's serverless, stores data in files, and works on the VPS without additional services.

```typescript
// Semantic skill retrieval
async function findSkillsBySemantic(query: string, topK = 5): Promise<Skill[]> {
  const queryEmbedding = await embed(query);
  const results = await skillsTable.search(queryEmbedding).limit(topK).execute();
  return results.map(r => loadSkillMetadata(r.skill_name));
}
```

### 2.2 Graph Store (Skill Relationships)

**Purpose**: Find skills via dependency relationships. If I need skill A, what else do I need?

**Content**: Directed graph where edges represent "requires" or "relates to" relationships.

**Implementation**: Simple JSON adjacency list (no graph database needed at our scale).

```json
// ~/.claude/config/skills-graph.json
{
  "create-react-component": {
    "requires": ["setup-typescript"],
    "related": ["write-unit-tests", "add-to-storybook"],
    "often-used-with": ["setup-shadcn-ui"]
  },
  "deploy-nextjs-vercel": {
    "requires": ["setup-nextjs"],
    "related": ["setup-env-variables", "setup-github-actions"]
  }
}
```

**Query**: Given the skills retrieved by semantic search, traverse the graph to find all transitively required skills.

### 2.3 Hybrid Retrieval

```typescript
async function retrieveSkills(taskDescription: string): Promise<SkillSet> {
  // Step 1: Semantic search (top 10 candidates)
  const semantic = await findSkillsBySemantic(taskDescription, 10);

  // Step 2: Graph expansion (add required skills)
  const graphExpanded = await expandWithDependencies(semantic);

  // Step 3: Rank by relevance + quality score
  const ranked = rankSkills(graphExpanded, taskDescription);

  // Step 4: Apply token budget
  return applyTokenBudget(ranked, TOKEN_BUDGET_FOR_SKILLS);
}

function rankSkills(skills: Skill[], query: string): RankedSkill[] {
  return skills.map(skill => ({
    ...skill,
    rank_score:
      0.5 * skill.semantic_similarity +
      0.3 * skill.quality_score +
      0.2 * skill.recency_score,
  })).sort((a, b) => b.rank_score - a.rank_score);
}
```

---

## 3. Progressive Skill Loading

### 3.1 Three Tiers

**Context budget is precious**. We don't load full skill documents unless we're actively using the skill.

**Tier 1 — Metadata** (~50 tokens per skill)
Always loaded for all skills in the top-20 results. Just enough to confirm relevance.
```markdown
## [Skill: create-react-component] (quality: 0.87)
Creates typed React components with tests.
Tags: react, typescript, testing
```

**Tier 2 — Instructions** (~200-400 tokens per skill)
Loaded for the top-5 most relevant skills. Full procedure.
```markdown
## create-react-component

### Prerequisites
- TypeScript strict mode enabled
- Testing Library installed

### Steps
1. Check src/components/ for similar existing components
2. Create [ComponentName].tsx with typed props interface
3. Create [ComponentName].test.tsx with render + interaction tests
4. Export from src/components/index.ts

### Known Issues
- For compound components, create separate sub-component files
```

**Tier 3 — Resources** (~800-1500 tokens per skill)
Loaded only for the skill currently executing. Full examples and edge cases.
```markdown
## Resources

### Complete Example
```tsx
interface ButtonProps {
  variant: 'primary' | 'secondary';
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
}

export function Button({ variant, children, onClick, disabled }: ButtonProps) {
  return (
    <button
      className={cn('btn', `btn-${variant}`)}
      onClick={onClick}
      disabled={disabled}
      type="button"
    >
      {children}
    </button>
  );
}
```

### Anti-patterns
- Do NOT use `any` for props type — always define explicit interface
- Do NOT forget `disabled` state styling — use `aria-disabled` for non-button elements
```
```

### 3.2 Loading Decision Logic

```typescript
function determineLoadTier(skill: Skill, context: ExecutionContext): LoadTier {
  // Tier 3: actively executing this skill
  if (context.active_skill === skill.name) return 3;

  // Tier 2: in top-5 relevant skills
  if (context.top5_skills.includes(skill.name)) return 2;

  // Tier 1: in top-20 (just show metadata)
  return 1;
}
```

---

## 4. Skill Evolution (CASCADE Three-Strategy Pattern)

### 4.1 When Evolution Triggers

Evolution runs when:
- A skill's rolling `success_rate` drops below 0.7 in the last 5 uses
- A task explicitly uses a skill and fails (post-error hook)
- The `skill-curator` agent runs its daily analysis

### 4.2 Three Parallel Debug Strategies

When a skill fails, three evolution strategies run in parallel:

**Strategy 1: Instruction Refinement**
- Read the failing step in the instructions
- Identify what ambiguity or missing information caused the failure
- Add a clarifying step or caveat
- Test: does the refined instruction avoid the failure?

**Strategy 2: Example Augmentation**
- The failure case becomes a new example with "What NOT to do" annotation
- Or: add a new "Works well when..." / "Fails when..." section
- Test: does the agent avoid the same failure when the example is present?

**Strategy 3: Decomposition**
- If the skill is doing too much, split it into two smaller skills
- Example: "setup-authentication" → "setup-nextauth-config" + "add-auth-routes"
- Test: do the two smaller skills together succeed where the large one failed?

### 4.3 Strategy Selection

After running all three strategies:
1. Run Tier 1 benchmark tasks that exercise this skill
2. Measure which evolved version has higher success rate
3. Promote the winner; discard the others

```typescript
async function evolveSkill(skill: Skill, failureEvent: FailureEvent): Promise<Skill> {
  const [refined, augmented, decomposed] = await Promise.all([
    strategyInstructionRefinement(skill, failureEvent),
    strategyExampleAugmentation(skill, failureEvent),
    strategyDecomposition(skill, failureEvent),
  ]);

  const scores = await Promise.all([
    benchmarkSkill(refined),
    benchmarkSkill(augmented),
    benchmarkSkill(decomposed),
  ]);

  const best = [refined, augmented, decomposed][scores.indexOf(Math.max(...scores))];

  if (Math.max(...scores) > skill.quality_score) {
    return promoteEvolution(skill, best);
  }

  // No improvement — increment evolution_attempts, might deprecate if too many
  return markEvolutionAttempt(skill);
}
```

### 4.4 Deprecation Policy

A skill is deprecated when:
- `success_rate` < 0.4 after 3+ evolution attempts, OR
- `usage_count` < 3 after 60 days (nobody uses it), OR
- Superseded by a better skill that covers the same use case

Deprecated skills are moved to `skills/deprecated/` (not deleted — they contain useful history).

---

## 5. Skill Quality Scoring

### 5.1 Quality Score Formula

```
quality_score =
  0.60 * success_rate (rolling 20-task window)
+ 0.20 * efficiency_score (1 - normalized_token_usage)
+ 0.10 * freshness_score (inverse of days since last update)
+ 0.10 * usage_confidence (1 if usage_count > 20, else usage_count/20)
```

**success_rate**: The most important factor. Computed over the last 20 uses (not lifetime).

**efficiency_score**: Lower token usage is better. Normalized against the 95th percentile token usage across all skills.

**freshness_score**: Recently updated skills get a small boost. Stale skills (not updated in 180 days) get a small penalty.

**usage_confidence**: A skill used only once can't be reliably scored. This factor reduces the quality score for rarely-used skills.

### 5.2 Auto-Update Schedule

Quality metrics are updated:
- After every successful use: `success_rate++, usage_count++`
- After every failed use: `failure_count++, success_rate--` (triggers evolution check)
- Weekly: Recalculate quality_score from stored metrics

---

## 6. Auto-Skill Creation from Successful Tasks

### 6.1 Pattern Detection

After a task completes successfully, the `skill-curator` agent analyzes:
- Was this a novel task pattern (not covered by existing skills)?
- Were 5+ steps required to complete it?
- Is it likely to recur?

If yes to all three: propose auto-creating a new skill.

### 6.2 Auto-Creation Process

```typescript
async function maybeCreateSkill(completedTask: Task): Promise<void> {
  const analysis = await analyzeForSkillCreation(completedTask);

  if (!analysis.should_create) return;

  const draft = await generateSkillDraft({
    task: completedTask,
    steps: completedTask.tool_call_history,
    context: completedTask.context,
  });

  // Validate draft quality
  const quality = await validateSkillDraft(draft);
  if (quality < 0.6) {
    log('Skill draft quality too low, discarding', { draft, quality });
    return;
  }

  // Save to skills/drafts/ for human review
  await saveSkillDraft(draft);
  await notifyViaTelegram(`New skill draft ready for review: ${draft.name}`);
}
```

### 6.3 Draft Review Process

Auto-created skill drafts go to `skills/drafts/` before becoming active. They need:
1. Human review (or `/approve-skill-draft <name>` command)
2. Quality score > 0.6 on first benchmark test
3. Tag classification

This prevents low-quality auto-generated skills from polluting the active skill store.

---

## 7. TeachMe Command Enhancement

### 7.1 Current `/teach-me` Behavior

Current: User walks the agent through a task. Agent creates a SKILL.md file.

### 7.2 Enhanced Behavior

```
/teach-me <task-description>
```

1. **Pre-check**: Search existing skills for coverage. If covered, show existing skill and ask: "This existing skill covers this. Should we update it instead of creating a new one?"

2. **Guided capture**: Walk through task with structured questions:
   - What are the prerequisites?
   - What are the exact steps?
   - What does success look like?
   - What are known failure modes?
   - Are there related skills?

3. **Quality check**: Before saving, validate:
   - Does the description clearly explain the skill?
   - Are there at least 3 steps?
   - Are failure modes documented?

4. **Embed**: Auto-compute and store embedding for semantic retrieval.

5. **Graph update**: Add to skills-graph.json based on related_skills declarations.

6. **Confirmation**: "Skill created: `create-react-component` (quality: new, will score after first use)"
