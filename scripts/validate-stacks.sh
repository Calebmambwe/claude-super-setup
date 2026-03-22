#!/usr/bin/env bash
set -euo pipefail

# Validate all stack template YAML files against the JSON Schema
SCHEMA="schemas/stack-template.schema.json"
STACKS_DIR="config/stacks"
ERRORS=0

if ! command -v ajv &>/dev/null && ! command -v npx &>/dev/null; then
  echo "ERROR: ajv-cli not found. Install with: npm install -g ajv-cli"
  exit 1
fi

for yaml in "$STACKS_DIR"/*.yaml; do
  if [ ! -f "$yaml" ]; then
    echo "WARNING: No YAML files found in $STACKS_DIR"
    exit 0
  fi

  echo -n "Validating $(basename "$yaml")... "
  if npx --yes ajv-cli validate -s "$SCHEMA" -d "$yaml" --spec=draft2020 2>/dev/null; then
    echo "OK"
  else
    echo "FAIL"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS stack template(s) failed validation"
  exit 1
fi

echo "All stack templates valid."
