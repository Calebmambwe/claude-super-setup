# Ollama Model Benchmarks

**Date:** 2026-03-26
**Environment:** Hostinger VPS, 4 vCPU, 16GB RAM, CPU-only (no GPU)
**Ollama version:** Latest stable

## Summary

| Model | Size | TypeScript Interface | Null Check Fix | Speed (tok/s) | Quality |
|-------|------|---------------------|----------------|---------------|---------|
| llama3.2:3b | 2.0 GB | 2.8s (34 tok) | 2.3s (32 tok) | ~12 tok/s | Good |
| qwen2.5-coder:7b | 4.7 GB | 8.7s (34 tok) | 15.2s (86 tok) | ~5 tok/s | Very Good |

## Detailed Results

### Task 1: Generate TypeScript Interface

**Prompt:** "Generate a TypeScript interface for User with id (number), name (string), email (string), createdAt (Date), roles (string[]). Code only."

**llama3.2:3b** — 2.8s eval, 20s wall (includes model load)
```typescript
interface User {
  id: number;
  name: string;
  email: string;
  createdAt: Date;
  roles: string[];
}
```
**Quality:** Perfect. Clean, minimal, exactly what was asked.

**qwen2.5-coder:7b** — 8.7s eval, 51s wall
```typescript
interface User {
    id: number;
    name: string;
    email: string;
    createdAt: Date;
    roles: string[];
}
```
**Quality:** Perfect. Identical output with 4-space indent.

### Task 2: Fix Null Check Bug

**Prompt:** "Fix this TypeScript function that crashes on null: function getLength(s: string) { return s.length; }. Handle null/undefined. Code only."

**llama3.2:3b** — 2.3s eval
```typescript
function getLength(s: string | undefined): number {
    return typeof s !== 'undefined' ? s.length : 0;
}
```
**Quality:** Good. Handles undefined but misses null. Uses typeof check.

**qwen2.5-coder:7b** — 15.2s eval
```typescript
function getLength(s: string | null | undefined): number {
  if (s === null || s === undefined) {
    return 0;
  }
  return s.length;
}
```
**Quality:** Very Good. Handles both null and undefined. Includes explanation.

## Performance Analysis

### Token Generation Speed (CPU)

| Model | Tokens/sec | First Token Latency | RAM Usage |
|-------|-----------|-------------------|-----------|
| llama3.2:3b | ~12 tok/s | ~15s (cold) / ~1s (warm) | ~2.5 GB |
| qwen2.5-coder:7b | ~5 tok/s | ~40s (cold) / ~3s (warm) | ~5.5 GB |

### Quality Assessment

| Metric | llama3.2:3b | qwen2.5-coder:7b |
|--------|------------|-------------------|
| Code correctness | 8/10 | 9/10 |
| Type safety | 7/10 | 9/10 |
| Edge case handling | 6/10 | 8/10 |
| Explanation quality | 5/10 | 8/10 |
| Following instructions | 8/10 | 7/10 (adds explanations when told "code only") |

### Recommendations

**llama3.2:3b** — Best for:
- Fast triage and classification
- Simple code generation (interfaces, types)
- When speed matters more than quality
- Low-RAM environments

**qwen2.5-coder:7b** — Best for:
- Code generation with proper types
- Bug fixing with null/undefined handling
- Code review (catches more edge cases)
- When quality matters more than speed

### CPU vs GPU Comparison (estimated)

| Setup | llama3.2:3b | qwen2.5-coder:7b |
|-------|------------|-------------------|
| CPU (our VPS) | ~12 tok/s | ~5 tok/s |
| RTX 3080 (est.) | ~80 tok/s | ~40 tok/s |
| M2 Pro (est.) | ~60 tok/s | ~30 tok/s |
| A100 (est.) | ~150 tok/s | ~80 tok/s |

## Conclusion

Local models are viable for budget/offline mode on CPU but ~10x slower than GPU. For our VPS:
- **llama3.2:3b**: Usable for simple tasks (2-5s response)
- **qwen2.5-coder:7b**: Usable but slow for complex tasks (15-50s response)
- **Claude API**: Still preferred for production (3-5s, much higher quality)

The sweet spot is using local models for **triage and classification** (decide which Claude model to route to) and **simple code generation** (types, interfaces, boilerplate).
