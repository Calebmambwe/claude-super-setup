# claude-super-setup: Comprehensive Development Plan

**Version:** 1.0
**Status:** Ready for implementation
**Last Updated:** 2026-03-21

---

## Project Context

This project transforms a rich but non-portable Claude Code configuration (`~/.claude/` with 70+ commands, 40+ agents, 12 hooks, 16 rules, 3 stack templates, Ghost Mode, BMAD, Ralph Loop, self-learning system) into an installable, version-controlled, self-improving git repository. The result is a first-in-market portable AI development configuration with autonomous CI/CD, 16 stack templates, 60+ agents with model routing, and weekly self-improvement proposals.

---

## Document Index

| Document | Path | Status | Purpose |
|----------|------|--------|---------|
| Research Brief | `docs/research/research-brief.md` | Complete | Competitive analysis of 10 setups |
| Brainstorm | `docs/brainstorm/brainstorm.md` | Complete | SCAMPER ideation, top 25 ideas |
| Design Document | `docs/design/design-document.md` | Complete | Architectural blueprint |
| Milestone Prompts | `docs/milestone-prompts/` | Complete | 8 self-contained implementation guides |
| **Development Plan** | `docs/development-plan.md` | **Active** | Master orchestration (this document) |

---

## Architecture Decisions Log

| # | Decision | Chosen | Rejected | Rationale |
|---|----------|--------|----------|-----------|
| 1 | Install mode | Symlink (default) | Copy-only, GNU Stow | Symlinks enable `git pull` = instant update. No extra dependency like Stow. Copy available as fallback. |
| 2 | Template format | YAML with embedded files | Separate file trees, JSON | Single file is easier to version, validate, and diff. Existing 3 templates prove the pattern. |
| 3 | CI validation | shellcheck + ajv + markdownlint + actionlint | Custom validator | Proven tools with no maintenance burden. Catches real issues. |
| 4 | Versioning | release-please + conventional commits | Manual changelog, CalVer | Fully automated. Conventional commits already enforced by git rules. |
| 5 | Personal config | settings.local.json overlay | Separate branch, .env files | Claude Code natively supports settings.local.json overlay. No custom logic needed. |
| 6 | Agent organization | core/ + community/ with catalog.json | Flat directory, tags-only | Subdirectories for source clarity. catalog.json for programmatic discovery. |
| 7 | Model routing | Static 4-tier (haiku/sonnet/opus/custom) | Runtime auto-routing | Static is simple, predictable, and sufficient. Auto-routing deferred to v2. |
| 8 | Autonomous CI | Weekly improvement PRs (never auto-merged) | Daily runs, auto-merge | Weekly is enough. Human review mandatory — config changes are high-impact. |
| 9 | Template expansion | 13 new (web, mobile, specialized, backend) | Web-only, or all categories later | User chose all categories. Breadth of templates is our strongest differentiator. |
| 10 | Agent imports | Adapt and attribute, don't copy verbatim | Wholesale import, fork repos | Adaptation ensures consistency. Attribution respects open source. |
| 11 | New /new-app menu | Extend existing command | New command | Fewer commands to learn. `/new-app` already has the routing logic. |
| 12 | Ghost Mode scripts | Shared (scripts are generic) | Personal (too specific) | ghost-watchdog.sh reads ghost-config.json for project-specific state. Script is reusable. |

---

## Execution Roadmap

### Phase 0: Documentation (COMPLETE)
- [x] Research Brief
- [x] Brainstorm Document
- [x] Design Document
- [x] Milestone Prompts (8 files + README)
- [x] Development Plan (this document)

### Phase 1: Foundation (Sequential — M1 then M2)

| Milestone | Description | Est. Sessions | Dependencies |
|-----------|-------------|---------------|--------------|
| **M1** | Repo Scaffold & CI Pipeline | 1-2 | None |
| **M2** | Install Script | 1 | M1 |

**M1 deliverables:** Git repo with all config migrated, CI passing (6 validation jobs), release-please configured, .gitignore for personal files.

**M2 deliverables:** install.sh (symlink/copy, --dry-run, backup), uninstall.sh, health check, user override templates.

### Phase 2: Templates & Agents (Parallel — M3, M4, M5, M6, M7)

