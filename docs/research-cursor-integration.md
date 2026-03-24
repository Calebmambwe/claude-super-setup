# Research Report: Cursor IDE Integration with Claude Code Super Setup

**Date:** 2026-03-23
**Research Type:** Technical + Competitive
**Sources Consulted:** 15+

## Executive Summary

Cursor IDE has evolved from a VS Code fork with chat into the industry-standard agentic coding platform. It now features Cloud Agents (autonomous VMs), Automations (event-driven agents), a mature rules system (.cursor/rules with .mdc format), and full MCP server support with the same stdio/SSE/HTTP transports Claude Code uses. The existing Claude Code super setup (skills, hooks, MCP servers, BMAD pipeline, stack templates) can be fully bridged to Cursor with a configuration sync layer, shared MCP servers, and Cursor-native rules that mirror CLAUDE.md behavior.

Key findings:
- Cursor supports MCP natively via `~/.cursor/mcp.json` and `.cursor/mcp.json` - same format as Claude Code
- Cursor's rules system (.mdc files with frontmatter) maps directly to Claude Code's CLAUDE.md + skills
- Cursor Cloud Agents + Automations provide async execution that complements Claude Code's /ghost-run
- The `add-mcp` CLI can sync MCP configs across both tools automatically
- 30% of Cursor's own PRs are now created by Cloud Agents

## Research Questions & Answers

### Q1: How does Cursor's extension/plugin model work?

**Answer:** Cursor is a VS Code fork, so it supports VS Code extensions natively. However, its AI layer is built directly into the editor core (not an extension). Key AI features: Agent mode, Tab completion, Composer (multi-file editing), Background Agents (remote VMs), Automations (event-triggered agents), BugBot (PR review). Claude Code's VS Code extension (.vsix) can be manually installed in Cursor if auto-detection fails.

**Confidence:** High

### Q2: Does Cursor support MCP servers natively?

**Answer:** Yes, full MCP support across all tiers. Configuration via:
- **Global:** `~/.cursor/mcp.json`
- **Project:** `.cursor/mcp.json`
- **Transports:** stdio, SSE, Streamable HTTP
- **Features:** Tools, Prompts, Resources, Roots, Elicitation, Apps
- **Variables:** `${env:NAME}`, `${userHome}`, `${workspaceFolder}`

The format is identical to Claude Code's `.mcp.json` structure. Our existing context7, sandbox, and learning MCPs can be shared directly.

**Confidence:** High

### Q3: How does Cursor handle terminal integration?

**Answer:** Cursor has a built-in terminal (inherited from VS Code). Claude Code CLI runs in Cursor's terminal the same way it does in VS Code. The Claude Code extension can be installed in Cursor and shares conversation history with the CLI. Agent mode has terminal access for running commands. Cursor also launched its own CLI (`cursor` command) as an alternative to Claude Code.

**Confidence:** High

### Q4: What Cursor-specific features could amplify Claude Code?

**Answer:**
1. **Cloud Agents** - Spin up VMs to run tasks asynchronously, create PRs with video recordings
2. **Automations** - Event-driven agents triggered by Slack, Linear, GitHub, PagerDuty, webhooks, or cron schedules
3. **BugBot** - Automated PR review on GitHub
4. **Composer** - Multi-file conversational editing
5. **Multi-model support** - GPT-5.2, Opus 4.6, Gemini 3 Pro, Grok Code
6. **Memory tool** - Agents learn from past runs

**Confidence:** High

### Q5: How do competing AI CLI tools integrate with Cursor?

**Answer:** Cursor has its own CLI now. Claude Code integrates via terminal + extension. The key differentiator is that Claude Code has a richer skill/hook/pipeline system (BMAD, auto-dev, ghost-run) that Cursor's native agent doesn't have. Bridging these gives the best of both worlds.

**Confidence:** High

### Q6: What are the gaps between VS Code and Cursor for Claude Code?

**Answer:**
| Gap | VS Code | Cursor |
|-----|---------|--------|
| MCP config location | `~/.mcp.json` | `~/.cursor/mcp.json` |
| Rules system | CLAUDE.md + AGENTS.md | `.cursor/rules/*.mdc` + AGENTS.md |
| Extension ID | `anthropic.claude-code` | Manual .vsix install may be needed |
| Settings keys | `claudeCode.*` | Same (VS Code compatible) |
| Background agents | Claude Code /ghost-run (local) | Cloud Agents (remote VM) |
| Automations | Claude Code hooks | Cursor Automations (event-driven) |

**Confidence:** High

### Q7: What .cursorrules patterns exist?

**Answer:** Cursor has evolved from legacy `.cursorrules` (single file, deprecated) to `.cursor/rules/*.mdc` (multiple files with frontmatter). Rules support:
- `alwaysApply: true/false` - always inject or AI-decides
- `globs: ["**/*.ts"]` - file-pattern-triggered
- `description:` - used by AI to decide relevance
- Team Rules via dashboard (Team/Enterprise)
- AGENTS.md as simpler alternative (also supported)

**Confidence:** High

## Competitive Feature Matrix

