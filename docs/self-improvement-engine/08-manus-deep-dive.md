# Manus Deep Dive

## Overview

Manus is a fully autonomous multi-agent system from the Manus team. Their context engineering blog post (2025) and Skills system represent some of the most practically useful published work on production agent architecture. This document captures everything relevant to our system.

---

## Context Engineering Blog: Key Insights

### The Central Claim

Manus's core thesis: "Context engineering is the real skill in agent development, not model selection or prompt wording."

The best model with poorly structured context will underperform a good model with well-structured context. This is counter-intuitive to many developers who focus on model selection.

### What Constitutes Context Engineering

Context engineering is the discipline of deciding:
1. **What information** to include in the context window
2. **Where** to place it (position matters for attention)
3. **When** to update it (not every message needs to update context)
4. **What format** to use (JSON vs prose vs code affects comprehension)
5. **What to exclude** (irrelevant context is worse than no context)

### The Context Budget

Context windows have token limits. Manus treats tokens as a budget:

```
Total budget: 200K tokens

Allocation:
- System prompt: ~5K tokens (stable, always present)
- Tool definitions: ~10K tokens (stable, always present)
- Skills: ~20K tokens (semi-stable, loaded by relevance)
- Task context: ~15K tokens (dynamic, changes per task)
- Working history: ~50K tokens (dynamic, grows during task)
- Available budget: ~100K tokens (for tool outputs, research, etc.)
```

The discipline is: never let any category overflow its budget. When working history grows too large, summarize the oldest entries. When tool outputs are verbose, extract only the relevant parts.

### KV-Cache Architecture

The most actionable insight from Manus:

**How KV-cache works**: When the LLM processes a context, it computes key-value pairs for each token. These K-V pairs can be cached. If the same prefix appears at the start of the next request, the cached K-V pairs are reused — you only pay compute for the new tokens at the end.

**The key insight**: Structure your context so that static content is always at the beginning.

```
[System prompt]       ← Always identical, always cached
[Tool definitions]    ← Always identical, always cached
[Loaded skills]       ← Semi-stable, usually cached
[Task description]    ← Changes per task, new tokens
[Working history]     ← Grows throughout task, new tokens
[New user message]    ← Always new tokens
```

