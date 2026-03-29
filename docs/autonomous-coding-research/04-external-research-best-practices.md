# External Research: Autonomous AI Coding Best Practices

**Date:** 2026-03-28
**Sources:** Manus.ai, Devin, Windsurf, Aider, OpenHands, SWE-Agent, Claude Code official docs

---

## 1. Manus.ai: Why It Produces Fully Working Systems

### The 3-Agent Model

| Role | Model Tier | Responsibility |
|------|-----------|----------------|
| Planner | Expensive reasoning | Decomposes task into subtasks with I/O contracts |
| Executor | Cheap/fast workhorse | Sequential tool execution, exception handling |
| Verifier | Fresh-context adversarial | Checks output quality without confirmation bias |

**Key insight:** The Verifier has NOT participated in generation, so it has no motivated reasoning to approve bad output.

### todo.md Attention Anchoring
- Tasks average 50 tool calls
- Agent recites and updates a todo.md checklist throughout
- Counteracts "lost in the middle" transformer attention degradation
- Task spec stays at top and bottom of context (highest attention positions)

### File-system as Unlimited Memory
- Filesystem IS the memory
- Compress observations into files, keep references
- Selectively rehydrate what's needed
- Tasks survive context overflow without losing state

### KV-cache Discipline
- Stable prompt prefixes throughout execution
- Unstable prefixes = cache misses = expensive + slow

---

## 2. Competing Tools Comparison

| Tool | Reliability Pattern | Key Differentiator |
|------|--------------------|--------------------|
| **Manus** | Planner/Executor/Verifier + todo.md | Verifier is fresh-context adversarial |
| **Devin 2.2** | Planner/Coder/Critic + file impact map | Human approves file changes before writes |
| **Windsurf** | Fast Context + dual-layer planning + auto-Memories | Learns patterns over 48h |
| **Aider** | Architect/Editor split + edit-time linting | 14x cheaper hybrid (R1 + Sonnet) |
| **OpenHands** | Auto context compression + SecurityAnalyzer | Automatic condenser, not manual |
| **SWE-Agent** | Integrated linter at edit time | Cannot submit syntactically invalid edits |
| **Continue.dev** | Source-controlled AI checks in CI | Quality gates checked into git |

### Universal Pattern
ALL reliable tools separate reasoning from execution. The model that generates code CANNOT also be the model that approves code.

---

## 3. Claude Code Best Practices (Verified March 2026)

### CLAUDE.md Rules
- **Hard limit: 200 lines / ~1,800 tokens**
- Beyond this, content is truncated and rules are lost
- Place critical rules at TOP and briefly repeat at END
- Use `@path/to/file` imports for domain knowledge
- Move domain-specific content to Skills (load on demand)
- Convert frequently-ignored rules to hooks (deterministic enforcement)

### Context Window Degradation Curve

| Context Fill | Quality State |
|-------------|---------------|
| 0-40% | Full quality |
| 40-50% | Degradation begins |
| ~48% | Opus 4.6 1M self-recommends restart |
| 65% | Losing nuance in compacted regions |
| 75% | Noticeably worse: re-reads files, contradicts decisions |

**Critical rule: One context window = one task.**

### Model Selection Matrix

| Scenario | Config |
|----------|--------|
| Default tasks | `model: "sonnet"` |
| Autonomous multi-step | `model: "opusplan"` (Opus plans, Sonnet executes) |
| Complex architecture | `model: "opus"` or `opus[1m]` |
| Background exploration | `CLAUDE_CODE_SUBAGENT_MODEL=haiku` |
| Hard debugging | Add "ultrathink" or `/effort high` |

**opusplan is the practical optimum:** 68% cost reduction vs all-Opus while maintaining architectural quality.

