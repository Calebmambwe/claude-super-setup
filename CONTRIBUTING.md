# Contributing to claude-super-setup

## Adding a New Agent

1. Create a file in the appropriate directory:
   - `agents/core/{department}/` for maintained agents
   - `agents/community/{category}/` for imported/adapted agents

2. Use YAML front-matter:
```yaml
---
name: my-agent
department: engineering
description: What this agent does
model: sonnet
tools: [Read, Write, Edit, Bash, Grep, Glob]
---
```

3. Add to `agents/catalog.json` with capabilities and team assignments

4. Update `scripts/inventory-check.sh` if minimum counts change

## Adding a New Stack Template

1. Create a YAML file in `config/stacks/`

2. Follow the schema in `schemas/stack-template.schema.json`

3. Required fields: name, description, short_label, init_commands, directories, starter_files, commands, env_example, claude_md, agents_md

4. Validate: `bash scripts/validate-stacks.sh`

5. Reference existing templates as examples (web-app.yaml, api-service.yaml)

## Adding a New Command

1. Create a markdown file in `commands/`
2. Use kebab-case naming: `my-command.md`
3. Include a clear title and description

## Adding a New Rule

1. Create a markdown file in `rules/`
2. Add path matcher in `config/settings.json` hooks if auto-loading is needed

## Running Validation Locally

```bash
# All validations
bash scripts/validate-agents.sh
bash scripts/validate-stacks.sh
bash scripts/inventory-check.sh

# Shell script linting
shellcheck hooks/*.sh scripts/*.sh
```

## Commit Convention

Use conventional commits:
- `feat:` new agent, template, command, or feature
- `fix:` bug fix in hooks, scripts, or templates
- `docs:` documentation changes
- `ci:` CI/CD workflow changes
- `refactor:` restructuring without behavior change
- `test:` validation script changes

## Pull Requests

- CI must pass before merge
- One logical change per PR
- Update inventory counts if adding/removing files
- Include clear description of what changed and why