**Why this matters at scale**:
- Cache hit: $0.30/MTok (Claude's cache read price)
- Cache miss: $3.00/MTok (Claude's input price)
- At 10M tokens/day: cache saves $27,000/day
- At our scale: saves meaningful costs as usage grows

**Implementation rules**:
1. System prompt NEVER changes between requests in a session
2. Tool definitions are loaded once and never reordered
3. Skills are loaded by tier (metadata → instructions → resources) and maintain position
4. User messages and tool results are always appended to the end

---

## Manus Skills System

### Overview

Manus's Skills system is a library of reusable agent behaviors that can be composed to handle complex tasks. Each Skill is a structured document that teaches the agent how to do something reliably.

**Key difference from few-shot prompting**: Skills are retrieved by relevance, not included wholesale. Only the skills relevant to the current task are loaded.

### Progressive Disclosure Architecture

Manus's Skills implement progressive disclosure — you see only what you need at each level.

**Level 1: Skill Card** (always loaded — minimal tokens)
```markdown
---
name: deploy-nextjs-vercel
description: Deploys a Next.js application to Vercel
tags: [nextjs, vercel, deployment, ci-cd]
success_rate: 0.92
avg_tokens: 4200
---
```

**Level 2: Skill Instructions** (loaded when task matches)
```markdown
## Prerequisites
- Vercel CLI installed (`npm i -g vercel`)
- Environment variables configured in Vercel dashboard
- `vercel.json` present in project root

## Steps
1. Run `vercel --prod` from project root
2. Confirm project link if prompted
3. Wait for deployment to complete
4. Verify deployment URL is accessible
```

**Level 3: Skill Resources** (loaded when executing skill)
```markdown
## Common Errors and Fixes

**Error: `vercel.json` not found**
Create `vercel.json` with:
```json
{
  "buildCommand": "pnpm build",
  "installCommand": "pnpm install"
}
```

**Error: Environment variable not set**
- Go to Vercel dashboard → Project Settings → Environment Variables
- Add all variables from `.env.example`
```

This three-level structure means a single context window can hold metadata for 100 skills, full instructions for the 5 most relevant skills, and resources for the 1 currently executing skill — all within reasonable token budget.

### Skill vs MCP: Complementary Technologies

A common confusion: are Skills replacing MCP tools? No — they're complementary.

**Skills** answer: "How do I do this task?" (procedural knowledge)
- Example: "How do I set up authentication in a Next.js app?"
- Content: Steps, patterns, pitfalls, code examples
- Stored as: Markdown documents in the skills store

**MCP tools** answer: "How do I interact with this external system?" (capability)
- Example: "How do I call the GitHub API?"
- Content: Tool definitions, authentication, API endpoints
- Stored as: MCP server processes

**Together**: An agent uses a Skill to know the *approach* and MCP tools to *execute* the approach.

Example task: "Add a new GitHub Actions workflow for CI"
- Skill loaded: `setup-github-actions-ci` (teaches what steps to take, what yaml to write)
- MCP tools used: `mcp__github__create_or_update_file` (executes the file creation)

### SKILL.md Format Compatibility

Our current SKILL.md format is highly compatible with Manus's approach. The main additions needed:

**Add to current SKILL.md header**:
```yaml
---
# Current fields (already present)
name: skill-name
description: What this skill does

# New fields to add
tags: [tag1, tag2, tag3]      # For retrieval
success_rate: 0.0             # Updated automatically
usage_count: 0                # Updated automatically
avg_tokens_loaded: 0          # Updated automatically
last_updated: 2025-01-01      # Updated on modification
failure_modes:                # Known edge cases
  - "Description of failure mode 1"
  - "Description of failure mode 2"
---
```

**Add resource section** (Level 3):
```markdown
## Resources

### Examples
[Full working examples]

### Anti-patterns
[What NOT to do and why]

### Related Skills
- skill-name-1: Use when X
- skill-name-2: Use when Y
```

---

## Manus Wide Research: Multi-Agent Pattern

### Overview

"Wide Research" is Manus's term for a multi-agent research pattern where multiple parallel agents investigate different aspects of a problem simultaneously.

### Architecture

```
Orchestrator Agent
├── Research Agent 1: Technical feasibility
├── Research Agent 2: Competitive landscape
├── Research Agent 3: Implementation options
└── Research Agent 4: Security considerations
         ↓ (all complete)
Synthesis Agent: Combines findings into unified brief
```

### Key Properties

1. **Parallel execution**: All research agents run concurrently, not sequentially
2. **Specialized context**: Each agent loads only the skills relevant to its research domain
3. **Independent verification**: If agents reach contradictory conclusions, the orchestrator flags the conflict
4. **Structured output**: Each research agent returns a structured JSON report, not free text

### Implementation

```typescript
interface ResearchTask {
  id: string;
  domain: string;
  question: string;
  context: string;
}

async function wideResearch(topic: string): Promise<ResearchSynthesis> {
  const tasks: ResearchTask[] = [
    { id: 'tech', domain: 'technical', question: `Best technical approach for: ${topic}` },
    { id: 'libs', domain: 'libraries', question: `Available libraries for: ${topic}` },
    { id: 'sec', domain: 'security', question: `Security considerations for: ${topic}` },
  ];

  // Run all research agents in parallel
  const results = await Promise.all(
    tasks.map(task => runResearchAgent(task))
  );

  // Synthesize findings
  return await runSynthesisAgent(topic, results);
}
```

### Relevance to Our System

Our `/bmad:research` command and the `researcher` agent are the closest equivalents. The Wide Research pattern would enhance them by:
1. Running multiple research sub-agents in parallel (technical, competitive, library)
2. Using Context7 MCP for each sub-agent (current research agent already does this)
3. Synthesizing findings into a structured Research Brief

This is a natural evolution of the researcher agent.

---

## Manus API Access and Ecosystem

### Public API

Manus has a public API (as of 2025) that exposes:
- Task creation and execution
- Agent session management
- Tool permission controls
- Output retrieval

**Key consideration**: Manus's API is positioned as an alternative to building your own agent infrastructure. For our purposes, we're building the infrastructure, so the API is more of a competitive reference than a tool to use.

### Integration Points

Places where Manus could be used as a capability (rather than replaced):
- **Complex research tasks**: When a task requires web browsing + document analysis + code execution, Manus's fully autonomous mode may outperform our current setup
- **Benchmark validation**: Run the same task on our system and Manus, compare outputs
- **Capability gap identification**: Tasks that Manus handles well but our system doesn't are skill creation opportunities

---

## Applying Manus Patterns: Implementation Checklist

### Immediate (Week 1)
- [ ] Restructure system prompt to ensure stable prefix for KV-cache
- [ ] Add tags, success_rate, usage_count to all SKILL.md headers
- [ ] Create Level 3 resource sections for top-10 most-used skills
- [ ] Implement todo.md pattern in the task dispatch system
- [ ] Add post-error hook to capture error context before discarding

### Short-term (Week 2-3)
- [ ] Implement dual-store skill retrieval (semantic + graph)
- [ ] Add progressive loading (load metadata first, instructions on match, resources on execute)
- [ ] Build skill quality scoring system (auto-update success_rate after each use)
- [ ] Implement controlled diversity retry (raise temperature after 3 failures)

### Medium-term (Month 2)
- [ ] Build skill evolution system (three parallel debug strategies)
- [ ] Implement Wide Research pattern for complex research tasks
- [ ] Add skill dependency graph (skill A requires skill B)
- [ ] Build skill performance dashboard
