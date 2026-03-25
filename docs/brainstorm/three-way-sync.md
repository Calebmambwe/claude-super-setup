# Brainstorm: Three-Way Automatic Sync

**Date:** 2026-03-25
**Problem:** Three environments must stay in perfect sync — any change on one should propagate to the others automatically.

---

## The Three Environments

```
┌─────────────────────────┐
│  1. LOCAL MAC            │
│  ~/claude_super_setup    │  ← You work here daily
│  ~/.claude/              │
│  The "source of truth"   │
└────────────┬────────────┘
             │ git push
             ▼
┌─────────────────────────┐
│  GitHub Repo             │
│  Calebmambwe/            │  ← Central hub
│  claude-super-setup      │
└──────┬──────────┬────────┘
       │          │
       ▼          ▼
┌──────────────┐ ┌──────────────┐
│ 2. VPS       │ │ 3. AGENTOS   │
│ Claude Code  │ │ (uses VPS    │
│ ~/.claude-   │ │  Claude Code │
│ super-setup  │ │  under hood) │
└──────────────┘ └──────────────┘
```

**Key insight:** AgentOS uses the VPS Claude Code installation, so environments 2 and 3 share the same `~/.claude/` config. The real sync challenge is **Mac ↔ VPS** (bidirectional).

---

## Current Sync Mechanism

| What | How | Trigger | Direction |
|------|-----|---------|-----------|
| Code (commands, agents, hooks, scripts) | Git push/pull | Manual | Mac → GitHub → VPS |
| Config (settings.json, .mcp.json) | `install.sh` symlinks | Manual `git pull` | One-way |
| API keys | `sync-to-vps.sh` | Manual | Mac → VPS |
| Learning ledger | Independent SQLite DBs | Never synced | Isolated |
| Memory (MEMORY.md) | In git (per-project) | Manual commit | Mac → VPS |
| AGENTS.md | In git | Manual commit | Bidirectional via git |

**Problems:**
1. Manual — you have to remember to push/pull
2. One-directional — VPS changes don't flow back to Mac
3. Config drift — settings.json edited locally on VPS diverges from Mac
4. Learnings isolated — Mac learns things VPS doesn't know and vice versa

---

## Solution: Git-Based Auto-Sync with Hooks

### Why Git (not rsync/syncthing)?

- Already the mechanism — both machines clone the same repo
- `install.sh` uses symlinks — pull = instant sync
- Merge conflicts handled by git (not silent overwrites)
- Audit trail — every change is a commit
- Works over SSH (no new ports/services needed)
- AgentOS gets changes for free (same filesystem as VPS Claude Code)

### The Auto-Sync Architecture

```
MAC (post-commit hook)                    VPS (cron every 5 min)
       │                                        │
       │ git push                                │ git pull
       ▼                                        ▼
   GitHub Repo  ◄──────────────────────►   GitHub Repo
       │                                        │
       │                                        │ install.sh --quick
       │                                        ▼
       │                                   ~/.claude/ updated
       │                                   (symlinks resolve
       │                                    to new content)
       │
       │  VPS changes flow back:
       │  VPS auto-commits + pushes
       │  Mac pulls on next session start
```

### Three Sync Triggers

#### Trigger 1: Mac Push Hook (instant, Mac → VPS)
When you commit and push on Mac, the VPS auto-pulls within 5 minutes.

```bash
# .git/hooks/post-push (Mac)
#!/bin/bash
# After pushing, notify VPS to pull
sshpass -p "$VPS_PASS" ssh root@$VPS_IP \
  'cd ~/.claude-super-setup && git pull -q && echo "VPS synced"' &
```

#### Trigger 2: VPS Cron Pull (every 5 min, GitHub → VPS)
Belt and suspenders — even if the push hook fails.

```bash
# Cron on VPS (claude user)
*/5 * * * * cd ~/.claude-super-setup && git pull -q 2>/dev/null
```

#### Trigger 3: VPS Auto-Push (VPS → GitHub → Mac)
When VPS modifies configs (e.g., Darwin creates proposals, learning ledger changes), auto-commit and push.

```bash
# Cron on VPS (every 30 min)
*/30 * * * * cd ~/.claude-super-setup && \
  git add -A && \
  git diff --cached --quiet || \
  git commit -m "sync: auto-commit VPS changes $(date +%Y%m%d-%H%M)" && \
  git push -q
```

#### Trigger 4: Mac Session Start Pull (Mac ← GitHub)
On every Claude Code session start, pull latest (catches VPS changes).

