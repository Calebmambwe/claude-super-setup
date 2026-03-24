---
name: cursor-setup
description: "One-command Cursor IDE integration — syncs MCP servers, generates .mdc rules, validates setup"
---

# /cursor-setup

Set up Cursor IDE integration with Claude Code's super setup. This bridges your skills, MCP servers, rules, and design system into Cursor's native rules and MCP configuration.

## What It Does

1. **Detects Cursor** — Checks for /Applications/Cursor.app or `cursor` CLI
2. **Syncs Global MCP** — Mirrors `~/.mcp.json` to `~/.cursor/mcp.json` (converts paths to `${userHome}`)
3. **Creates Project .cursor/** — Sets up `.cursor/mcp.json` for project-level MCP
4. **Generates Rules** — Converts Claude Code skills + rules into `.cursor/rules/*.mdc` files
5. **Validates** — Checks all integrations, MCP server reachability, frontmatter validity

## Usage

```bash
# Full setup (global + project + rules + validate)
/cursor-setup

# Just check current status
/cursor-setup --validate

# Re-sync after skill/rule changes
/cursor-setup --refresh
```

## Implementation

When the user runs `/cursor-setup`:

### Default (no flags)

```bash
bash "$HOME/.claude-super-setup/scripts/cursor-sync.sh" all
```

### --validate flag

```bash
bash "$HOME/.claude-super-setup/scripts/cursor-sync.sh" validate
```

### --refresh flag

```bash
bash "$HOME/.claude-super-setup/scripts/cursor-sync.sh" global --force
bash "$HOME/.claude-super-setup/scripts/cursor-sync.sh" rules --force
bash "$HOME/.claude-super-setup/scripts/cursor-sync.sh" validate
```

### --watch flag

Starts bidirectional sync. When you edit `.cursor/rules/*.mdc` files in Cursor, changes sync back to the source skills and rules automatically.

```bash
bash "$HOME/.claude-super-setup/scripts/cursor-watch.sh" start
```

Reports the watcher PID and log file location. Safe to leave running — uses minimal CPU via fswatch events (not polling). Requires `fswatch` (`brew install fswatch`).

To stop: `bash "$HOME/.claude-super-setup/scripts/cursor-watch.sh" stop`
To check: `bash "$HOME/.claude-super-setup/scripts/cursor-watch.sh" status`

### --export-team-rules flag

Compiles all `.mdc` rules into `AGENTS.md` — a workaround for sharing rules without Cursor Team/Enterprise plan. Both Claude Code and Cursor read AGENTS.md natively.

```bash
bash "$HOME/.claude-super-setup/scripts/cursor-team-rules-export.sh"
```

Preserves any custom content above the `<!-- GENERATED RULES BELOW -->` marker.

## Post-Setup Checklist

After running `/cursor-setup`, verify:

1. Open Cursor IDE
2. Open the project directory
3. Check that `.cursor/rules/` contains .mdc files (visible in file explorer)
4. Open Agent chat and ask "What rules are loaded?" — should list the generated rules
5. Try using an MCP tool (e.g., Context7) in Cursor's agent chat

## Claude Code Extension in Cursor

If the validation shows the Claude Code extension is missing:

1. Open Cursor
2. Go to Extensions (Cmd+Shift+X)
3. Search "Claude Code"
4. Install the Anthropic extension
5. Or manually: find the .vsix at `~/.vscode/extensions/anthropic.claude-code-*/` and drag into Cursor

## Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `~/.cursor/mcp.json` | Created/Updated | Global MCP config for Cursor |
| `.cursor/mcp.json` | Created | Project-level MCP config |
| `.cursor/rules/*.mdc` | Created | 16 rule files (10 skills/rules + 6 pipeline workflows) |

## Troubleshooting

**MCP servers not working in Cursor:**
- Check `~/.cursor/mcp.json` has valid JSON: `jq . ~/.cursor/mcp.json`
- Ensure `npx`, `uv`, `python3` are in PATH
- Restart Cursor after config changes

**Rules not loading:**
- Cursor rules require `.mdc` extension with `---` frontmatter
- Check `alwaysApply: true` rules appear in every chat
- Check `globs` rules appear only for matching files

**Extension conflicts:**
- Claude Code extension and Cursor's native agent can coexist
- Use Claude Code for pipeline orchestration (/auto-dev, /ghost)
- Use Cursor's agent for inline editing and multi-file composer
