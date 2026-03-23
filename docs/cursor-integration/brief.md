# Feature Brief: Cursor Integration

**Created:** 2026-03-23
**Status:** Draft

---

## Problem

Developers who have invested in a comprehensive Claude Code setup (50+ skills, hooks, MCP servers, BMAD pipeline, 16 stack templates, design system) are locked into VS Code as the only IDE that fully harnesses that power. Cursor IDE has emerged as the industry-standard agentic coding platform with unique capabilities (Cloud Agents on VMs, event-driven Automations, BugBot PR review, multi-model support) that Claude Code cannot replicate alone. Currently, switching to Cursor means losing all the skill/hook/pipeline infrastructure, and running both editors means maintaining two disconnected configurations manually.

---

## Proposed Solution

Build a **Cursor Integration Layer** consisting of three components:

1. **Config Sync Engine** (`cursor-sync`) — A CLI tool and Claude Code skill that mirrors MCP server configs, generates Cursor `.mdc` rules from Claude Code skills, and creates a `.cursor/` project template. One-way push: Claude Code is the source of truth, Cursor is the consumer.

2. **Cursor Project Template** (`~/.claude/config/cursor-template/`) — A drop-in `.cursor/` directory with rules, MCP config, and settings that gets scaffolded into every new project alongside `.vscode/`. Includes auto-generated `.mdc` rules for design-system, backend-architecture, git workflow, and consistency checks.

3. **`/cursor-setup` Skill** — One-command setup that installs the Claude Code extension in Cursor, syncs global MCP configs, generates project rules, and validates the integration. Also includes Cursor Automation templates for common pipelines (auto-review, ghost-run dispatch, incident response).

The core mechanism: Claude Code remains the orchestrator brain (planning, pipelines, SDLC). Cursor provides an additional execution surface (Cloud Agents for async work, Automations for event-driven triggers, native AI for inline editing). Both editors share the same MCP servers, the same project rules (via AGENTS.md + .mdc), and the same git workflow.

---

## Target Users

**Primary:** Power users of the Claude Code super setup who want to also leverage Cursor's Cloud Agents, Automations, and native AI features — developers running complex multi-agent workflows across planning, implementation, and review.

**Secondary:** Team members who prefer Cursor as their primary editor but want to benefit from the same skills, rules, and patterns that Claude Code enforces.

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Technical | Must not modify or break existing `~/.claude/` infrastructure. Must work alongside VS Code setup (both editors usable simultaneously on same projects). MCP configs must stay in sync without manual intervention. |
| Timeline | MVP in 1 sprint (6 days): config sync + template + /cursor-setup skill |
| Team | 1 engineer (Claude Code autonomous pipeline) |
| Integration | Must integrate with Cursor's `.cursor/rules/*.mdc` format, `~/.cursor/mcp.json` global config, and `.cursor/mcp.json` project config. Must support Cursor's variable interpolation (`${workspaceFolder}`, `${env:NAME}`). |

---

## Scope

### In Scope

1. **MCP Config Sync** — Script to mirror `~/.mcp.json` to `~/.cursor/mcp.json` with format validation
2. **Cursor Template Directory** — `~/.claude/config/cursor-template/` with:
   - `.cursor/rules/` — Auto-generated `.mdc` rules from core skills (design-system, backend-architecture, docker, git-workflow, consistency)
   - `.cursor/mcp.json` — Project-level MCP config template
   - `.cursor/settings.json` — Cursor-specific AI settings (model preferences, agent config)
3. **`/cursor-setup` Skill** — One-command that:
   - Syncs global MCP configs
   - Installs Claude Code extension in Cursor (via .vsix if needed)
   - Generates `.cursor/` directory for current project
   - Validates all MCP servers are accessible
   - Prints integration status dashboard
4. **Scaffold Integration** — Update `/new-project` to include `.cursor/` alongside `.vscode/`
5. **AGENTS.md Enhancement** — Ensure `/init-agents-md` outputs instructions compatible with both Claude Code and Cursor
6. **Cursor Automation Templates** — Pre-built automation configs for:
   - Auto PR review (triggers on GitHub PR open)
   - Ghost-run dispatch (triggers on Linear issue assignment)
   - Incident response (triggers on PagerDuty alert)
7. **Documentation** — Usage guide in `docs/cursor-integration/`

### Out of Scope
- Bidirectional rule sync (Cursor rules edits back to Claude Code skills)
- Cursor Automation API programmatic provisioning (manual setup via cursor.com/automations)
- Replacing Claude Code's pipeline with Cursor's native agent
- Cursor Team Rules dashboard integration (requires Team/Enterprise plan)
- Custom Cursor extensions or plugins beyond configuration

---

## Feature Name

**Kebab-case identifier:** `cursor-integration`

**Folder:** `docs/cursor-integration/`

---

## Notes

- Research report: `docs/research-cursor-integration.md` (15 sources, completed 2026-03-23)
- Cursor supports AGENTS.md natively — this is the universal bridge between both editors
- `add-mcp` CLI (by Neon) can help with cross-editor MCP sync but our custom sync gives more control
- 30% of Cursor's own PRs are created by Cloud Agents — validates the async execution model
- Cursor's `.mdc` format supports frontmatter (`description`, `alwaysApply`, `globs`) which maps cleanly to Claude Code skill metadata
- Cloud Agents record video of their work sessions — useful for review and debugging
- Cursor Automations support: cron schedules, Slack, Linear, GitHub, PagerDuty, custom webhooks
- Both tools use the same MCP server JSON structure — the sync is mostly a file copy with path adjustment