```bash
# In hooks/session-start.sh
cd ~/.claude-super-setup && git pull -q 2>/dev/null &
```

---

## What Gets Synced (and What Doesn't)

### AUTO-SYNCED via git:

| Component | Path in Repo | Symlinked to ~/.claude/ |
|-----------|-------------|------------------------|
| Commands | `commands/` | `~/.claude/commands` |
| Agents | `agents/core/` | `~/.claude/agents` |
| Hooks | `hooks/` | `~/.claude/hooks` |
| Rules | `rules/` | `~/.claude/rules` |
| Skills | `skills/` | `~/.claude/skills` |
| Agent docs | `agent_docs/` | `~/.claude/agent_docs` |
| Settings | `config/settings.json` | `~/.claude/settings.json` |
| CLAUDE.md | `config/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| MCP config | `config/.mcp.json` | `~/.claude/.mcp.json` |
| Stack templates | `config/stacks/` | `~/.claude/config/stacks` |
| BMAD templates | `config/bmad/` | `~/.claude/config/bmad` |
| SDLC prompts | `config/prompts/` | `~/.claude/config/prompts` |
| MCP servers | `mcp-servers/` | `~/.claude/mcp-servers` |
| Scripts | `scripts/` | Used directly |
| Docs/brainstorms | `docs/` | Used directly |
| Darwin proposals | `~/.claude/darwin/` | NOT in git (local state) |

### NOT SYNCED (machine-specific):

| Component | Why | Handled by |
|-----------|-----|-----------|
| API keys (.env.local) | Security — shouldn't be in git | `sync-to-vps.sh` (manual, one-time) |
| OAuth tokens | Machine-specific browser auth | Manual login per machine |
| Learning DB (learnings.db) | SQLite — can't merge via git | Learning sync daemon (see below) |
| Telegram bot tokens | Different bots per machine | Machine-specific .env |
| gh auth tokens | Machine-specific | `gh auth login` per machine |
| Installed npm packages | OS-specific binaries | `npm install` per machine |

---

## Learning Ledger Sync (the hard one)

The learning SQLite DB can't be merged via git. Options:

### Option A: One-Way Promotion (recommended)
- Each machine records learnings locally
- `/consolidate` promotes cross-repo learnings to `CLAUDE.md`
- `CLAUDE.md` IS in git → syncs automatically
- Result: important learnings flow to all machines, trivial ones stay local

### Option B: API-Based Sync
- Learning MCP server exposes a `/sync` endpoint
- Mac and VPS exchange learnings via HTTP
- Conflict resolution: last-write-wins with fingerprint dedup
- More complex but keeps full history on both machines

### Option C: Shared DB (PostgreSQL)
- Both machines point to the VPS PostgreSQL (already running for AgentOS)
- Learning server connects to `postgresql://vps:5432/learnings`
- True real-time sync
- Requires network access (Tailscale or open port)

**Recommendation:** Option A for now (simple, works today), Option C later when Tailscale is set up.

---

## Implementation: The Sync Daemon

### `scripts/config-sync-daemon.sh`
A single script that handles all sync directions, runs on BOTH machines.

```bash
#!/usr/bin/env bash
# Runs every 5 minutes via cron on both Mac and VPS
# Detects which machine it's on and acts accordingly

REPO_DIR="$HOME/.claude-super-setup"
# Fallback for Mac where the repo might be elsewhere
[ ! -d "$REPO_DIR" ] && REPO_DIR="$HOME/claude_super_setup"

IS_VPS=false
[ "$(uname)" != "Darwin" ] && IS_VPS=true

cd "$REPO_DIR" || exit 1

# Step 1: Pull latest changes
git pull -q 2>/dev/null

# Step 2: Check for local uncommitted changes
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  # Auto-commit local changes
  git add -A
  MACHINE=$(hostname -s)
  git commit -q -m "sync: auto-commit from $MACHINE $(date +%Y%m%d-%H%M)" 2>/dev/null
  git push -q 2>/dev/null
fi

# Step 3: If VPS, also notify running Claude session to reload
if $IS_VPS; then
  # Touch a sentinel file that the Claude session can watch
  touch "$HOME/.claude/.config-updated" 2>/dev/null
fi
```

### Cron Setup (both machines)

**Mac:**
```
*/5 * * * * /path/to/claude_super_setup/scripts/config-sync-daemon.sh >> ~/.claude/logs/sync.log 2>&1
```

**VPS:**
```
*/5 * * * * /home/claude/.claude-super-setup/scripts/config-sync-daemon.sh >> ~/.claude/logs/sync.log 2>&1
```