| Milestone | Description | Est. Sessions | Dependencies | Can Parallel With |
|-----------|-------------|---------------|--------------|-------------------|
| **M3** | Web Templates (4) | 2 | M2 | M4, M5, M6, M7 |
| **M4** | Mobile Templates (3) | 1-2 | M2 | M3, M5, M6, M7 |
| **M5** | Specialized + Backend (6) | 2 | M2 | M3, M4, M6, M7 |
| **M6** | Agent Ecosystem (20+ agents) | 2 | M2 | M3, M4, M5, M7 |
| **M7** | Autonomous CI/CD | 1 | M2 | M3, M4, M5, M6 |

**Parallel execution strategy:** Use `/parallel-implement` or separate Claude sessions for M3-M7. Each milestone works on a separate feature branch. No file conflicts because each touches different directories.

### Phase 3: Release (Sequential — M8)

| Milestone | Description | Est. Sessions | Dependencies |
|-----------|-------------|---------------|--------------|
| **M8** | Docs & Release v1.0.0 | 1 | M1-M7 all complete |

**M8 deliverables:** README, CONTRIBUTING.md, UPGRADING.md, GitHub Release v1.0.0, branch protection.

### Dependency Graph

```
M1 (Scaffold + CI)
  │
  ▼
M2 (Install Script)
  │
  ├──► M3 (Web Templates: Astro, T3, SvelteKit, Remix) ──────┐
  │                                                            │
  ├──► M4 (Mobile Templates: NativeWind, Flutter, RevenueCat) ─┤
  │                                                            │
  ├──► M5 (Specialized: SaaS, AI/ML, Chrome Ext, CLI,         ├──► M8 (Docs + Release)
  │        Backend: FastAPI, Hono Edge)                        │
  │                                                            │
  ├──► M6 (Agent Ecosystem: 20+ imports, catalog, routing)  ──┤
  │                                                            │
  └──► M7 (Autonomous CI/CD: improve.yml)  ────────────────────┘
```

### Total Estimated Effort

| Phase | Sessions | Calendar Time (1 session/day) |
|-------|----------|-------------------------------|
| Phase 0 (Documentation) | 1 | 1 day (DONE) |
| Phase 1 (Foundation) | 2-3 | 2-3 days |
| Phase 2 (Parallel) | 2-3 (parallel) | 2-3 days |
| Phase 3 (Release) | 1 | 1 day |
| **Total** | **~6-8** | **~6-8 days** |

If running M3-M7 sequentially instead of in parallel: add 5-6 sessions (~11-13 total).

---

## Template Expansion Priority

### Full Template Catalog (16 total)

| # | Template | Category | Stack | Priority | Status |
|---|----------|----------|-------|----------|--------|
| 1 | web-nextjs | Web | Next.js 15 + Supabase | — | Existing |
| 2 | api-hono | Backend | Hono + Drizzle + PostgreSQL | — | Existing |
| 3 | mobile-expo | Mobile | Expo + TypeScript + Supabase | — | Existing |
| 4 | web-astro | Web | Astro 5 + Cloudflare Pages | P0 | M3 |
| 5 | web-t3 | Web | T3: Next.js + tRPC + Prisma | P0 | M3 |
| 6 | web-sveltekit | Web | SvelteKit 2 + Lucia + Drizzle | P1 | M3 |
| 7 | web-remix | Web | Remix + Vite + Cloudflare Workers | P1 | M3 |
| 8 | mobile-nativewind | Mobile | Expo + NativeWind + Supabase | P0 | M4 |
| 9 | mobile-flutter | Mobile | Flutter 3 + Supabase + Riverpod | P1 | M4 |
| 10 | mobile-expo-revenucat | Mobile | Expo + RevenueCat + IAP | P2 | M4 |
| 11 | saas-starter | Specialized | Next.js + Supabase + Stripe + Resend | P0 | M5 |
| 12 | ai-ml-app | Specialized | Next.js + AI SDK + pgvector | P0 | M5 |
| 13 | chrome-extension | Specialized | TypeScript + Vite + Chrome MV3 | P1 | M5 |
| 14 | cli-tool | Specialized | TypeScript + Commander.js + tsup | P2 | M5 |
| 15 | api-fastapi | Backend | FastAPI + SQLAlchemy + PostgreSQL | P0 | M5 |
| 16 | api-hono-edge | Backend | Hono + Cloudflare Workers + D1 | P1 | M5 |

---

## Agent Integration Roadmap

### Phase 1: Language Specialists (M6)

Import 8 language-specific agents from VoltAgent/awesome-claude-code-subagents:

