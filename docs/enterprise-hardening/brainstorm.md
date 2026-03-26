# Enterprise Hardening Brainstorm

**Date:** 2026-03-26
**Input:** System Audit + Enterprise Research + VPS Research (pending)
**Goal:** Make claude-super-setup enterprise-grade — reliable, observable, secure, testable

---

## The Gap: Where We Are vs Enterprise Grade

### What We Already Have (Strong)
- 100 commands, 72 agents, 19 hooks, 3 MCP servers
- Autonomous pipelines (auto-dev, ghost mode)
- Hook-based enforcement (pre-commit, branch guard, protect-files)
- Telegram dispatch with NLP routing and security validation
- Self-teaching agent (TeachMe) that fills knowledge gaps
- Marketplace integration (MCP search/install, agent/skill import)
- Learning system (ledger + auto-learn hook)

### What's Missing (Enterprise Gaps)

| Gap | Impact | Fix Complexity |
|-----|--------|---------------|
| 10/19 hooks lack set -euo pipefail | Silent failures in safety hooks | Low |
| 19+ Telegram commands silently blocked | Users think tasks are running but they're not | Low |
| No Python tests for MCP servers | Regression risk on every change | Medium |
| No path boundary in knowledge-rag | Security vulnerability | Low |
| settings.json/CLAUDE.md not protected | Agent can disable own safety | Low |
| 31 commands missing frontmatter | Undiscoverable in UI | Low-Medium |
| No structured observability (OTel) | Can't debug multi-agent chains | High |
| No token budget caps per task | Runaway cost risk | Medium |
| No checkpoint/replay for long tasks | Lost work on failure | High |
| No schema validation in CI | Invalid configs pass CI | Low |
| AGENTS.md over limit | Rule violation | Low |

---

## Brainstorm: Enterprise Hardening Initiatives

### Initiative 1: "Bulletproof Hooks" (P0, Low effort)

**Problem:** 10 hooks silently swallow errors. Safety hooks (protect-files, branch-guard) can fail without blocking.

**Solution:**
- Add `set -euo pipefail` to all 10 hooks
- Add `#!/usr/bin/env bash` consistently
- Add error output to stderr so Claude sees failure messages
- Test each hook with intentional failure scenarios

**Estimated:** 1-2 hours, 10 files

### Initiative 2: "Dispatch Parity" (P0, Low effort)

**Problem:** telegram-dispatch-runner.sh allowlist has 19 commands but dispatch doc promises 38+. Tasks silently fail.

**Solution:**
- Expand ALLOWED_COMMANDS in telegram-dispatch-runner.sh to match telegram-dispatch.md
- Add a validation test that cross-references dispatch doc vs runner allowlist
- Add error notification when a command is blocked (Telegram message instead of silent failure)

**Estimated:** 30 minutes, 2 files

### Initiative 3: "Security Hardening" (P0, Low effort)

**Problem:** knowledge-rag accepts any path. protect-files doesn't cover critical configs.

**Solution:**
- Add HOME boundary check in knowledge-rag-server.py knowledge_ingest
- Add settings.json, CLAUDE.md, catalog.json to protect-files.sh
- Add path traversal test to integration tests

**Estimated:** 1 hour, 3 files

### Initiative 4: "Three-Tier Testing" (P1, Medium effort)

**Problem:** Only 5 integration tests. No Python unit tests. No MCP server tests.

**Solution (inspired by OpenHands):**
- **Tier 1:** pytest unit tests for all 3 MCP servers + 3 Python scripts
  - learning-server: record/search round-trip
  - knowledge-rag: ingest/search round-trip
  - agent-converter: JSON -> MD conversion
  - mcp-registry-fetch: cache format validation
- **Tier 2:** Integration tests for command workflows
  - /mcp-search -> /mcp-install -> /mcp-list -> /mcp-remove flow
  - /knowledge-ingest -> /knowledge-search flow
- **Tier 3:** Add to CI pipeline
  - pytest in ci.yml
  - ruff check + mypy for Python files

**Estimated:** 3-4 hours, 10+ files

### Initiative 5: "Structured Observability" (P1, Medium effort)

**Problem:** No structured logging across agent chains. Can't debug multi-agent failures.

**Solution (inspired by AgentTrace + Manus):**
- Create hooks/telemetry-v2.sh with structured JSONL output
- Log: timestamp, agent_name, tool_name, duration_ms, token_count, success/failure
- Write to ~/.claude/logs/telemetry.jsonl
- Create /observability command that parses and summarizes telemetry
- Add to /dashboard output

**Estimated:** 2-3 hours, 4 files

### Initiative 6: "Token Budget Caps" (P1, Medium effort)

**Problem:** No hard limits on task token usage. Runaway risk ($40 incident from research).

**Solution:**
- Add TASK_TOKEN_BUDGET env var (default: 200K)
- Add TASK_MAX_ITERATIONS env var (default: 50)
- Create hooks/budget-guard.sh that tracks cumulative tokens per task
- Block execution when budget exceeded with clear message
- Add to /auto-build and /auto-build-all pipelines

**Estimated:** 2 hours, 3 files

### Initiative 7: "Command Frontmatter Completion" (P1, Low effort)

**Problem:** 31 commands missing YAML frontmatter. Undiscoverable in Claude Code UI.

**Solution:**
- Script to scan all commands and add missing frontmatter
- Derive name from filename, description from first paragraph
- Add frontmatter validation to CI

**Estimated:** 1 hour, 31 files (scripted)

### Initiative 8: "AGENTS.md Consolidation" (P2, Low effort)

**Problem:** 166 lines, violates own 100-line rule.

**Solution:**
- Merge related entries (Telegram section: 5 entries -> 2)
- Merge marketplace entries (8 entries -> 3)
- Move detailed gotchas to dedicated docs
- Target: under 80 lines

**Estimated:** 30 minutes, 1 file

---

## Priority Execution Plan

### Wave 1 (P0 — do first, <2 hours)
1. Bulletproof hooks (10 files)
2. Dispatch parity (2 files)
3. Security hardening (3 files)

### Wave 2 (P1 — do next, 4-6 hours)
4. Three-tier testing (10+ files)
5. Command frontmatter completion (31 files, scripted)
6. Token budget caps (3 files)

### Wave 3 (P1-P2 — polish)
7. Structured observability (4 files)
8. AGENTS.md consolidation (1 file)
9. CI pipeline enhancements (1-2 files)

---

## VPS Collaboration Plan

Mac handles: Waves 1-2 (hooks, dispatch, security, testing)
VPS handles: Wave 3 (observability, AGENTS.md, CI) + its own research findings

Both push to feat/lobehub-marketplace-integration branch.
Final merge after all waves complete.

---

*Generated from: system-audit.md + enterprise-research.md*
*Patterns adopted from: Manus (failure evidence), OpenHands (three-tier testing), SWE-Agent (edit-time validation), Claude Code (hook governance)*