---

## Conflict Resolution

Since both machines can modify files, conflicts will happen. Strategy:

1. **Settings/config files:** Mac is the source of truth. VPS never modifies `config/settings.json` directly — only through the repo.
2. **Darwin proposals:** Darwin writes to `~/.claude/darwin/` (not in git), then creates GitHub issues. No conflict.
3. **AGENTS.md:** Both machines can update. Git handles merges. If conflict: accept both changes (append-only file).
4. **Commands/agents/hooks:** Only Mac creates new ones. VPS consumes via symlinks.
5. **Learnings:** Each machine has its own DB. Cross-pollination via CLAUDE.md promotion.

### Conflict Prevention Rules:
- VPS should NEVER directly edit files under `config/` — always edit via the repo
- New commands/agents are created on Mac, pushed, and auto-synced
- VPS can create files in `docs/`, `scripts/`, `agents/` — these flow back to Mac via auto-push
- `settings.json` changes should ONLY be made on Mac via `/update-config` skill

---

## Monitoring Sync Health

### Darwin Integration
Darwin already runs daily. Add a sync health check:

```bash
# In scripts/darwin/self-analyze.sh — add sync check
echo "=== Sync Health ==="
LOCAL_HASH=$(git -C $REPO_DIR rev-parse HEAD)
REMOTE_HASH=$(git -C $REPO_DIR ls-remote origin HEAD | cut -f1)
if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
  echo "SYNCED: local matches remote"
else
  echo "DRIFT: local=$LOCAL_HASH remote=$REMOTE_HASH"
fi
```

### Drift Detection
The existing `scripts/drift-detect.sh` already compares `~/.claude/` against the repo. Run it as part of Darwin's daily scan.

---

## Complete Sync Flow Diagram

```
┌─────── MAC ────────┐     ┌──── GITHUB ────┐     ┌────── VPS ──────┐
│                     │     │                 │     │                  │
│ You edit code       │     │                 │     │                  │
│      │              │     │                 │     │                  │
│      ▼              │     │                 │     │                  │
│ git commit+push ────┼────►│ repo updated    │     │                  │
│                     │     │       │         │     │                  │
│                     │     │       │ ◄───────┼─────┤ cron: git pull   │
│                     │     │       │         │     │ (every 5 min)    │
│                     │     │       ▼         │     │      │           │
│                     │     │                 │     │      ▼           │
│                     │     │                 │     │ symlinks resolve │
│                     │     │                 │     │ ~/.claude/ = new │
│                     │     │                 │     │                  │
│                     │     │                 │     │ AgentOS uses     │
│                     │     │                 │     │ same ~/.claude/  │
│                     │     │                 │     │ = also updated   │
│                     │     │                 │     │                  │
│                     │     │  ◄──────────────┼─────┤ VPS changes:     │
│                     │     │                 │     │ auto-commit+push │
│ session-start.sh    │     │                 │     │ (every 30 min)   │
│ git pull ◄──────────┼─────┤                 │     │                  │
│ = VPS changes land  │     │                 │     │                  │
└─────────────────────┘     └─────────────────┘     └──────────────────┘
```

---

## Implementation Priority

| Step | What | Effort | Impact |
|------|------|--------|--------|
| 1 | VPS cron: `git pull` every 5 min | 5 min | Mac→VPS sync (80% of the problem) |
| 2 | VPS cron: auto-commit+push every 30 min | 5 min | VPS→Mac sync |
| 3 | Mac session-start hook: `git pull` | 5 min | Catch VPS changes on session start |
| 4 | Mac post-push SSH trigger | 10 min | Instant Mac→VPS (no 5min delay) |
| 5 | Darwin sync health check | 10 min | Detect drift |
| 6 | Drift alerting via Telegram | 10 min | Know when sync breaks |
| 7 | Learning ledger promotion sync | 30 min | Cross-machine learnings via CLAUDE.md |

Total: ~1 hour for complete three-way auto-sync.

---

## Anti-Patterns

1. **Don't use rsync** — it overwrites without merge, loses changes
2. **Don't sync .env files via git** — security risk, use `sync-to-vps.sh` once
3. **Don't sync node_modules or .venv** — OS-specific, install per machine
4. **Don't edit config/settings.json on VPS directly** — edit in repo, let symlinks propagate
5. **Don't sync SQLite DBs via git** — binary files don't merge, use promotion
6. **Don't auto-push without checking for conflicts** — `git push` will fail on conflict, which is the safe behavior
