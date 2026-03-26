# Local Model Recommendations — 2026

## Model Routing Strategy

Use local models for fast, cheap operations. Route to Claude for complex tasks.

```
User prompt → Classifier (local, fast)
  ├── Simple query → llama3.2:3b (instant, free)
  ├── Code generation → qwen2.5-coder:7b (local, free)
  ├── Code review → qwen2.5-coder:7b (local, free)
  ├── Complex task → Claude Sonnet (API, paid)
  └── Autonomous → Claude Code CLI (full power)
```

## Recommended Models by Task

### Code Generation
| Model | Quality | Speed (CPU) | Best For |
|-------|---------|-------------|----------|
| qwen2.5-coder:7b | Good | ~30-45s | TypeScript, Python, React components |
| deepseek-coder-v2:16b | Very Good | ~60-90s | Complex multi-file generation |
| Claude Sonnet | Excellent | ~3-5s (API) | Production code, architecture |

### Code Review / Bug Fixing
| Model | Quality | Speed (CPU) | Best For |
|-------|---------|-------------|----------|
| qwen2.5-coder:7b | Good | ~30s | Null checks, type errors, simple bugs |
| Claude Sonnet | Excellent | ~3s (API) | Security review, architecture issues |

### Quick Triage / Classification
| Model | Quality | Speed (CPU) | Best For |
|-------|---------|-------------|----------|
| llama3.2:3b | Adequate | ~15-25s | Classify task type, extract keywords |
| Claude Haiku | Good | ~1s (API) | Fast classification with better quality |

### Unit Test Writing
| Model | Quality | Speed (CPU) | Best For |
|-------|---------|-------------|----------|
| qwen2.5-coder:7b | Good | ~40s | Simple unit tests, happy path |
| Claude Sonnet | Excellent | ~5s (API) | Edge cases, integration tests |

## Cost Comparison

| Provider | Cost per 1M tokens | Speed | Quality |
|----------|-------------------|-------|---------|
| Ollama (local CPU) | $0 | Slow (15-90s) | Good |
| Ollama (local GPU) | $0 | Fast (1-5s) | Good |
| Claude Haiku | ~$0.25 | Very Fast | Good |
| Claude Sonnet | ~$3.00 | Fast | Excellent |
| Claude Opus | ~$15.00 | Fast | Best |

## When to Use Local Models

**Use Local (Ollama):**
- Offline development
- Budget-constrained projects
- Simple code generation (interfaces, types, boilerplate)
- First-pass code review
- Task classification / routing
- Bulk operations (processing 100+ items)
- Privacy-sensitive code

**Use Claude API:**
- Complex multi-step reasoning
- Architecture decisions
- Security-critical code review
- Full autonomous pipelines (/auto-dev)
- Production deployments
- Anything requiring tool use (MCP, file ops, shell)

## VPS-Specific Notes

- Our Hostinger VPS has **no GPU** — CPU-only inference
- 16GB RAM supports up to 7B models comfortably
- Running both AgentOS (Docker) + Ollama simultaneously uses ~8GB
- Consider stopping Ollama when not needed: `sudo systemctl stop ollama`
- For GPU inference, consider upgrading to a GPU VPS or using RunPod/Lambda
