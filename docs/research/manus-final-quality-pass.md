# Manus.ai — Final Quality Pass & Hardening Guide

**Date:** 2026-03-24
**Source:** Manus API task RBCjcZKwdq5ptrhP3QybCm (41 credits)

---

## Top 5 Integration Tests

| Test | What It Validates |
|------|------------------|
| **Context Degradation** | Inject fact at turn 2, recall at turn 48. Tests attention over 50K+ tokens. |
| **Tool Failure Recovery** | Mock 503/429 errors. Agent must retry, backoff, or pivot — never crash. |
| **Multi-Agent Handoff** | Two agents pass state. Verify payload completeness, no redundant work. |
| **Prompt Injection** | Submit injection vectors. Infrastructure-level guardrails must block, not the prompt. |
| **Concurrent Race Conditions** | 50 simultaneous sessions. Watch for deadlocks, duplicated executions, corrupted state. |

## #1 Mistake: Context Rot

Treating the context window as a dumping ground. Three failures:
1. Latency spikes from bloated context
2. Quadratic cost scaling
3. Degraded reasoning → infinite loops, hallucinations

**Fix:** JIT context injection — expose only 3-5 relevant tools per task, prune history actively.

## 30-Day Hardening Roadmap

| Week | Focus | Key Actions |
|------|-------|-------------|
| 1 | Observability | Distributed tracing, token tracking per session, PII masking in logs |
| 2 | Security | Code-based guardrails (not prompt-based), session taint tracking, injection test fixes |
| 3 | Cost/Latency | Prompt caching for static elements, semantic routing (Haiku for simple, Opus for complex) |
| 4 | Chaos Engineering | Concurrent stress tests, API outage simulation, Red Team exercise |

## Monitoring Alerts

- **Infinite Loop:** >15 sequential tool calls without final response
- **Cost Anomaly:** Single session exceeds budget threshold
- **Tool Error Rate:** >10% failures in 5-minute window

## Cost Optimization (Beyond Sprint 4)

1. **Semantic Caching:** Redis + embeddings for repeated requests → zero cost on cache hits
2. **Prompt Caching:** Static prefix (system prompt, tools) at top → Anthropic caches 90%+ of input
3. **Smart Model Routing:** Haiku for formatting/classification, Opus only for reasoning
4. **Schema Shrinking:** Task-specific tool schemas instead of full API specs
