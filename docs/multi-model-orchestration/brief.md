# Feature Brief: Multi-Model Orchestration

**Created:** 2026-03-26
**Status:** Draft

---

## Problem

Our setup currently runs everything through Anthropic's Claude (Opus 4.6 as brain, Sonnet for subagents). This means:
- **Cost inefficiency** — simple tasks (linting suggestions, boilerplate generation, classification) use expensive Opus/Sonnet tokens when cheaper models would suffice.
- **No specialized models** — we can't leverage purpose-built models for voice-to-text, image generation, or embeddings within our pipelines.
- **Single point of failure** — if Anthropic is rate-limited or down, everything stops.
- **No quality comparison** — we can't A/B test two models on the same task to find which produces better output for specific task types.

---

## Proposed Solution

Build a **multi-model orchestration layer** integrated directly into our Claude Code skills and hooks. Opus 4.6 remains the brain and orchestrator — it decides which supplementary model to dispatch tasks to based on task type, complexity, and cost. The layer connects to OpenRouter (100+ models), Ollama (local), and specialized APIs (Whisper for voice, Gemini for image gen).

Key mechanisms:
- **Task classifier** — Opus analyzes incoming work and routes subtasks to the optimal model
- **Dual-model mode** — run the same task on two models, Opus auto-judges which output is better
- **Specialized model registry** — maps capabilities (voice-to-text, code generation, embeddings) to best-in-class models
- **Fallback chain** — Anthropic -> OpenRouter -> Ollama, automatic failover

---

## Target Users

**Primary:** Caleb + Claude agents — our entire dev pipeline (auto-dev, ghost mode, manual workflows)

**Secondary:** Apps we build — shipping features that use OpenRouter models for voice, image, AI chat, etc.

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Technical | Must integrate into existing Claude Code skills/hooks — not a separate service |
| Architecture | Opus 4.6 is ALWAYS the brain/orchestrator. Other models are workers only. Never replace Opus for planning, judgment, or orchestration |
| Budget | No monthly cap on OpenRouter spend — optimize for quality, not cost-cutting |
| Integration | Must work with existing model-routing.json config, auto-dev pipeline, ghost mode, and Telegram dispatch |

---

## Scope

### In Scope
- OpenRouter API integration as a skill/utility callable from any pipeline
- Task-type routing: coding -> qwen3-coder, analysis -> gemini, general -> deepseek, triage -> free models
- Dual-model comparison mode with Claude as auto-judge
- Specialized model support: voice-to-text (Whisper), image generation (Gemini/DALL-E), embeddings
- Model registry in config/model-routing.json with benchmarks and routing rules
- Cost tracking and logging per model per task
- Automatic fallback chain: Anthropic -> OpenRouter -> Ollama
- Reusable for apps we build (shared OpenRouter client module)

### Out of Scope
- Fine-tuning or training custom models
- Building a model marketplace UI
- Replacing Opus 4.6 for ANY orchestration/planning task
- Self-hosted model inference (beyond Ollama)
- Multi-tenant model routing (this is for our setup only)

---

## Feature Name

**Kebab-case identifier:** `multi-model-orchestration`

**Folder:** `docs/multi-model-orchestration/`

---

## Notes

- Benchmark data already collected: see `docs/local-models/openrouter-benchmarks.md`
- OpenRouter API key stored in `~/.claude/.env.local`
- model-routing.json already has OpenRouter provider with benchmark scores
- qwen/qwen3-coder won coding benchmarks (9.5 correctness, 2.1s avg)
- Free models currently unreliable — design should handle graceful degradation
- Dual-model mode should be opt-in per task (e.g., `--dual` flag or config toggle)

---

## PR/FAQ: Multi-Model Orchestration

### Press Release

**LUSAKA, March 2026** — Today we're shipping Multi-Model Orchestration, a new capability in our Claude Code setup that lets Claude's Opus 4.6 brain dispatch subtasks to the best model for the job. Starting immediately, our dev pipeline can route coding tasks to Qwen3 Coder (2x cheaper, equally correct), voice transcription to Whisper, and image generation to Gemini — while Opus stays in the driver's seat for all planning and judgment calls.

Every day, our pipeline processes dozens of tasks — from generating boilerplate code to analyzing architecture to transcribing voice briefs. Today, every single one of those tasks runs through the same expensive, general-purpose model. A simple TypeScript interface generation costs the same tokens as a complex architecture review. Meanwhile, purpose-built coding models like Qwen3 Coder score 9.5/10 on coding tasks at a fraction of the cost and 16x faster than Gemini.

"I wanted to use the best model for each job without manually switching between APIs," said Caleb, the platform operator. "Now Opus decides automatically — it sends coding to Qwen, analysis to Gemini, and keeps the hard thinking for itself. And when I'm not sure which model is better for a new task type, dual-model mode runs both and picks the winner."

The system works by extending our existing model-routing.json configuration. When a task enters the pipeline, Opus classifies it by type (coding, analysis, triage, voice, image) and dispatches it to the optimal model via OpenRouter's unified API. For high-stakes tasks, dual-model mode runs two models in parallel and Opus judges which output is better — building an evolving knowledge base of which models excel at what.

Unlike switching to a different AI platform, this keeps Opus 4.6 as the undisputed brain. Other models are workers — they execute, they don't decide. This means we get cost savings and specialized capabilities without sacrificing the reasoning quality that makes our autonomous pipelines reliable.

To get started, use the existing pipeline commands. Model routing happens automatically based on `config/model-routing.json`. For dual-model comparison, add `--dual` to any build task.

### Frequently Asked Questions

**Customer FAQs:**

**Q: Who is this for?**
A: Our own dev pipeline (Caleb + Claude agents) and apps we build that need AI capabilities like voice-to-text or image generation.

**Q: How is this different from just using OpenRouter directly?**
A: Direct OpenRouter usage requires manual model selection. This system auto-routes based on task type, benchmarks, and cost — with Opus as the intelligent dispatcher. Plus dual-model comparison builds institutional knowledge about model strengths.

**Q: What does it cost?**
A: OpenRouter charges per token — qwen3-coder is ~$0.00012/1K input tokens. No monthly cap. The cost optimization comes from routing cheap tasks to cheap models instead of using Opus for everything.

**Q: What if a model produces bad output?**
A: Opus is always the judge. If a worker model's output fails quality checks, Opus can retry with a different model or handle it directly. The fallback chain ensures nothing gets stuck.

**Q: When will it be available?**
A: OpenRouter integration and routing config are already in place. Full skill integration and dual-model mode target 1-2 sprints.

**Internal/Technical FAQs:**

**Q: How long will this take to build?**
A: 3 milestones — M1: OpenRouter client skill + routing (1 sprint), M2: Dual-model mode + auto-judge (1 sprint), M3: Specialized models — voice, image, embeddings (1 sprint).

**Q: What are the biggest risks?**
A: 1) OpenRouter reliability — free models are flaky, paid models occasionally slow. 2) Auto-judge accuracy — Opus needs to reliably pick the better output. 3) Latency — dual-model mode doubles API calls.

**Q: What are we NOT building?**
A: No fine-tuning, no custom model training, no model marketplace UI, no replacing Opus as the brain.

**Q: How will we measure success?**
A: 1) Cost per task decreases 30%+ for routine coding tasks. 2) Dual-model mode picks the objectively better output >80% of the time. 3) Zero pipeline failures from model routing (fallback chain works).

**Q: What's the rollback plan?**
A: model-routing.json has an `enabled` flag per provider. Set `openrouter.enabled: false` to instantly revert to Anthropic-only routing. No code changes needed.