### Hooks for Autonomous Sessions
1. Never `permissionDecision: "ask"` in headless — blocks forever
2. `async: true` on logging hooks — prevents blocking
3. Stop hook: always check `stop_hook_active` — prevents infinite loop
4. Keep hooks under 5 seconds
5. Known bug (GitHub #6305): PreToolUse/PostToolUse intermittently not firing

### Headless Mode (-p) Specifics
- 3 consecutive classifier denials OR 20 total denials = session terminates
- `--allowedTools` scopes what Claude can do
- `--output-format stream-json` for parseable output
- `--permission-mode auto` for classifier-based approval
- `--bare` skips hooks/MCP/CLAUDE.md/skills — faster, for scripting

---

## 4. Key Principles for Reliability

### Context Management (Priority Order)
1. One task per context window
2. Compact at 60% proactively
3. Subagents for investigation (isolated context)
4. todo.md / checkpoint files for long tasks
5. `/btw` for side questions (never enters history)
6. Stable prompt prefixes for KV-cache

### Hallucination Prevention (Priority Order)
1. Context7 integration (never guess APIs)
2. Edit-time linting / PostToolUse typecheck hook
3. Preserve failure evidence in context
4. Verifier agent / fresh-context review
5. Scope investigation narrowly

### Output Verification (Priority Order)
1. Run tests after implementation
2. Separate reviewer session (Writer/Reviewer pattern)
3. PostToolUse hooks running tsc/linter after edits
4. Stop hooks running test suite before declaring done
5. Screenshot comparison for UI changes

---

## 5. Common Failure Modes

### Failure Mode 1: Context Rot
- Onset at 40-50% fill, not 100%
- Fix: compact at 60%, subagents for research, one-task-per-context

### Failure Mode 2: Rule Dilution in Long System Prompts
- Middle of 300+ line file is functionally ignored
- Fix: cut to under 200 lines, convert to hooks, use @imports

### Failure Mode 3: Hook Interference in Headless
- `permissionDecision: "ask"` blocks forever in -p mode
- Slow synchronous hooks stall reasoning
- Fix: always "allow" or "deny" in auto-answer hooks

### Failure Mode 4: Model Switching Quality Gaps
- opusplan: excellent plan, mediocre execution when Sonnet misinterprets
- Fix: include explicit implementation constraints in plan step

### Failure Mode 5: Budget Exhaustion ($40 phantom error)
- Agent loops 47 iterations on phantom error in test fixture
- Fix: 200 tool call cap, 20 subagent cap, graceful abandonment

### Failure Mode 6: Hallucinated API Signatures
- Fix: Context7 before every library usage, edit-time linting

### Failure Mode 7: State Divergence
- Agent proceeds as if write succeeded when it didn't
- Fix: post-action assertions, checkpoint-based decomposition

---

## 6. Official Documentation Key Points

### CLAUDE.md Official Guidance
- 200 line hard limit
- Loaded as user message (advisory, not enforced)
- Survives /compact (re-read from disk)
- Use `.claude/rules/` with path-scoping for context savings
- HTML comments stripped (zero-token notes)

### settings.json Key Discovery
- **`skipDangerousModePermissionPrompt` does not exist as a settings key**
- Correct approach: `permissions.disableBypassPermissionsMode: "disable"` or CLI flag
- Add `$schema` for autocomplete: `"$schema": "https://json.schemastore.org/claude-code-settings.json"`

### Agent Teams Official Guidance
- 3-5 teammates optimal
- Each teammate must own distinct files
- Token usage scales linearly
- File conflict = overwrite (no merge)
- Use `TeammateIdle` and `TaskCompleted` hooks for quality gates

### Startup Token Budget
- System prompt: ~4,200 tokens
- Auto memory: ~680
- Environment info: ~280
- MCP tools: ~120
- Global CLAUDE.md: ~320
- Project CLAUDE.md: ~1,800
- **Total startup: ~7,400 tokens**

---

## Sources

- [Official Best Practices](https://code.claude.com/docs/en/best-practices)
- [Official Model Config](https://code.claude.com/docs/en/model-config)
- [Official Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Official Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Official Context Window](https://code.claude.com/docs/en/context-window)
- [Official CLI Reference](https://code.claude.com/docs/en/cli-reference)
- [Manus AI Architecture (arXiv 2505.02024)](https://arxiv.org/html/2505.02024v1)
- [Devin 2025 Performance Review](https://cognition.ai/blog/devin-annual-performance-review-2025)
- [Aider Architect Mode](https://aider.chat/2024/09/26/architect.html)
- [OpenHands CodeAct 2.1](https://openhands.dev/blog/openhands-codeact-21-an-open-state-of-the-art-software-development-agent)
- [Claude Code GitHub Issue #6305](https://github.com/anthropics/claude-code/issues/6305)
- [Claude Code GitHub Issue #34685](https://github.com/anthropics/claude-code/issues/34685)
