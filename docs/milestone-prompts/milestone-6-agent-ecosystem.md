# Milestone 6: Agent Ecosystem Integration

## Section 1: Task Summary

**What:** Import 20+ high-value agents from external ecosystems, build a unified agent catalog, configure 4-tier model routing, and define preset team compositions.

**In scope:**
- Import/adapt 8-10 language specialist agents (Go, Rust, Java, Swift, Kotlin, Ruby, PHP, Elixir)
- Import/adapt 3-5 data/AI agents (ML pipeline, data engineer, prompt engineer)
- Import/adapt 3-5 infrastructure agents (Kubernetes, Terraform, AWS, GCP)
- Import/adapt 3-4 mobile specialist agents (accessibility, performance, security)
- Create `agents/catalog.json` with full agent registry
- Configure 4-tier model routing (haiku → sonnet → opus → custom)
- Define 7 preset team compositions
- Update CLAUDE.md with model routing and team documentation

**Out of scope:**
- Auto model routing (runtime dynamic selection — deferred to v2)
- Agent marketplace install command (deferred)
- Agent health checks / canary tests (deferred)
- Party Mode (deferred)

**Definition of done:**
- [ ] 20+ new agent files in `agents/community/`
- [ ] Each adapted agent has required front-matter: name, description, department, model_tier, capabilities
- [ ] `agents/catalog.json` registers ALL agents (core + community) with schema validation
- [ ] Every agent assigned to a model tier (haiku, sonnet, opus, or custom)
- [ ] 7 preset teams defined in catalog.json
- [ ] Original repos credited in agent file headers
- [ ] CI passes with updated inventory counts

## Section 2: Project Background

**Source ecosystems to import from:**
- **VoltAgent/awesome-claude-code-subagents** — 127+ agents, focus on language specialists
- **wshobson/agents** — 112 agents, focus on domain specialists and team presets
- **senaiverse/claude-code-reactnative-expo-agent-system** — 7 mobile agents
- **affaan-m/everything-claude-code** — per-language code reviewers

**Import philosophy:** We don't copy agents verbatim. We adapt them to our system:
1. Standardize front-matter to match our schema
2. Normalize tool lists to our naming conventions
3. Assign model tier based on task complexity
4. Place in appropriate department/subdirectory
5. Add to catalog.json with source attribution

**Model tier assignment guidelines:**
- **haiku:** Simple, fast tasks — formatting, simple lookups, status checks, boilerplate generation
- **sonnet:** Standard development — implementation, testing, code review, most language specialists
- **opus:** Critical thinking — architecture, security review, planning, complex debugging, orchestration
- **custom:** Tasks requiring specific model capabilities or fine-tuned models

## Section 3: Current Task Context

M1 and M2 complete. Parallel with M3, M4, M5, M7.

## Section 4: Design Document Reference

See `docs/design/design-document.md`:
- Section 3.2: Agent catalog schema (catalog.json structure)
- Section 4.4: Agent import process (6-step adaptation flow)
- Section 5.2: Agent department taxonomy

## Section 5: Pre-Implementation Exploration

Before implementing:
1. Read `docs/design/design-document.md` Section 3.2 and 4.4
2. Read 3-5 existing core agent files to understand our format
3. Fetch and read agent definitions from VoltAgent repo (language specialists section)
4. Fetch and read agent definitions from wshobson repo (infrastructure and data/AI sections)
5. Fetch and read agent definitions from senaiverse repo (all 7 mobile agents)
6. Map external tool names to our tool names (e.g., some use `FileRead` instead of `Read`)

## Section 6: Implementation Instructions

### Architecture constraints
- Community agents go in `agents/community/{category}/` subdirectories
- Every agent must have attribution: `<!-- Source: {repo-url} | Adapted: {date} -->`
- Model tier must be justified — don't default everything to opus
- Tool lists must use our standard names: Read, Write, Edit, Bash, Grep, Glob, Agent, WebSearch, WebFetch
- Agent names must be kebab-case and unique across core + community

