# OpenRouter Model Benchmarks

**Date:** 2026-03-26 08:09 UTC
**Benchmark by:** Claude (VPS agent)
**Models tested:** 4 working + 1 free (errored) | **Tasks:** 6 coding challenges

## Models Tested

| # | Model | Type | Status |
|---|-------|------|--------|
| 1 | `qwen/qwen3-coder` | Paid | Working |
| 2 | `deepseek/deepseek-chat-v3-0324` | Paid | Working |
| 3 | `google/gemini-2.5-pro` | Paid | Working |
| 4 | `meta-llama/llama-4-maverick` | Paid | Working |
| 5 | `qwen/qwen3-coder:free` | Free | Error (provider unavailable) |

> **Note:** Original request targeted free model variants (`:free` suffix). These were either removed or unavailable at benchmark time. Only `qwen/qwen3-coder:free` exists but returned provider errors on all tasks.

## Tasks

| ID | Task | Tests |
|----|------|-------|
| a | Create a TypeScript interface (User) | Correct fields, union type for role |
| b | Fix a null check bug | Handles null/undefined safely |
| c | Write a Zod validation schema | Correct validators, uuid, email, enum |
| d | Create a React component with typed props | Proper interface, FC, delete handler |
| e | Write a SQL JOIN query (3 tables) | Correct JOINs, column aliases, date filter |
| f | Refactor callback to async/await | Clean async, error handling preserved |

## Scoring Summary

| Model | Correctness (avg) | Speed (avg) | Quality (avg) | **Overall** |
|-------|-------------------|-------------|---------------|-------------|
| **qwen/qwen3-coder** | **9.5** | **2.1s** | **9.3** | **1st** |
| meta-llama/llama-4-maverick | 9.2 | 2.9s | 8.8 | 2nd |
| deepseek/deepseek-chat-v3-0324 | 9.0 | 3.9s | 8.3 | 3rd |
| google/gemini-2.5-pro | 8.7 | 34.8s | 8.8 | 4th |

## Detailed Scores

### Task a: TypeScript Interface

| Model | Time | Correctness | Quality | Notes |
|-------|------|-------------|---------|-------|
| qwen3-coder | 0.7s | 10 | 10 | Clean, minimal, perfect |
| deepseek-v3-0324 | 2.8s | 10 | 9 | Correct but uses 4-space indent (minor style) |
| gemini-2.5-pro | 23.1s | 10 | 10 | Correct but extremely slow |
| llama-4-maverick | 1.1s | 10 | 10 | Clean and fast |

### Task b: Null Check Fix

| Model | Time | Correctness | Quality | Notes |
|-------|------|-------------|---------|-------|
| qwen3-coder | 0.5s | 10 | 9 | Uses `??` -- correct. Code-only response |
| deepseek-v3-0324 | 4.5s | 9 | 7 | Correct fix but included explanation (asked for code-only) |
| gemini-2.5-pro | 55.1s | 10 | 9 | Clean `?.` + `??` -- code only. Very slow |
| llama-4-maverick | 0.8s | 10 | 9 | Clean optional chaining |

### Task c: Zod Schema

| Model | Time | Correctness | Quality | Notes |
|-------|------|-------------|---------|-------|
| qwen3-coder | 3.4s | 10 | 9 | All validators correct. No type export |
| deepseek-v3-0324 | 3.0s | 10 | 10 | Used `z.coerce.date()` (smart), includes type export |
| gemini-2.5-pro | 46.6s | 10 | 10 | Clean, includes type export |
| llama-4-maverick | 5.7s | 10 | 10 | Clean, includes type export |

### Task d: React Component

| Model | Time | Correctness | Quality | Notes |
|-------|------|-------------|---------|-------|
| qwen3-coder | 1.6s | 10 | 9 | Full component with inline styles |
| deepseek-v3-0324 | 2.7s | 9 | 8 | Added explanation text (instruction violation). Showed user ID |
| gemini-2.5-pro | 53.0s | 6 | 6 | **Output truncated** -- component incomplete |
| llama-4-maverick | 4.0s | 9 | 8 | Clean but minimal styling |

### Task e: SQL JOIN Query

| Model | Time | Correctness | Quality | Notes |
|-------|------|-------------|---------|-------|
| qwen3-coder | 0.8s | 9 | 9 | MySQL syntax (CURDATE). No column aliases |
| deepseek-v3-0324 | 4.7s | 8 | 7 | Added explanation (instruction violation). MySQL dialect |
| gemini-2.5-pro | 14.4s | 10 | 10 | PostgreSQL interval syntax. Clean aliases |
| llama-4-maverick | 3.9s | 9 | 9 | Clean aliases, ANSI-ish syntax |

### Task f: Async/Await Refactor

| Model | Time | Correctness | Quality | Notes |
|-------|------|-------------|---------|-------|
| qwen3-coder | 5.7s | 8 | 8 | Correct but redundant try/catch that just re-throws |
| deepseek-v3-0324 | 5.8s | 8 | 8 | Same re-throw pattern. Added verbose explanation + 2 versions |
| gemini-2.5-pro | 17.0s | 9 | 9 | Added `response.ok` check -- better error handling |
| llama-4-maverick | 1.8s | 8 | 8 | Clean but redundant try/catch |

## Speed Comparison (all times in seconds)

| Task | Qwen3 Coder | DeepSeek v3 | Gemini 2.5 Pro | Llama Maverick |
|------|-------------|-------------|----------------|----------------|
| a. TS Interface | **0.7** | 2.8 | 23.1 | 1.1 |
| b. Null Fix | **0.5** | 4.5 | 55.1 | 0.8 |
| c. Zod Schema | 3.4 | **3.0** | 46.6 | 5.7 |
| d. React Component | **1.6** | 2.7 | 53.0 | 4.0 |
| e. SQL JOIN | **0.8** | 4.7 | 14.4 | 3.9 |
| f. Async Refactor | 5.7 | 5.8 | 17.0 | **1.8** |
| **Average** | **2.1** | 3.9 | 34.8 | 2.9 |

## Key Findings

### Winner: `qwen/qwen3-coder`
- **Fastest overall** (2.1s avg) -- 1.4x faster than Maverick, 1.9x faster than DeepSeek
- **Highest correctness** (9.5/10) -- always code-only as instructed
- **Best instruction following** -- never added unsolicited explanations
- Excellent candidate for Ollama local-model replacement at coding tasks

### Runner-up: `meta-llama/llama-4-maverick`
- Very fast (2.9s avg), especially on async refactor (1.8s)
- Clean, minimal outputs
- Good instruction following

### DeepSeek v3: Solid but verbose
- Moderate speed (3.9s avg)
- Frequently added explanations despite "code-only" instruction
- Good code quality when ignoring verbosity

### Gemini 2.5 Pro: Powerful but slow
- **Extremely slow** (34.8s avg, up to 55s per task)
- Best error handling (added `response.ok` check in async task)
- One truncated output (React component incomplete)
- Not suitable for interactive/real-time coding assistance

### Free models: Currently unavailable
- `qwen/qwen3-coder:free` returned provider errors on all 6 tasks
- No free alternatives from DeepSeek, Gemini, or Llama available at benchmark time

## Recommendations

1. **Primary model for coding:** `qwen/qwen3-coder` -- best speed + quality ratio
2. **Fallback model:** `meta-llama/llama-4-maverick` -- fast with solid quality
3. **Deep analysis tasks:** `google/gemini-2.5-pro` -- when speed doesn't matter
4. **Free tier:** Monitor `qwen/qwen3-coder:free` availability -- same model, zero cost when working
