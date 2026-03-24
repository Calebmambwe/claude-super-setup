# Cursor + Claude Code: Practical Usage Guide

How to use both editors together to get maximum power from your Claude Code super setup.

## 1. Two-Editor Workflow

**Claude Code** (runs in Cursor's terminal) = **Orchestrator brain**
- Planning, multi-file edits, full SDLC pipeline, code review, ghost mode
- Has 73 commands, 12 hooks, BMAD workflows, stack templates

**Cursor's Native Agent** = **Inline executor**
- Fast multi-file Composer edits, Cloud Agents on VMs, Automations, BugBot PR review
- Native AI features (Tab completion, inline suggestions)

They don't conflict. Use different entry points for different task scales.

## 2. Decision Matrix

| Task | Use | Why |
|------|-----|-----|
| Planning a feature (3+ files) | Claude Code `/plan` in terminal | 3-tier routing, Research Gate, BMAD |
| Quick inline fix (1-2 files) | Cursor Agent (Cmd+K or chat) | Faster for small changes |
| Multi-file refactor with spec | Claude Code `/build` | Resource Audit, dependency ordering |
| Multi-file refactor (no spec) | Cursor Composer | Faster for exploratory changes |
| Overnight autonomous run | Claude Code `/ghost` OR Cloud Agent | See Section 4 |
| PR review | Claude Code `/check` + BugBot | Run both — complementary |
| Library API question | Either (both have context7 MCP) | Same result |
| Design system compliance | Either (design-system.mdc loaded) | Same rule enforced |
| New project scaffold | Claude Code `/new-project` | Stack templates + .vscode + .cursor |
| Event-triggered automation | Cursor Automations | Slack/Linear/GitHub/PagerDuty triggers |

## 3. Claude Code in Cursor's Terminal

Open Cursor's integrated terminal (`Ctrl+\``) and run:

```bash
claude                    # Start interactive session
/plan my feature          # Full planning workflow
/build                    # Size-routed implementation
/auto-dev my feature      # Fully autonomous: plan → build → check → ship
/ghost "overnight task"   # Launch overnight pipeline
/check                    # Code review + security audit + tests
/ship                     # Commit + push + create PR
```

All commands work identically to VS Code. The Claude Code extension in Cursor gives the sidebar UI; the terminal gives full pipeline access. They share conversation history — you can resume a terminal session in the extension with `claude --resume`.

### Terminal Profile Setup

Ensure your API key is available in Cursor's terminal:

```bash
# Add to ~/.zshrc or ~/.bashrc
export ANTHROPIC_API_KEY="sk-ant-..."
```

## 4. Cloud Agents vs /ghost-run

| Feature | Claude Code /ghost (local) | Cursor Cloud Agent (remote) |
|---------|---------------------------|----------------------------|
| Where it runs | Your machine in `screen` session | Isolated VM in Cursor's cloud |
| Crash recovery | `ghost-watchdog.sh` restarts | Built-in auto-recovery |
| Survives laptop close | Yes (screen + caffeinate) | Yes (runs independently) |
| Video recording | No | Yes (attached to PR) |
| Local resources | Uses CPU/RAM/disk | Zero local consumption |
| Best for | When you want local control | Overnight runs, close laptop |
| Cost | Just API credits | Cursor subscription + API credits |

### When to Use Cloud Agents

- You want to close your laptop and sleep
- Multi-hour tasks that would drain battery
- Running multiple features in parallel (each on a separate Cloud Agent)
- You want video proof of what the agent did

### How to Launch a Cloud Agent

1. Go to `cursor.com/agents` (or use Cursor's Agent panel)
2. Provide the ghost-config.json context:
   ```
   Feature: {describe what to build}
   Trust: balanced
   Max tasks: 10
   Repository: {your repo URL}
   Branch: feat/ghost-{date}
   ```
3. Select model: claude-opus-4-6
4. Enable MCPs: context7, github
5. Launch — the Cloud Agent creates a PR when done

### Checkpoint Compatibility

Both environments use `.claude/pipeline-checkpoint.json` for resume:
- Start locally with `/ghost`, get interrupted → resume on Cloud Agent
- Start on Cloud Agent, want local control → `claude --resume` in terminal

## 5. Using MCP Servers in Cursor Agent

After running `/cursor-setup`, three MCP servers are available in Cursor's Agent chat:

| Server | How to Use | What It Does |
|--------|-----------|--------------|
| **context7** | Ask about any library API | Looks up current, version-specific documentation |
| **learning** | Automatic | Recalls patterns from past sessions across both editors |
| **sandbox** | Ask to run in sandbox | Isolated Docker execution (tests, builds) |

In Cursor Agent chat, MCP tools are used automatically when relevant. You can also explicitly ask:
- "Use context7 to look up the React Router v7 API"
- "Check the learning ledger for patterns in this project"

### Project MCP File Behavior

`/cursor-setup` creates `.cursor/mcp.json` in inherit-global mode by default:

```json
{ "mcpServers": {} }
```

This keeps `~/.cursor/mcp.json` as the canonical MCP server source and avoids per-project drift.

If you need explicit servers in the project file, run:

```bash
bash ~/.claude-super-setup/scripts/cursor-sync.sh project --project-mcp-mode=template --force
```

## 6. AGENTS.md Bridges Both Editors

`AGENTS.md` is the universal bridge — both Claude Code and Cursor read it natively.

**Generate:** Run `/init-agents-md` in Claude Code's terminal. It detects your stack and creates project-specific instructions.

**How it's used:**
- Claude Code reads it at every `/build`, `/auto-build`, `/ghost-run` start
- Cursor loads it automatically in every Agent chat when present in the project root
- The `consistency.mdc` rule instructs Cursor to check AGENTS.md before coding

**Keep it updated:** After significant new patterns emerge, run `/reflect` in Claude Code — it captures learnings and updates AGENTS.md.

**Team Rules workaround:** If you don't have Cursor Team/Enterprise, run:
```bash
bash ~/.claude-super-setup/scripts/cursor-team-rules-export.sh
```
This compiles all your `.mdc` rules into AGENTS.md, which both editors read. Instant "team rules" without the plan.

## 7. BYON (Bring Your Own Key/Model)

### For Claude Code (in Cursor's terminal)

Your `ANTHROPIC_API_KEY` from `~/.zshrc` is used automatically. Claude Code always uses your own API key — no Cursor subscription involved.

### For Cursor's Native Agent

Cursor's Agent uses Cursor's subscription by default. To use your own API key (BYON):

1. Open Cursor Settings (Cmd+,)
2. Navigate to **Models** section
3. Click **Add API Key**
4. Select provider: Anthropic
5. Paste your `ANTHROPIC_API_KEY`
6. Select model: claude-opus-4-6

Benefits of BYON in Cursor:
- Use Opus 4.6 at full 1M context without Cursor's rate limits
- Your API usage, your billing — no Cursor Pro+ needed for premium models
- Same key works in Claude Code terminal and Cursor Agent

### Model Selection Strategy

| Agent | Model | Why |
|-------|-------|-----|
| Claude Code (planning) | Opus 4.6 | Deep reasoning for architecture |
| Claude Code (subagents) | Sonnet 4.6 | Fast execution for file-level tasks |
| Cursor Agent | Opus 4.6 (BYON) or Cursor default | Full power for complex inline edits |
| Cursor Tab | Cursor's Tab model | Optimized for autocompletion speed |
| Cloud Agents | Opus 4.6 | Autonomous tasks need deep reasoning |

## 8. Pipeline Rules in Cursor

Six workflow rules are available as `.mdc` files:

| Rule | When to Invoke |
|------|---------------|
| `plan-workflow.mdc` | "Follow the /plan workflow for this task" |
| `build-workflow.mdc` | "Follow the /build workflow" |
| `auto-plan-workflow.mdc` | "Follow the /auto-plan workflow" |
| `auto-ship-workflow.mdc` | "Follow the /auto-ship workflow" |
| `ghost-workflow.mdc` | "Follow the /ghost workflow" |
| `ghost-run-workflow.mdc` | "Follow the /ghost-run workflow" |

These rules teach Cursor's native agent to follow the same structured workflows as Claude Code. They're loaded on-demand when you reference them in chat — they don't inject into every session.

## 9. Quick Health Check

Run these checks after setup:

```bash
# Global MCP is present + valid
jq . ~/.cursor/mcp.json

# Project rules generated
ls .cursor/rules/*.mdc

# Project MCP mode check (0 = inherit-global, >0 = explicit/template)
jq '.mcpServers | length' .cursor/mcp.json
```

Also verify:
- `AGENTS.md` exists in project root (shared context bridge for both editors)
- Claude Code extension is installed in Cursor