| Agent | Language | Model Tier | Priority |
|-------|----------|-----------|----------|
| go-specialist | Go | sonnet | P0 |
| rust-specialist | Rust | sonnet | P0 |
| java-specialist | Java | sonnet | P1 |
| swift-specialist | Swift | sonnet | P1 |
| kotlin-specialist | Kotlin | sonnet | P1 |
| ruby-specialist | Ruby | sonnet | P2 |
| php-specialist | PHP | sonnet | P2 |
| elixir-specialist | Elixir | sonnet | P2 |

### Phase 2: Domain Specialists (M6)

Import 7 domain-specific agents:

| Agent | Domain | Source | Model Tier |
|-------|--------|--------|-----------|
| ml-pipeline-builder | AI/ML | VoltAgent + wshobson | opus |
| data-engineer | Data | VoltAgent | sonnet |
| prompt-engineer | AI | wshobson | opus |
| kubernetes-specialist | Infrastructure | wshobson | sonnet |
| terraform-specialist | Infrastructure | wshobson | sonnet |
| aws-architect | Cloud | wshobson | opus |
| gcp-specialist | Cloud | wshobson | sonnet |

### Phase 3: Mobile Specialists (M6)

Import 3 mobile-specific agents from senaiverse:

| Agent | Focus | Model Tier |
|-------|-------|-----------|
| rn-accessibility | WCAG 2.2 | sonnet |
| rn-performance | FPS/memory | sonnet |
| rn-security | OWASP mobile | sonnet |

### Preset Team Compositions (M6)

| Team | Agents | Use Case |
|------|--------|----------|
| `review` | code-reviewer, security-auditor, silent-failure-hunter | Code quality gate |
| `frontend` | frontend-dev, ui-designer, tdd-test-writer, whimsy-injector | Frontend sprint |
| `backend` | backend-dev, architect, security-auditor | API development |
| `fullstack` | architect, backend-dev, frontend-dev, test-writer-fixer | Full feature |
| `mobile` | mobile-app-builder, ui-designer, test-writer-fixer | Mobile app dev |
| `research` | researcher, trend-researcher, feedback-synthesizer | Research sprint |
| `security` | security-auditor, code-reviewer, silent-failure-hunter | Security audit |

---

## Autonomous CI/CD Specification

### Workflow 1: ci.yml (Every PR)

| Job | Tool | What It Checks |
|-----|------|---------------|
| lint-shell | shellcheck | All .sh files in hooks/ and scripts/ |
| lint-markdown | markdownlint-cli2 | All .md files in commands/, agents/, rules/ |
| validate-stacks | ajv-cli | All .yaml files in config/stacks/ against JSON Schema |
| validate-agents | custom script | Agent front-matter: name, description present |
| validate-workflows | actionlint | All .yml files in .github/workflows/ |
| inventory-check | custom script | Minimum file counts: commands ≥70, agents ≥60, hooks ≥12, rules ≥14, stacks ≥16 |

### Workflow 2: release.yml (Merge to main)

| Step | Action | What It Does |
|------|--------|-------------|
| 1 | googleapis/release-please-action@v4 | Parse conventional commits, determine version bump |
| 2 | (automatic) | Update CHANGELOG.md |
| 3 | (automatic) | Create GitHub Release with tag |

### Workflow 3: improve.yml (Weekly Monday 9am UTC)

| Step | What It Does |
|------|-------------|
| 1 | Check for existing open improvement PR — skip if one exists |
| 2 | Run anthropics/claude-code-action with improvement analysis prompt |
| 3 | Claude analyzes: agent catalog, template freshness, rule coverage, hook quality |
| 4 | Claude creates a single PR with all proposed improvements |
| 5 | PR labeled `autonomous-improvement`, requires human review |

**Guardrails:**
- Max 1 open improvement PR at a time
- Claude has restricted tool access (primarily read, limited write)
- NEVER modifies: settings.json, hooks, core commands (too high-risk for autonomous changes)
- CAN modify: agent files, stack templates, catalog.json, rules, community agents
- Human review always required — no auto-merge

---

## Personal Config Separation Guide

### Tracked in Git (Shared)

```
config/CLAUDE.md              # Global rules (public, non-personal)
config/settings.json          # Base permissions, hooks, plugins
config/.mcp.json              # Global MCP server config
config/stacks/*.yaml          # Stack templates
config/statusline-command.sh  # Status bar
commands/**                   # All slash commands
agents/**                     # All agent definitions
hooks/**                      # All hook scripts
rules/**                      # All rule files
skills/**                     # All skill definitions
agent_docs/**                 # Reference documentation
schemas/**                    # Validation schemas
scripts/**                    # CI/maintenance scripts
```

### NOT Tracked (Personal — in .gitignore)

