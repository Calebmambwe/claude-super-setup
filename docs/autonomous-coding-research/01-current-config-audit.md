# Current Claude Code Configuration Audit

**Date:** 2026-03-28
**Scope:** Complete audit of all settings, hooks, permissions, and MCP servers

---

## 1. Settings Files

### Global Settings (`~/.claude/settings.json`)

#### Environment Variables

| Variable | Value | Effect | Assessment |
|---|---|---|---|
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `"50"` | Forces context compaction at 50% | Best practice. Global CLAUDE.md says 50%, project says 65% — contradiction, but env var wins. |
| `CLAUDE_CODE_SUBAGENT_MODEL` | `"claude-sonnet-4-6"` | All subagents use Sonnet 4.6, never Opus | Cost saver but means no model escalation for complex subagent work. |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `"1"` | Enables experimental agent teams | Still experimental — may be unstable. |
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `"1"` | Enables telemetry | Standard. |
| `OTEL_METRICS_EXPORTER` | `"console"` | Exports metrics to stdout | Causes noise in Ghost Mode logs — triggers false budget-exhaustion detection. |
| `TASK_MAX_TOOL_CALLS` | `"1000"` | Budget guard limit | Set globally but NOT in project settings. Budget guard script is disabled anyway. |

#### Permissions — Critical Issues

**Allow list is extremely broad:**
- `Bash(sudo *)` — sudo allowed with no confirmation
- `Bash(rm -r *)`, `Bash(rm -f *)` — recursive/force deletion allowed
- `Bash(curl *)` — curl to arbitrary URLs
- All major toolchains: git, npm/npx/pnpm/bun, python/uv/pip, cargo, go, make/cmake, docker, gh CLI

**Deny list gaps:**
- `Read(.env*)` blocks reads but NOT writes to .env
- `Bash(rm -rf *)` blocked but `Bash(rm -r *)` (without -f) is NOT blocked
- `Bash(curl * | sh)` blocked but `curl * | python3` or `curl > file && bash file` NOT blocked

**`skipDangerousModePermissionPrompt: true`** — disables ALL interactive permission confirmations. Required for automation but removes safety net for interactive sessions.

### Project Settings (`config/settings.json`)

Is a **superset** of global settings with additional hooks:
- `SessionStart`: rotate-audit-log.sh
- `UserPromptSubmit`: smart-route.sh (NLP intent detection)
- `PostToolUse`: auto-fix-loop.sh, command audit log, alert-check.sh, teach-me-detect.sh
- `Stop`: visual-verify-guard.sh
- `SubagentStop`: quality verification prompt
- Various lifecycle hooks: TaskCreated, TaskCompleted, WorktreeCreate, WorktreeRemove, TeammateIdle

**Missing `TASK_MAX_TOOL_CALLS`** — falls back to 200 (but budget guard is disabled).

---

## 2. CLAUDE.md Files

### Project CLAUDE.md (`config/CLAUDE.md`)

- 22 critical gotchas covering TypeScript, Next.js, shadcn/ui, Framer Motion, etc.
- Two-Correction Rule enforced
- Context7 MCP usage "non-negotiable"
- Three autonomy tiers documented
- References `@agent_docs/` files that may not exist in all projects (silent rule dropping)
- **Model strategy contradiction:** Says "opusplan" but no `model` key in settings.json

### Global CLAUDE.md (`~/.claude/CLAUDE.md`)

- Condensed version of project CLAUDE.md
- Same core rules present
- Baseline for ALL sessions everywhere

---

## 3. Hooks Inventory (34 hook scripts)

### HIGH SEVERITY Issues

1. **`budget-guard.sh` is disabled** (`.disabled` suffix on disk) but referenced in settings.json — budget guard NOT running
2. **`sandbox-router.sh` exists but NOT wired into hooks** — dangerous commands run directly on host
3. **Auto-pull on session start** — `session-start.sh` runs `git pull -q` silently, remote config changes take effect automatically

### MEDIUM SEVERITY Issues

4. **`auto-fix-loop.sh`** runs full builds after every code edit (5s debounce only) — 30-120s latency per edit on slow projects
5. **SDLC workflow prompt-hooks** have 45-second timeouts — can bypass gates under high latency
6. **Stop hook LLM verification** on every session end — 60s timeout, high token cost, can block autonomous sessions

### Hook Categories

| Category | Count | Risk Level |
|---|---|---|
| SessionStart | 2 | Low (auto-pull is medium) |
| UserPromptSubmit | 1 | Low |
| PreToolUse | 6 | Low-Medium |
| PostToolUse | 10 | Medium (auto-fix-loop, SDLC gates) |
| Stop | 3 | High (LLM verification blocks headless) |
| SubagentStop | 1 | Medium (token cost) |
| Other lifecycle | 6 | Low |
| Dead/unwired | 10 | N/A |

---

## 4. MCP Servers

- `knowledge-rag`: Python MCP for local docs RAG
- `stitch`: Project-only (npx proxy)
- Pre-approved: Telegram, Context7, GitHub (full CRUD including merge_pull_request), Memory, Learning, Sequential-thinking, Playwright, Sandbox

**GitHub MCP permissions are broad** — Claude can autonomously merge PRs and create repos.

---

## 5. Enabled Plugins

ralph-loop, pr-review-toolkit, hookify, skill-creator, playwright, supabase, telegram

---

## 6. Critical Summary

| Issue | Severity | Impact |
|---|---|---|
| Budget guard disabled but referenced | HIGH | No tool call limits enforced |
| Sandbox router not wired | HIGH | Code runs on host, not sandbox |
| Auto-pull on session start | HIGH | Silent config changes from remote |
| Stop hook blocks headless sessions | HIGH | Ghost mode can loop at stop gate |
| SDLC artifact hooks block autonomous flows | CRITICAL | Deadlocks auto-develop/ghost-run |
| OTEL noise triggers false budget kills | HIGH | Ghost mode terminated prematurely |
| sudo allowed without confirmation | MEDIUM | Security risk |
| Model strategy contradiction | MEDIUM | Inconsistent behavior |
| auto-fix-loop latency on slow projects | MEDIUM | Slows autonomous coding |
