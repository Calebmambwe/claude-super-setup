# Milestone 1: Repository Scaffold & CI Pipeline

## Section 1: Task Summary

**What:** Create the claude-super-setup git repository by migrating all existing configuration from `~/.claude/` into a structured, version-controlled repository with a CI pipeline that validates every PR.

**In scope:**
- Initialize git repo at `/Users/calebmambwe/claude_super_setup`
- Migrate all 70+ commands, 40+ agents, 12 hooks, 16 rules, 3 stack templates, skills, agent_docs
- Create JSON Schemas for stack template validation
- Create `.github/workflows/ci.yml` with 6 parallel validation jobs
- Create `.github/workflows/release.yml` with release-please
- Create validation scripts in `scripts/`
- Create `.gitignore` excluding personal files
- First passing CI run

**Out of scope:**
- install.sh (Milestone 2)
- New templates (Milestones 3-5)
- Agent imports (Milestone 6)
- improve.yml (Milestone 7)

**Definition of done:**
- [ ] All existing config files present in repo with correct directory structure
- [ ] `ci.yml` runs 6 validation jobs: shellcheck, markdownlint, YAML schema, actionlint, inventory, agent front-matter
- [ ] `release.yml` configured with release-please
- [ ] `.gitignore` excludes all personal files (settings.local.json, logs/, ghost-config.json, etc.)
- [ ] CI passes on initial commit
- [ ] Repo pushed to GitHub

## Section 2: Project Background

**Stack:** This is a configuration repository, not an application. It contains markdown files (commands, agents, rules), shell scripts (hooks), YAML files (stack templates), and JSON files (settings, schemas).

**Architecture:**
```
claude-super-setup/
├── config/              # Core config files (CLAUDE.md, settings.json, .mcp.json, stacks/)
├── commands/            # 70+ slash command definitions (.md)
├── agents/
│   ├── core/            # 40+ agent definitions (.md)
│   └── community/       # (empty for now, populated in M6)
├── hooks/               # 12 lifecycle hook scripts (.sh)
├── rules/               # 16 path-scoped rule files (.md)
├── skills/              # Skill definitions
├── agent_docs/          # Reference documentation
├── schemas/             # JSON Schema files for validation
├── scripts/             # CI validation scripts
├── user-overrides/      # Templates for personal config
├── .github/workflows/   # CI/CD pipelines
└── docs/                # Project documentation (already exists)
```

**Key conventions:**
- All markdown files use standard front-matter where applicable
- Shell scripts must pass shellcheck
- YAML stack templates must validate against `schemas/stack-template.schema.json`
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `ci:`

## Section 3: Current Task Context

This is the FIRST milestone. No prior milestones exist. This establishes the foundation that all other milestones build on.

## Section 4: Design Document Reference

See `docs/design/design-document.md` for:
- Section 2.1: Complete repository structure
- Section 3.1: Stack template YAML schema
- Section 3.4: Personal vs shared config classification (what to .gitignore)
- Section 4.2: CI validation pipeline specification
- Section 5: File naming conventions

## Section 5: Pre-Implementation Exploration

Before implementing:
1. Read `docs/design/design-document.md` — the architectural blueprint
2. Read `~/.claude/settings.json` — understand the hook architecture to migrate
3. Read `~/.claude/config/stacks/web-app.yaml` — canonical template format for schema creation
4. List all files in `~/.claude/commands/` — get the full command inventory
5. List all files in `~/.claude/agents/` — get the full agent inventory
6. List all files in `~/.claude/hooks/` — get the full hook inventory
7. List all files in `~/.claude/rules/` — get the full rule inventory
8. Read `~/.claude/config/stacks/api-service.yaml` and `mobile-app.yaml` — additional template examples

## Section 6: Implementation Instructions

### Architecture constraints
- Do NOT modify any files in `~/.claude/` — COPY them to the repo
- Do NOT include any personal config (settings.local.json, logs, ghost-config.json, etc.)
- settings.json must be cleaned: remove `skipDangerousModePermissionPrompt: true` (personal preference)
- CLAUDE.md must be reviewed: remove personal identity sections, keep universal rules

### Ordered build list

**Step 1: Copy config files**
```
cp -r ~/.claude/commands/ ./commands/
cp -r ~/.claude/hooks/ ./hooks/
cp -r ~/.claude/rules/ ./rules/
cp -r ~/.claude/skills/ ./skills/
cp -r ~/.claude/agent_docs/ ./agent_docs/
mkdir -p agents/core agents/community
cp -r ~/.claude/agents/*.md ./agents/core/
cp -r ~/.claude/agents/contains-studio/ ./agents/core/contains-studio/
mkdir -p config/stacks config/bmad
cp ~/.claude/config/stacks/*.yaml config/stacks/
cp ~/.claude/CLAUDE.md config/CLAUDE.md
cp ~/.claude/settings.json config/settings.json
cp ~/.claude/.mcp.json config/.mcp.json
cp ~/.claude/statusline-command.sh config/statusline-command.sh
```

**Step 2: Clean settings.json**
Remove personal fields:
- `skipDangerousModePermissionPrompt` → remove entirely
- `companyAnnouncements` → keep (generic)
- All hooks → keep (generic, paths use `~/.claude/` which is fine)

**Step 3: Create .gitignore**
```
# Personal config (never tracked)
settings.local.json
ghost-config.json
ghost-stop
command-audit.log
command-audit.log.tmp
stats-cache.json
metrics.jsonl
history.jsonl
mcp-needs-auth-cache.json

# Personal directories
logs/
sessions/
plans/
telemetry/
cache/
file-history/
paste-cache/
shell-snapshots/
plugins/
agent-memory/
projects/

# Runtime
node_modules/
.env*
*.lock
```

**Step 4: Create schemas/**
Create `schemas/stack-template.schema.json` based on the YAML format documented in the design doc Section 3.1. All 3 existing templates must validate against it.

**Step 5: Create scripts/**
- `scripts/validate-stacks.sh` — iterate config/stacks/*.yaml, validate against schema
- `scripts/validate-agents.sh` — check each agent .md has at minimum a title line
- `scripts/inventory-check.sh` — assert minimum file counts

**Step 6: Create CI workflows**
- `.github/workflows/ci.yml` — 6 parallel jobs (see design doc Section 4.2)
- `.github/workflows/release.yml` — release-please configuration

**Step 7: Create user-overrides/**
- `user-overrides/README.md` — instructions for personal config
- `user-overrides/settings.local.json.template` — template with common overrides
- `user-overrides/CLAUDE.md.personal.template` — template for personal additions

**Step 8: Create initial commit and push**
```
git init
git add -A
git commit -m "feat: initial scaffold with 70+ commands, 40+ agents, 12 hooks, 16 rules, 3 templates, CI pipeline"
gh repo create claude-super-setup --public --source=. --push
```

### Git workflow
- Work on `main` branch for initial scaffold
- All subsequent work uses feature branches

## Section 7: Final Reminders

- Run `shellcheck hooks/*.sh` locally before committing to verify hooks pass
- Validate all 3 stack templates against the schema before committing
- Verify `.gitignore` excludes everything listed in the design doc's personal config table
- Count files after migration: commands ≥70, agents ≥40, hooks ≥12, rules ≥14
- Do NOT create documentation files beyond what's specified (no extra READMEs)
- Commit with conventional commit message format
