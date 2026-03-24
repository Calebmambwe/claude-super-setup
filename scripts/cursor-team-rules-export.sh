#!/usr/bin/env bash
set -euo pipefail

# cursor-team-rules-export — Compile .mdc rules into AGENTS.md
# Workaround for sharing rules without Cursor Team/Enterprise plan
# Usage: cursor-team-rules-export.sh [--output PATH] [--rules-dir PATH] [--dry-run]

RULES_DIR=".cursor/rules"
OUTPUT="AGENTS.md"
DRY_RUN=false
MARKER="<!-- GENERATED RULES BELOW -->"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

for arg in "$@"; do
  case "$arg" in
    --output=*) OUTPUT="${arg#*=}" ;;
    --rules-dir=*) RULES_DIR="${arg#*=}" ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

if [[ ! -d "$RULES_DIR" ]]; then
  echo -e "${YELLOW}[WARN]${NC} Rules directory not found: $RULES_DIR"
  echo "Run cursor-sync rules first, or specify --rules-dir"
  exit 1
fi

# Count available rules
rule_count=$(find "$RULES_DIR" -name "*.mdc" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$rule_count" -eq 0 ]]; then
  echo -e "${YELLOW}[WARN]${NC} No .mdc files found in $RULES_DIR"
  exit 1
fi

echo -e "${BLUE}Compiling $rule_count rules into $OUTPUT...${NC}"

# Preserve custom content above the marker if AGENTS.md already exists
custom_content=""
if [[ -f "$OUTPUT" ]]; then
  if grep -q "$MARKER" "$OUTPUT"; then
    custom_content=$(sed "/$MARKER/q" "$OUTPUT" | head -n -1)
  else
    custom_content=$(cat "$OUTPUT")
  fi
fi

# Build the generated section
generated=""
generated+="$MARKER"$'\n'
generated+=""$'\n'
generated+="# Generated Rules"$'\n'
generated+=""$'\n'
generated+="*Auto-generated from .cursor/rules/*.mdc by cursor-team-rules-export.sh.*"$'\n'
generated+="*Edit individual .mdc files, not this section.*"$'\n'
generated+=""$'\n'

for rule_file in "$RULES_DIR"/*.mdc; do
  [[ -f "$rule_file" ]] || continue
  rule_name=$(basename "$rule_file" .mdc)

  # Extract content (strip frontmatter)
  content=$(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$rule_file")

  # If no frontmatter, use full file
  if [[ -z "$content" ]]; then
    content=$(cat "$rule_file")
  fi

  # Extract description from frontmatter for the heading
  description=$(awk '/^---$/{if(++c==2)exit}c==1 && /description:/{sub(/.*description:\s*/, ""); gsub(/"/, ""); print}' "$rule_file")

  generated+="## ${rule_name}"$'\n'
  if [[ -n "$description" ]]; then
    generated+="*${description}*"$'\n'
  fi
  generated+=""$'\n'
  generated+="$content"$'\n'
  generated+=""$'\n'
  generated+="---"$'\n'
  generated+=""$'\n'
done

# Combine custom content + generated content
full_output=""
if [[ -n "$custom_content" ]]; then
  full_output="${custom_content}"$'\n'$'\n'
fi
full_output+="$generated"

if [[ "$DRY_RUN" == true ]]; then
  echo -e "${BLUE}[dry-run]${NC} Would write $OUTPUT with $rule_count rules"
  echo ""
  echo "Preview (first 20 lines of generated section):"
  echo "$generated" | head -20
  exit 0
fi

echo "$full_output" > "$OUTPUT"
echo -e "${GREEN}[OK]${NC} Compiled $rule_count rules into $OUTPUT"
echo ""
echo "Both Claude Code and Cursor read AGENTS.md natively."
echo "Share this file with your team for consistent AI behavior across editors."
