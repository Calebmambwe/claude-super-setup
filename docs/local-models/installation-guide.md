# Ollama Local Models — Installation Guide

## Prerequisites

- Linux (Ubuntu 22.04+), macOS, or Windows with WSL2
- Minimum 8GB RAM (16GB recommended for 7B models)
- 10GB+ free disk space per model

## Installation

### Linux / VPS

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

This installs Ollama as a systemd service. It auto-starts on boot.

### macOS

```bash
brew install ollama
# Or download from https://ollama.com/download
```

### Verify Installation

```bash
ollama --version
# Should output version number

ollama list
# Should show no models yet (empty table)
```

## Pull Models

### Recommended Models for Coding

```bash
# Fast triage / simple tasks (2GB, runs on any machine)
ollama pull llama3.2:3b

# Coding specialist (4.7GB, needs 8GB+ RAM)
ollama pull qwen2.5-coder:7b

# Heavy coding (10GB+, needs 16GB+ RAM — optional)
ollama pull deepseek-coder-v2:16b
```

### Verify Models

```bash
ollama list
# Should show pulled models with sizes

# Quick test
ollama run llama3.2:3b "Say hello"
```

## API Access

Ollama runs a REST API at `http://localhost:11434`:

```bash
# Generate completion
curl http://localhost:11434/api/generate \
  -d '{"model": "llama3.2:3b", "prompt": "Write hello world in Python", "stream": false}'

# Chat completion (OpenAI-compatible)
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:7b",
    "messages": [{"role": "user", "content": "Write a TypeScript interface for User"}]
  }'
```

## Integration with AgentOS

Ollama is available as a local model fallback for:
- **Budget mode**: Use local models instead of Claude API
- **Offline mode**: No internet required
- **Fast triage**: Quick classification before routing to Claude
- **Code review**: Local model for initial code review pass

## Service Management

```bash
# Check status
systemctl status ollama

# Restart
sudo systemctl restart ollama

# View logs
journalctl -u ollama -f

# Stop (free RAM)
sudo systemctl stop ollama
```

## GPU Support

- **NVIDIA**: Ollama auto-detects CUDA GPUs (install nvidia-driver)
- **AMD**: ROCm support (Linux only)
- **Apple Silicon**: Metal acceleration (automatic on macOS)
- **CPU only**: Works but 5-10x slower than GPU

Our VPS runs CPU-only (no GPU). For production, consider a GPU-equipped instance.

## Memory Requirements

| Model | RAM (Idle) | RAM (Running) | Disk |
|-------|-----------|---------------|------|
| llama3.2:3b | ~200MB | ~2.5GB | 2.0GB |
| qwen2.5-coder:7b | ~200MB | ~5.5GB | 4.7GB |
| deepseek-coder-v2:16b | ~200MB | ~11GB | 9.2GB |

Rule of thumb: model file size * 1.2 = minimum RAM needed during inference.