```
settings.local.json           # Local model overrides, personal tokens
ghost-config.json             # Project paths, budget, trust level
ghost-stop                    # Emergency stop signal
command-audit.log             # Bash command history
stats-cache.json              # Metrics cache
metrics.jsonl                 # Session metrics
history.jsonl                 # Session history
mcp-needs-auth-cache.json     # MCP auth cache
logs/                         # Pipeline traces, ghost logs
sessions/                     # Session transcripts
plans/                        # Session planning artifacts
telemetry/                    # Telemetry data
cache/                        # Various caches
file-history/                 # File edit history
paste-cache/                  # Paste cache
shell-snapshots/              # Shell snapshots
plugins/                      # Plugin binary cache
agent-memory/                 # Per-agent project memory
projects/                     # Project-specific memory
```

---

## Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | Install script overwrites personal config | Medium | HIGH | Mandatory backup (default on), --dry-run flag, NEVER overwrite settings.local.json |
| 2 | Stack templates use deprecated APIs | Medium | Medium | Pin framework versions. improve.yml checks freshness weekly. Context7 for all framework APIs. |
| 3 | CI over-validates and blocks legitimate PRs | Low | Medium | Use warnings for style issues, errors only for structural problems |
| 4 | Personal config leaks to public repo | Low | HIGH | Comprehensive .gitignore, pre-commit check for .env files, settings.local.json gitignored |
| 5 | Imported community agents are low quality | Medium | Medium | Adaptation process normalizes quality. CI validates front-matter. Review before merge. |
| 6 | Autonomous improvement PRs are noisy/useless | Medium | Low | Weekly limit, skip-if-open logic, conservative prompt, human review always required |
| 7 | Symlink install breaks on some systems | Low | Medium | --mode=copy fallback. Test on macOS and Linux. |
| 8 | release-please creates unexpected version bumps | Low | Low | Conventional commits are already enforced by rules. MAJOR bumps require explicit `feat!:` or `BREAKING CHANGE:` |
| 9 | Agent catalog.json becomes stale | Medium | Medium | improve.yml checks catalog completeness weekly. CI validates catalog references real files. |
| 10 | Template init_commands fail on different Node/OS versions | Medium | Medium | Pin runtime versions in templates. Include .nvmrc in generated projects. |

---

## Quality Gates

### Per-Milestone Gates

Every milestone must pass before merging:

1. **CI passes** — all 6 validation jobs green
2. **Definition of Done** — checklist in milestone prompt fully checked off
3. **No regressions** — existing functionality still works (inventory counts don't decrease)
4. **Conventional commit** — merge commit follows `feat:` / `fix:` / `docs:` convention

### Pre-Release Gate (M8)

Before tagging v1.0.0:

1. All 8 milestones merged to main
2. Full CI pipeline passing
3. Install script tested on clean environment
4. All 16 templates present and validating against schema
5. catalog.json complete with all agents
6. improve.yml tested via manual dispatch
7. README accurately reflects actual repo contents
8. No TODO/FIXME in tracked files

---

## Post-Launch Considerations

### Community Contributions
- CONTRIBUTING.md provides clear guides for adding agents, templates, commands
- Issues templates for agent requests and template requests
- Community agents go in `agents/community/` — separate from core
- All contributions require CI pass and maintainer review

### Ongoing Maintenance
- improve.yml handles routine improvements (template versions, rule gaps)
- `/consolidate` weekly for learning system maintenance
- Review improvement PRs weekly (they accumulate if ignored)
- Pin action versions in CI — update via Dependabot

### Future Enhancements (v2.0)
- Auto model routing (runtime dynamic selection based on task complexity)
- Agent health checks (canary tasks that validate output structure)
- Party Mode (collaborative multi-agent sessions from BMAD)
- Agent marketplace install command
- Progressive disclosure in agent/skill prompts
- Homebrew formula distribution
- Cross-machine learning sync
- Interactive setup wizard
- Shell completion for all 70+ commands

---

## Working Notes

_This section is updated at the end of each work session._

### 2026-03-21 — Documentation Phase Complete
- All 5 documents created successfully
- Research covered 10 competing setups, identified key gaps and opportunities
- Brainstorm generated 25 ranked ideas across 8 categories
- Design document specifies complete repo structure, schemas, CI/CD, agent catalog
- 8 milestone prompts ready for `/implement-meta-prompt` execution
- Key insight: autonomous CI/CD (improve.yml) is genuinely novel — no competitor does this
- Key risk: install script must handle existing config gracefully — backup is critical