### Agent import targets

**Language Specialists (agents/community/language-specialists/):**
| Agent | Source | Model Tier | Key Capabilities |
|-------|--------|-----------|------------------|
| go-specialist | VoltAgent | sonnet | Go idioms, goroutines, error handling, testing |
| rust-specialist | VoltAgent | sonnet | Ownership, lifetimes, cargo, unsafe code review |
| java-specialist | VoltAgent | sonnet | Spring Boot, Maven/Gradle, JUnit, design patterns |
| swift-specialist | VoltAgent | sonnet | SwiftUI, UIKit, Xcode, iOS patterns |
| kotlin-specialist | VoltAgent | sonnet | Android, Jetpack Compose, coroutines |
| ruby-specialist | VoltAgent | sonnet | Rails, RSpec, gems, metaprogramming |
| php-specialist | VoltAgent | sonnet | Laravel, Composer, PHPUnit, modern PHP 8+ |
| elixir-specialist | VoltAgent | sonnet | Phoenix, OTP, LiveView, Ecto |

**Data/AI Agents (agents/community/data-ai/):**
| Agent | Source | Model Tier | Key Capabilities |
|-------|--------|-----------|------------------|
| ml-pipeline-builder | VoltAgent/wshobson | opus | ML pipelines, feature engineering, model training |
| data-engineer | VoltAgent | sonnet | ETL, data modeling, SQL optimization, dbt |
| prompt-engineer | wshobson | opus | Prompt design, few-shot examples, evaluation |

**Infrastructure Agents (agents/community/infrastructure/):**
| Agent | Source | Model Tier | Key Capabilities |
|-------|--------|-----------|------------------|
| kubernetes-specialist | wshobson | sonnet | K8s manifests, Helm, troubleshooting |
| terraform-specialist | wshobson | sonnet | IaC, modules, state management, providers |
| aws-architect | wshobson | opus | AWS services, CDK, cost optimization |
| gcp-specialist | wshobson | sonnet | GCP services, Cloud Run, Firestore |

**Mobile Specialists (agents/community/mobile/):**
| Agent | Source | Model Tier | Key Capabilities |
|-------|--------|-----------|------------------|
| rn-accessibility | senaiverse | sonnet | WCAG 2.2, VoiceOver, TalkBack |
| rn-performance | senaiverse | sonnet | FPS optimization, memory, render cycles |
| rn-security | senaiverse | sonnet | OWASP mobile, secure storage, cert pinning |

### Ordered build list

**Step 1: Create directory structure**
```
agents/community/
├── language-specialists/
├── data-ai/
├── infrastructure/
└── mobile/
```

**Step 2: Import and adapt agents**
For each agent:
1. Fetch the original definition from the source repo
2. Create new .md file with standardized front-matter
3. Adapt the prompt to our conventions
4. Normalize tool names
5. Add attribution header
6. Assign model tier

**Step 3: Create catalog.json**
Register ALL agents (core + community) following the schema in design doc Section 3.2. Include:
- All 40+ core agents
- All 20+ newly imported community agents
- Model tier assignments for every agent
- Capability tags for every agent
- 7 preset team definitions

**Step 4: Update inventory counts**
Update `scripts/inventory-check.sh` to reflect new expected agent counts (≥60 total).

**Step 5: Verify CI**
Run validation to ensure all new agents have valid front-matter and catalog.json validates against schema.

### Git workflow
- Branch: `feature/agent-ecosystem`
- Commits: `feat: import language specialist agents from VoltAgent`, `feat: create agent catalog with model routing and preset teams`, etc.

## Section 7: Final Reminders

- Do NOT import agents that duplicate existing core agents
- Every imported agent must have clear attribution to the source repo
- Model tier assignments must be justified — use sonnet as default, opus only for complex reasoning tasks
- Catalog.json must include EVERY agent (core and community) — it's the single source of truth
- Team compositions must be practical — don't just group agents randomly
- Update the CI inventory check script to expect the new agent count
- Run the full CI pipeline before merging
