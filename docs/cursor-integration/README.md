# Cursor IDE Integration Guide

Bridge Claude Code's full power into Cursor IDE — MCP servers, rules, design system, and pipeline intelligence.

## Prerequisites

- Claude Code super setup installed (`~/.claude-super-setup/`)
- Cursor IDE installed ([cursor.com](https://cursor.com))
- `jq` installed (`brew install jq`)

## Quick Start

```bash
# Run from any project directory
/cursor-setup
```

This single command:
1. Syncs your MCP servers (context7, sandbox, learning) to Cursor
2. Generates `.cursor/rules/*.mdc` from your Claude Code skills and rules
3. Creates project-level `.cursor/mcp.json` (default: inherit global MCP)
4. Validates everything works

## What Gets Synced

### MCP Servers (Global)

Your `~/.mcp.json` is mirrored to `~/.cursor/mcp.json`. Both editors share the same servers:

| Server | Purpose |
|--------|---------|
| context7 | Library/framework documentation lookup |
| sandbox | Isolated Docker execution environment |
| learning | Persistent learning ledger across sessions |

### Project MCP Strategy

By default, `cursor-sync project` writes a minimal project config:

```json
{ "mcpServers": {} }
```

This means the project inherits MCP servers from `~/.cursor/mcp.json` (global source of truth), which avoids project-level drift.

If you want explicit project MCP servers copied from the template, run:

```bash
bash ~/.claude-super-setup/scripts/cursor-sync.sh project --project-mcp-mode=template --force
```

### Rules (Per-Project)

10 `.mdc` rule files are generated in `.cursor/rules/`:

| Rule | Source | Applied When |
|------|--------|-------------|
| `design-system.mdc` | skills/design-system | Editing .tsx, .jsx, .css |
| `backend-architecture.mdc` | skills/backend-architecture | Editing .ts, .py, routes, services |
| `docker.mdc` | skills/docker | Editing Dockerfiles, compose files |
| `git-workflow.mdc` | rules/git.md | Always (every chat) |
| `consistency.mdc` | rules/consistency.md | Always (every chat) |
| `typescript.mdc` | rules/typescript.md | Editing .ts, .tsx |
| `python.mdc` | rules/python.md | Editing .py |
| `security.mdc` | rules/security.md | Always (every chat) |
| `testing.mdc` | rules/testing.md | Editing test files |
| `api.mdc` | rules/api.md | Editing routes, controllers |

### AGENTS.md (Shared)

Both Claude Code and Cursor read `AGENTS.md` natively. It serves as the universal bridge for project-specific context.

## Manual Sync

```bash
# Sync only global MCP config
bash ~/.claude-super-setup/scripts/cursor-sync.sh global

# Regenerate rules only
bash ~/.claude-super-setup/scripts/cursor-sync.sh rules --force

# Create project MCP from template servers (explicit mode)
bash ~/.claude-super-setup/scripts/cursor-sync.sh project --project-mcp-mode=template --force

# Preview changes without writing
bash ~/.claude-super-setup/scripts/cursor-sync.sh all --dry-run

# Check integration status
bash ~/.claude-super-setup/scripts/cursor-sync.sh validate
```

## Agent Roles (VS Code + Cursor)

| Agent | Role | Best For |
|-------|------|----------|
| **Claude Code** (terminal) | Orchestrator brain | Planning, multi-file edits, SDLC pipeline, code review |
| **Cursor Agent** | Autonomous executor | Cloud Agents (VM), multi-file Composer, background tasks |
| **Cursor Tab** | Inline completion | Fast ghost text predictions |
| **Copilot** | Tab completion | Inline suggestions alongside Cursor |

## Cursor Automations

Pre-built automation templates are in `config/cursor-automations/`:

1. **auto-pr-review.yaml** — Review PRs on GitHub open (code quality, security, tests)
2. **ghost-run-dispatch.yaml** — Auto-implement Linear issues labeled "auto-build"
3. **incident-response.yaml** — Investigate PagerDuty incidents, propose fixes

To use: Import templates at [cursor.com/automations](https://cursor.com/automations)

## Architecture

```
Claude Code (source of truth)     Cursor IDE (consumer)
~/.claude/skills/            -->  .cursor/rules/*.mdc
~/.mcp.json                  -->  ~/.cursor/mcp.json
rules/*.md                   -->  .cursor/rules/*.mdc
CLAUDE.md                    -->  .cursor/rules/project-conventions.mdc
AGENTS.md                    <->  AGENTS.md (shared, both read it)
```

One-way sync: Claude Code skills/rules push to Cursor. Edit in Claude Code, sync to Cursor.

## Validation Checklist

After `/cursor-setup`, verify:

1. `~/.cursor/mcp.json` exists and is valid JSON (`jq . ~/.cursor/mcp.json`)
2. `.cursor/rules/` exists with `.mdc` files
3. `.cursor/mcp.json` exists:
   - `0` servers = inherit-global mode (default)
   - `>0` servers = explicit/template mode
4. `AGENTS.md` exists in project root for shared context across editors
5. Claude Code extension is installed in Cursor

## Troubleshooting

### MCP servers not responding

```bash
# Verify commands are in PATH
which npx uv python3

# Check config is valid JSON
jq . ~/.cursor/mcp.json

# Restart Cursor after config changes
```

### Rules not loading in Cursor

- Rules need `.mdc` extension (not `.md`)
- Each rule must start with `---` frontmatter block
- `alwaysApply: true` rules inject into every chat
- `globs` rules only activate for matching file patterns
- Restart Cursor if rules were just created

### Claude Code extension in Cursor

If auto-detection fails:
1. Find .vsix: `ls ~/.vscode/extensions/anthropic.claude-code-*`
2. Drag .vsix into Cursor Extensions panel
3. Or: Open Cursor Extensions, search "Claude Code", install
