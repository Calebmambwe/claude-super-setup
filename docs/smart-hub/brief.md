# Feature Brief: Smart Hub

**Created:** 2026-03-22
**Status:** Draft

---

## Problem

Caleb manages a complex development environment across three interconnected systems — claude-super-setup (80+ commands, 60+ agents, 16 stack templates), Smart Desk (5 MCP servers, 2 launchd daemons, RAG search, file organization), and autonomous pipelines (/auto-dev, /ghost-run, task tracking). All of this is managed exclusively through CLI and text files. There is no visual overview, no unified dashboard, and no way to monitor agent activity, daemon health, or pipeline progress at a glance. Context-switching between systems requires remembering file paths, JSON structures, and command names.

---

## Proposed Solution

A native macOS desktop app built with **Tauri 2.0 (Rust + React/TypeScript)** that serves as a unified command center. Four panels — Dashboard, Claude Setup Manager, Smart Desk Monitor, and Pipeline Mission Control — give at-a-glance visibility into all three systems. The app reads config/state files directly (watching for changes via FSEvents) and can trigger Claude Code commands via subprocess. Read-first approach: dashboards and viewers in early sprints, write operations (config editing, command execution) added later.

---

## Target Users

**Primary:** Caleb — solo developer managing a sophisticated Claude Code + Smart Desk environment. Uses it daily to monitor autonomous pipelines, manage agents, and track file organization.

**Secondary:** Other claude-super-setup users who want a visual management layer for their Claude Code configuration.

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Technical | Tauri 2.0, Rust backend, React + TypeScript frontend. Must handle 81MB audit log without freezing (streaming/virtualized). macOS-first. |
| Timeline | Ongoing side project — multi-sprint. Phase 1 (scaffold + dashboard) is the first deliverable. |
| Team | Solo developer (Caleb) + Claude Code autonomous pipelines |
| Integration | Must read from ~/.claude/, ~/.claude-super-setup/, ~/smart-desk/, ~/.smart-desk/ without modifying existing structures. Claude Code CLI as subprocess for command execution. |

---

## Scope

### In Scope
- Dashboard with at-a-glance cards (daemon status, active tasks, recent activity, repo health)
- Claude Setup Manager: browse agents, commands, rules, hooks, settings, stack templates
- Smart Desk Monitor: daemon status, audit log viewer, RAG search UI, file org stats
- Pipeline Mission Control: task board (kanban), pipeline progress, agent activity feed, PR tracker
- Live updates via file watchers (no polling)
- Quick action buttons for common Claude Code commands
- Dark/light theme support

### Out of Scope
- Physical desk BLE/hardware control
- LobeHub integration
- Mobile companion app
- Multi-machine sync
- Direct MCP client protocol (subprocess bridge instead)
- AI chat interface within the app (use Claude Code CLI directly)

---

## Feature Name

**Kebab-case identifier:** `smart-hub`

**Folder:** `docs/smart-hub/`

---

## Notes

### Research Highlights
- **Tauri 2.0** is stable and production-ready (2025). Rust + React is the community-preferred stack. 5-10x smaller than Electron apps.
- **No competing product** combines developer CLI management + IoT/daemon monitoring + AI pipeline tracking in a single desktop app. This is a novel combination.
- **notify-rs** (Rust) provides cross-platform file watching — ideal for reactive updates from tasks.json, metrics.jsonl, audit_log.jsonl.
- **shadcn/ui + Tailwind CSS** for consistent, accessible UI components.
- **Prior art explored:** Raycast (command palette, no persistent dashboard), Homarr/Dashy (self-hosted web dashboards, no Claude/MCP awareness), Mission Control (agent task management, no config management), GitHub Agent HQ (agent supervision UX pattern).

### Existing Smart Desk Architecture (to integrate with)
```
~/smart-desk/src/
├── mcp_servers/
│   ├── filesystem_mcp/   — file scanning, classification, dedup, moves
│   ├── process_mcp/      — process monitoring, resource management
│   ├── sync_mcp/         — cloud sync management
│   ├── rag_search_mcp/   — hybrid search (ChromaDB + SQLite FTS5)
│   └── audit_mcp/        — append-only audit logging
├── daemons/
│   ├── downloads_watcher.py — auto-classify ~/Downloads
│   └── resource_monitor.py  — background resource tracking
└── config/
    ├── routing_rules.yaml
    ├── allowlist.yaml
    └── sync_targets.yaml

State: ~/.smart-desk/
├── audit_log.jsonl (81MB)
├── fts.db (SQLite FTS5)
└── chroma/ (ChromaDB vectors)
```

### Prior Plans Referenced
- `~/.claude/plans/tidy-scribbling-valley.md` — Smart Desk architecture
- `~/.claude/plans/fluttering-seeking-robin.md` — LobeHub + Smart Desk MCP integration plan
- `~/.claude/plans/spicy-finding-shannon.md` — Smart Desk implementation plan