| Feature | Claude Code (Super Setup) | Cursor Native | Gap/Opportunity |
|---------|--------------------------|---------------|-----------------|
| MCP Servers | 3 (context7, sandbox, learning) | Full MCP support | Sync configs |
| Skills System | 50+ skills | Rules (.mdc) | Generate .mdc from skills |
| Hooks | Pre/post command hooks | Automations | Bridge hooks to automations |
| Pipeline (/auto-dev) | Full SDLC pipeline | Cloud Agents | Trigger Cloud Agents from pipeline |
| Stack Templates | 16 templates | No equivalent | Expose via MCP or rules |
| BMAD Workflows | 12 workflows | No equivalent | Unique differentiator |
| Code Review | Multi-agent (/check) | BugBot | Use both |
| Background Execution | /ghost-run (local) | Cloud Agents (VM) | Use Cloud Agents for /ghost |
| Design System | Full token system | No equivalent | Inject via rules |
| Learning System | MCP learning ledger | Agent memory | Sync learnings |

## Key Insights

### Insight 1: MCP Config Sync is the Foundation
**Finding:** Both tools use identical MCP server JSON format.
**Implication:** A single sync script can mirror `~/.mcp.json` to `~/.cursor/mcp.json`.
**Recommendation:** Build a `cursor-sync` skill that keeps MCP configs in sync.
**Priority:** High

### Insight 2: Rules = Skills Translation Layer
**Finding:** Cursor's `.mdc` rules with frontmatter map directly to Claude Code skills.
**Implication:** Each Claude Code skill can be auto-generated into a `.mdc` rule file.
**Recommendation:** Build a `generate-cursor-rules` command that reads skills and outputs .mdc files.
**Priority:** High

### Insight 3: Cloud Agents Replace Local Ghost Mode
**Finding:** Cursor Cloud Agents run on isolated VMs, create PRs with video recordings.
**Implication:** /ghost-run could dispatch to Cloud Agents instead of running locally.
**Recommendation:** Add Cloud Agent dispatch as an option in the ghost pipeline.
**Priority:** Medium

### Insight 4: Automations Enable Event-Driven Development
**Finding:** Cursor Automations trigger agents from Slack, Linear, GitHub, PagerDuty, cron.
**Implication:** Claude Code hooks can be exposed as Cursor Automation triggers.
**Recommendation:** Create automation templates that bridge to Claude Code pipelines.
**Priority:** Medium

### Insight 5: AGENTS.md is the Universal Bridge
**Finding:** Both Cursor and Claude Code support AGENTS.md natively.
**Implication:** AGENTS.md becomes the single source of truth for project rules across both editors.
**Recommendation:** Enhance /init-agents-md to generate Cursor-compatible instructions.
**Priority:** High

### Insight 6: Shared Workspace Template
**Finding:** VS Code template exists at `~/.claude/config/vscode-template/` but no Cursor equivalent.
**Implication:** A parallel Cursor template with .cursor/rules, .cursor/mcp.json would complete the setup.
**Recommendation:** Create `~/.claude/config/cursor-template/` with rules, MCP config, and settings.
**Priority:** High

## Recommendations

### Immediate Actions (This Sprint)
1. Create `cursor-sync` CLI tool to mirror MCP configs
2. Create `.cursor/` template directory with rules and MCP config
3. Generate `.mdc` rules from existing skills (design-system, backend-architecture, docker)
4. Enhance `/new-project` scaffold to include `.cursor/` alongside `.vscode/`

### Short-term (Next 2 Sprints)
1. Build Cursor Automation templates for common Claude Code pipelines
2. Add Cloud Agent dispatch to `/ghost-run`
3. Sync learning ledger with Cursor's agent memory
4. Create `/cursor-setup` skill for one-command Cursor integration

### Long-term (Ongoing)
1. Build bidirectional rule sync (changes in .cursor/rules reflect back to skills)
2. Explore Cursor's API for programmatic Cloud Agent creation
3. Create Cursor Automation for auto-PR-review using Claude Code's /check pipeline

## Sources

1. [Cursor MCP Documentation](https://cursor.com/docs/context/mcp)
2. [Cursor Rules Documentation](https://cursor.com/docs/context/rules)
3. [Cursor Features](https://cursor.com/features)
4. [Cursor Cloud Agents Guide](https://www.nxcode.io/resources/news/cursor-cloud-agents-virtual-machines-autonomous-coding-guide-2026)
5. [Cursor Automations Blog](https://cursor.com/blog/automations)
6. [Cursor Webhooks API](https://cursor.com/docs/cloud-agent/api/webhooks)
7. [Claude Code vs Cursor Comparison](https://www.builder.io/blog/cursor-vs-claude-code)
8. [Cursor .cursorrules Guide](https://markaicode.com/cursor-cursorrules-project-ai-instructions/)
9. [MCP Setup Guide for Cursor](https://dev.to/serenitiesai/how-to-set-up-mcp-servers-in-cursor-ide-complete-guide-2026-5gdl)
10. [VS Code vs Cursor 2026](https://markaicode.com/vscode-vs-cursor-2026-comparison/)
11. [Cursor Scaling Agents Blog](https://cursor.com/blog/scaling-agents)
12. [Claude Code in VS Code Docs](https://code.claude.com/docs/en/vs-code)
13. [add-mcp CLI](https://neon.com/blog/add-mcp)
14. [Cursor AI Comprehensive Review 2026](https://createaiagent.net/tools/cursor/)
15. [Awesome Cursorrules GitHub](https://github.com/PatrickJS/awesome-cursorrules)

---

*Generated by BMAD Method v6 - Creative Intelligence*
*Research Duration: ~15 minutes*
*Sources Consulted: 15*
