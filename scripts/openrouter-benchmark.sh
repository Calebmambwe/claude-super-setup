#!/usr/bin/env bash
# OpenRouter Model Benchmark Script
set -euo pipefail

API_KEY="${OPENROUTER_API_KEY:?Set OPENROUTER_API_KEY env var}"
API_URL="https://openrouter.ai/api/v1/chat/completions"
RESULTS_DIR="/home/claude/docs/local-models"
TMP_DIR="/tmp/benchmark-run-$$"
mkdir -p "$TMP_DIR" "$RESULTS_DIR"

# Corrected model IDs (verified against OpenRouter /models API)
MODELS=(
  "qwen/qwen3-coder"
  "deepseek/deepseek-chat-v3-0324"
  "google/gemini-2.5-pro"
  "meta-llama/llama-4-maverick"
  "qwen/qwen3-coder:free"
)

MODEL_TYPES=("Paid" "Paid" "Paid" "Paid" "Free")

TASK_IDS=("a" "b" "c" "d" "e" "f")
TASK_LABELS=("TypeScript Interface" "Null Check Fix" "Zod Schema" "React Component" "SQL JOIN Query" "Async/Await Refactor")

PROMPTS=(
  "Create a TypeScript interface for a User with id (string), email (string), name (string), role (admin | user | viewer), createdAt (Date). Return ONLY the TypeScript code, no explanation."
  "Fix the null check bug in this TypeScript function. Return ONLY the fixed code:\n\nfunction getUserName(user: { name?: string | null }): string {\n  return user.name.trim().toLowerCase();\n}"
  "Write a Zod validation schema for a User object with: id (uuid string), email (valid email string), name (min 1 char, max 100 chars), role (enum: admin, user, viewer), createdAt (date). Return ONLY the TypeScript code with Zod imports."
  "Create a React functional component called UserCard that accepts typed props: user (with id string, name string, email string, role string) and onDelete callback. Show user info and a delete button. Return ONLY the TypeScript React code."
  "Write a SQL query that JOINs a users table with an orders table (on users.id = orders.user_id) and a products table (on orders.product_id = products.id). Select user name, order date, product name, and quantity. Filter for orders in the last 30 days. Return ONLY the SQL."
  "Refactor this callback-based function to use async/await. Return ONLY the refactored TypeScript code:\n\nfunction fetchUserData(userId: string, callback: (err: Error | null, data?: any) => void) {\n  fetch('/api/users/' + userId)\n    .then(res => res.json())\n    .then(data => callback(null, data))\n    .catch(err => callback(err));\n}"
)

call_model() {
  local model="$1"
  local prompt="$2"
  local time_file="$3"
  local output_file="$4"

  local start_ns end_ns elapsed_ms response content

  start_ns=$(date +%s%N)
  response=$(curl -s --max-time 120 "$API_URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -H "HTTP-Referer: https://github.com/Calebmambwe" \
    -d "$(jq -n --arg model "$model" --arg prompt "$prompt" '{
      model: $model,
      messages: [{role: "user", content: $prompt}],
      max_tokens: 2048,
      temperature: 0.2
    }')" 2>/dev/null || echo '{"error":"timeout or network error"}')
  end_ns=$(date +%s%N)

  elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
  content=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)

  if [ -z "$content" ]; then
    content="ERROR: $(echo "$response" | jq -r '.error.message // .error // "unknown error"' 2>/dev/null)"
  fi

  echo "$elapsed_ms" > "$time_file"
  printf '%s' "$content" > "$output_file"
}

echo "=== OpenRouter Model Benchmark ==="
echo "Date: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Models: ${#MODELS[@]} | Tasks: ${#TASK_IDS[@]}"
echo ""

for mi in "${!MODELS[@]}"; do
  model="${MODELS[$mi]}"
  echo "--- [$((mi+1))/${#MODELS[@]}] $model ---"

  for ti in "${!TASK_IDS[@]}"; do
    task_label="${TASK_LABELS[$ti]}"
    prompt="${PROMPTS[$ti]}"
    time_file="$TMP_DIR/m${mi}_t${ti}.time"
    output_file="$TMP_DIR/m${mi}_t${ti}.out"

    printf "  [%s] %s ... " "${TASK_IDS[$ti]}" "$task_label"
    call_model "$model" "$prompt" "$time_file" "$output_file"

    ms=$(cat "$time_file")
    secs=$(echo "scale=1; $ms / 1000" | bc)
    lines=$(wc -l < "$output_file")
    printf "%ss (%s lines)\n" "$secs" "$lines"
  done
  echo ""
done

echo "=== All benchmarks complete. Building report... ==="
