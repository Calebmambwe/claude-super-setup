# Enterprise Agent Framework Research

**Date:** 2026-03-26
**Researcher:** Enterprise Research Agent (Opus)
**Sources:** 25+ (Manus, Devin, OpenHands, SWE-Agent, Aider, Claude Code)

## Key Patterns to Adopt (Priority Order)

### 1. Three-Tier Testing (from OpenHands)
- **Tier 1 (every commit):** Mocked LLM calls testing core logic — near-zero cost
- **Tier 2 (daily):** Real LLM integration tests — $0.50-$3/run
- **Tier 3 (on-demand):** Benchmark evaluation — capability regression

### 2. Preserve Failure Evidence (from Manus)
- Never remove failed actions from context
- Error traces are the agent's learning signal
- Manus's #1 reliability mechanism

### 3. Edit-Time Validation Gates (from SWE-Agent)
- Validate at moment of action, not after
- Inline linter blocks invalid edits
- Prevents compounding failures from single bad edit

### 4. Deterministic Replay (from OpenHands)
- Event-sourced, append-only state
- Interrupted sessions resume by replaying events
- Gives checkpointing, stuck detection, and session resume for free

### 5. OTel Three-Surface Observability (from AgentTrace)
- Operational: what happened (tool calls, timing)
- Cognitive: why it happened (reasoning, confidence)
- Contextual: surrounding state (files, context window)
- JSONL for local debugging + OTel spans for distributed tracing

### 6. MCP Four-Layer Security
- Layer 1: Sandboxing (Docker/Firecracker, default-deny network)
- Layer 2: OAuth 2.1 authorization
- Layer 3: Tool integrity signing + version pinning
- Layer 4: Audit trail monitoring

### 7. Token Budget Caps
- Hard limit per task (200K tokens suggested)
- Iteration count limit per task
- Model tiering (expensive for planning, cheap for execution)

### 8. Schema-Driven Inter-Agent Boundaries
- Typed Pydantic schemas at every agent-to-agent boundary
- Fail immediately on schema violations
- Never pass natural language between agents that need reliability

## Platform Comparison

| Dimension | Manus | Devin | OpenHands | SWE-agent | Aider | Claude Code |
|---|---|---|---|---|---|---|
| Error recovery | Preserve failure evidence | Fresh-start protocol | Deterministic replay | Edit-time linting | Whole-file fallback | Hook-based gates |
| Testing | Not public | Human-reviewed | Three-tier (best) | SWE-bench | Manual | Hook-based CI |
| Security | Sandboxed VMs | Least-privilege | SecurityAnalyzer + Docker | Linux container | Git undo | OS-level sandbox |
| Context mgmt | KV-cache + filesystem | Sliding window | Event-sourced | Summarizer | AST repo map | Token budget hooks |

## Key Stats
- Devin PR merge rate: 34% -> 67% (2025) — even best agents fail 1/3 of the time
- 89% of production teams have observability; only 52% have evaluations
- 53% of MCP servers use hard-coded credentials (Astrix Security 2025)
- Claude Code avg cost: $6/dev/day (90% below $12/day)
- Agent spent $40 across 47 iterations hunting phantom error — budget caps are non-negotiable
