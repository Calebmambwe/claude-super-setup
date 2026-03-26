---
name: compare
description: "Run the same task on two models and let Opus pick the winner"
type: command
user_facing: true
telegram_tier: SAFE
---

# /compare — Dual-Model Comparison

Run the same coding task on two models in parallel. Opus judges which output is better.

## Usage

```
/compare <task description>
/compare --models qwen/qwen3-coder,deepseek/deepseek-chat-v3-0324 <task>
/compare --no-judge <task>   # Show both outputs without judging
```

## Process

1. Parse the user's task description from `$ARGUMENTS`
2. Read `config/model-routing.json` for `dual_mode.default_models` (default: `openrouter:code` vs `openrouter:general`)
3. Call `scripts/dual-compare.sh` with the task:

```bash
bash scripts/dual-compare.sh \
  --prompt "$ARGUMENTS" \
  --task-type implementation \
  --models "${MODELS:-}"
```

4. Display the result:
   - Which model won and why
   - The winning output
   - Latency comparison

5. Mention that the comparison was logged to `~/.claude/logs/comparisons.jsonl`

## Flags

- `--models M1,M2` — Override which two models to compare (full OpenRouter model IDs)
- `--no-judge` — Show both raw outputs side by side without Opus judging
- `--task-type <type>` — Override task type for routing (default: implementation)

## Example Output

```
Comparison: qwen/qwen3-coder vs deepseek/deepseek-chat-v3-0324

WINNER: qwen/qwen3-coder (Model A)
REASON: Output A correctly uses optional chaining and is code-only as requested

Latency: A=2.1s | B=3.9s
Logged to: ~/.claude/logs/comparisons.jsonl

--- Winning Output ---
<code output here>
```

## Rules

- Always show which model won and the reason
- Always show latency for both models
- If `--no-judge` is used, show both outputs with clear labels
- This command costs 2 API calls + 1 judge call (~$0.01 total)
