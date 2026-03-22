#!/usr/bin/env bash
# deps-check-local.sh — Local dependency audit with optional AI analysis
# Usage: ./deps-check-local.sh [--ai]
#   --ai  Use Claude CLI to analyze results (requires ANTHROPIC_API_KEY)

set -euo pipefail

USE_AI="${1:-}"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_DIR="/tmp/deps-check-${TIMESTAMP}"
mkdir -p "$REPORT_DIR"

echo "Dependency Health Check"
echo "======================"
echo ""

# ── Detect package manager ──────────────────────────────────────────

if [ -f "pnpm-lock.yaml" ]; then
  PM="pnpm"
elif [ -f "package-lock.json" ]; then
  PM="npm"
elif [ -f "yarn.lock" ]; then
  PM="yarn"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  PM="pip"
else
  echo "ERROR: No lockfile found. Run from a project root."
  exit 1
fi

echo "Package manager: $PM"
echo ""

# ── Run audit ───────────────────────────────────────────────────────

echo "Running security audit..."
if [ "$PM" = "pnpm" ]; then
  pnpm audit --json > "$REPORT_DIR/audit.json" 2>/dev/null || true
  pnpm outdated --json > "$REPORT_DIR/outdated.json" 2>/dev/null || true
elif [ "$PM" = "npm" ]; then
  npm audit --json > "$REPORT_DIR/audit.json" 2>/dev/null || true
  npm outdated --json > "$REPORT_DIR/outdated.json" 2>/dev/null || true
elif [ "$PM" = "pip" ]; then
  pip audit --json -o "$REPORT_DIR/audit.json" 2>/dev/null || echo "[]" > "$REPORT_DIR/audit.json"
fi

# ── Summary ─────────────────────────────────────────────────────────

AUDIT_SIZE=$(wc -c < "$REPORT_DIR/audit.json" 2>/dev/null || echo 0)
OUTDATED_SIZE=$(wc -c < "$REPORT_DIR/outdated.json" 2>/dev/null || echo 0)

echo "Audit report: $REPORT_DIR/audit.json ($AUDIT_SIZE bytes)"
echo "Outdated report: $REPORT_DIR/outdated.json ($OUTDATED_SIZE bytes)"
echo ""

# ── AI Analysis (optional) ──────────────────────────────────────────

if [ "$USE_AI" = "--ai" ]; then
  if ! command -v claude &>/dev/null; then
    echo "ERROR: claude CLI not found for AI analysis."
    exit 1
  fi

  echo "Running AI analysis..."
  AUDIT_DATA=$(cat "$REPORT_DIR/audit.json" | head -c 5000)
  OUTDATED_DATA=$(cat "$REPORT_DIR/outdated.json" | head -c 5000)

  claude -p "Analyze these dependency check results. Be concise.

AUDIT RESULTS:
$AUDIT_DATA

OUTDATED PACKAGES:
$OUTDATED_DATA

Respond with:
1. CRITICAL issues requiring immediate action (if any)
2. Safe-to-update packages (patch/minor versions only)
3. ACTION_REQUIRED: YES or NO
Keep it under 20 lines." --max-turns 1

else
  # Basic local analysis
  if [ "$PM" = "pnpm" ] || [ "$PM" = "npm" ]; then
    CRITICAL=$(grep -c '"critical"' "$REPORT_DIR/audit.json" 2>/dev/null || echo 0)
    HIGH=$(grep -c '"high"' "$REPORT_DIR/audit.json" 2>/dev/null || echo 0)

    echo "Vulnerabilities found:"
    echo "  Critical: $CRITICAL"
    echo "  High: $HIGH"

    if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
      echo ""
      echo "ACTION REQUIRED: Run '$PM audit' for details."
      # macOS notification
      if command -v osascript &>/dev/null; then
        osascript -e "display notification \"$CRITICAL critical, $HIGH high vulnerabilities found\" with title \"Dependency Check\" subtitle \"$(basename "$(pwd)")\""
      fi
    else
      echo ""
      echo "No critical or high vulnerabilities. All clear."
    fi
  fi
fi

echo ""
echo "Full reports saved to: $REPORT_DIR/"
