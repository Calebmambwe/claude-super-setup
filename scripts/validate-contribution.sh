#!/usr/bin/env bash
# validate-contribution.sh
# Validates a community contribution directory or single artifact file for CI.
#
# Usage:
#   bash validate-contribution.sh <path>
#
# Exit codes:
#   0 — all checks passed (warnings may exist)
#   1 — one or more FAIL checks found
#
# Output: structured text suitable for CI logs and human review.

set -euo pipefail

# ─── Colour helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

fail_count=0
warn_count=0
issues=()

record_fail() {
  issues+=("[FAIL] $*")
  (( fail_count++ )) || true
}

record_warn() {
  issues+=("[WARN] $*")
  (( warn_count++ )) || true
}

# ─── Usage ───────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <contribution-directory-or-file>" >&2
  exit 1
fi

TARGET="$(cd "$(dirname "$1")" 2>/dev/null && pwd)/$(basename "$1")"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}  Community Contribution Validator${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Target: $TARGET"
echo ""

# ─── 1. Target must exist ─────────────────────────────────────────────────────
if [[ ! -e "$TARGET" ]]; then
  echo -e "${RED}[FAIL] path not found: $TARGET${RESET}"
  exit 1
fi

# ─── 2. Locate manifest ───────────────────────────────────────────────────────
MANIFEST=""
CONTRIB_DIR=""
SINGLE_FILE_MODE=false

if [[ -d "$TARGET" ]]; then
  CONTRIB_DIR="$TARGET"
  if [[ -f "$TARGET/package.yaml" ]]; then
    MANIFEST="$TARGET/package.yaml"
  elif [[ -f "$TARGET/package.json" ]]; then
    MANIFEST="$TARGET/package.json"
  else
    echo "  [WARN] no package.yaml or package.json found — validating files only"
    warn_count=$(( warn_count + 1 ))
  fi
elif [[ -f "$TARGET" && "$TARGET" == *.md ]]; then
  SINGLE_FILE_MODE=true
  CONTRIB_DIR="$(dirname "$TARGET")"
  echo "  [INFO] single-file mode — validating $TARGET only"
else
  record_fail "target must be a directory or a .md file, got: $TARGET"
fi

# ─── Helpers ─────────────────────────────────────────────────────────────────

# Extract a YAML field value (simple key: value, no nested support needed here)
yaml_field() {
  local file="$1"
  local field="$2"
  grep -E "^${field}:" "$file" 2>/dev/null | head -1 | sed "s/^${field}:[[:space:]]*//" | tr -d '"' || true
}

# Check whether a file has a frontmatter block (starts with ---)
has_frontmatter() {
  local file="$1"
  head -1 "$file" 2>/dev/null | grep -q "^---"
}

# Extract a frontmatter field value from a .md file
frontmatter_field() {
  local file="$1"
  local field="$2"
  awk '/^---/{found++; next} found==1 && /^'"$field"':/{sub(/^'"$field"':[[:space:]]*/,""); print; exit}' "$file" 2>/dev/null | tr -d '"' || true
}

# ─── 3. Manifest validation ───────────────────────────────────────────────────
PKG_NAME=""
PKG_VERSION=""
PKG_TYPE=""
PKG_AUTHOR=""
PKG_DESC=""

if [[ -n "$MANIFEST" ]]; then
  echo "  Manifest: $MANIFEST"
  echo ""

  # Required fields
  PKG_NAME="$(yaml_field "$MANIFEST" "name")"
  PKG_VERSION="$(yaml_field "$MANIFEST" "version")"
  PKG_TYPE="$(yaml_field "$MANIFEST" "type")"
  PKG_AUTHOR="$(yaml_field "$MANIFEST" "author")"
  PKG_DESC="$(yaml_field "$MANIFEST" "description")"

  [[ -z "$PKG_NAME" ]]    && record_fail "manifest: missing required field \"name\""
  [[ -z "$PKG_VERSION" ]] && record_fail "manifest: missing required field \"version\""
  [[ -z "$PKG_TYPE" ]]    && record_fail "manifest: missing required field \"type\""
  [[ -z "$PKG_AUTHOR" ]]  && record_fail "manifest: missing required field \"author\""
  [[ -z "$PKG_DESC" ]]    && record_fail "manifest: missing required field \"description\""

  # Field format checks
  if [[ -n "$PKG_NAME" ]] && ! echo "$PKG_NAME" | grep -qE '^[a-z][a-z0-9-]*$'; then
    record_fail "manifest: \"name\" must be kebab-case (^[a-z][a-z0-9-]*\$), got \"$PKG_NAME\""
  fi

  if [[ -n "$PKG_VERSION" ]] && ! echo "$PKG_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    record_fail "manifest: \"version\" must be semver X.Y.Z, got \"$PKG_VERSION\""
  fi

  if [[ -n "$PKG_TYPE" ]] && ! echo "$PKG_TYPE" | grep -qE '^(agent|skill|command|hook|team)$'; then
    record_fail "manifest: \"type\" must be one of agent/skill/command/hook/team, got \"$PKG_TYPE\""
  fi

  if [[ -n "$PKG_DESC" ]] && [[ ${#PKG_DESC} -lt 10 ]]; then
    record_fail "manifest: \"description\" must be at least 10 characters, got ${#PKG_DESC}"
  fi

  MODEL_TIER="$(yaml_field "$MANIFEST" "model_tier")"
  if [[ -n "$MODEL_TIER" ]] && ! echo "$MODEL_TIER" | grep -qE '^(haiku|sonnet|opus)$'; then
    record_fail "manifest: \"model_tier\" must be one of haiku/sonnet/opus, got \"$MODEL_TIER\""
  fi

  HOMEPAGE="$(yaml_field "$MANIFEST" "homepage")"
  if [[ -n "$HOMEPAGE" ]] && ! echo "$HOMEPAGE" | grep -qE '^https?://'; then
    record_fail "manifest: \"homepage\" must be a valid URL starting with http:// or https://, got \"$HOMEPAGE\""
  fi
fi

# ─── 4. Naming conventions ────────────────────────────────────────────────────
echo "  Checking naming conventions..."

# Allowed uppercase filenames
ALLOWED_UPPERCASE=("SKILL.md" "README.md" "CHANGELOG.md" "AGENTS.md" "LICENSE")

while IFS= read -r -d '' file; do
  filename="$(basename "$file")"
  dirpart="$(dirname "$file")"
  relpath="${file#"$CONTRIB_DIR/"}"

  # Skip manifest files
  [[ "$filename" == "package.yaml" || "$filename" == "package.json" ]] && continue

  # Check if this is an allowed uppercase name
  is_allowed_upper=false
  for allowed in "${ALLOWED_UPPERCASE[@]}"; do
    [[ "$filename" == "$allowed" ]] && is_allowed_upper=true && break
  done

  if [[ "$is_allowed_upper" == false && "$filename" == *.md ]]; then
    if ! echo "$filename" | grep -qE '^[a-z][a-z0-9-]*\.md$'; then
      record_fail "naming: file \"$relpath\" must be kebab-case (e.g. \"$(echo "$filename" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')\")"
    fi
  fi
done < <(find "$CONTRIB_DIR" -type f -print0 2>/dev/null)

# Check directory naming
while IFS= read -r -d '' dir; do
  dirname_only="$(basename "$dir")"
  reldir="${dir#"$CONTRIB_DIR/"}"
  [[ "$reldir" == "." || -z "$reldir" ]] && continue
  if ! echo "$dirname_only" | grep -qE '^[a-z][a-z0-9-]*$'; then
    record_fail "naming: directory \"$reldir\" must be kebab-case (e.g. \"$(echo "$dirname_only" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')\")"
  fi
done < <(find "$CONTRIB_DIR" -mindepth 1 -type d -print0 2>/dev/null)

# ─── 5. Artifact-level validation ─────────────────────────────────────────────

validate_agent() {
  local file="$1"
  local relpath="${file#"$CONTRIB_DIR/"}"
  local fname
  fname="$(basename "$file" .md)"

  if ! has_frontmatter "$file"; then
    record_fail "agent frontmatter: \"$relpath\" missing frontmatter block (must start with ---)"
    return
  fi

  local fm_name
  fm_name="$(frontmatter_field "$file" "name")"
  [[ -z "$fm_name" ]] && record_fail "agent frontmatter: \"$relpath\" missing required field \"name\""

  local fm_desc
  fm_desc="$(frontmatter_field "$file" "description")"
  [[ -z "$fm_desc" ]] && record_fail "agent frontmatter: \"$relpath\" missing required field \"description\""

  if [[ -n "$fm_name" && "$fm_name" != "$fname" ]]; then
    record_warn "agent frontmatter: \"$relpath\" name in frontmatter (\"$fm_name\") does not match filename (\"$fname\")"
  fi
}

validate_skill() {
  local skill_path="$1"
  local relpath="${skill_path#"$CONTRIB_DIR/"}"

  if [[ ! -d "$skill_path" ]]; then
    record_fail "skill: \"$relpath\" must be a directory — skills are directories containing SKILL.md"
    return
  fi

  local skill_md="$skill_path/SKILL.md"
  if [[ ! -f "$skill_md" ]]; then
    record_fail "skill: \"$relpath/SKILL.md\" not found — every skill directory requires a SKILL.md"
    return
  fi

  if ! has_frontmatter "$skill_md"; then
    record_fail "skill: \"$relpath/SKILL.md\" missing frontmatter block"
    return
  fi

  local fm_name
  fm_name="$(frontmatter_field "$skill_md" "name")"
  [[ -z "$fm_name" ]] && record_fail "skill: \"$relpath/SKILL.md\" missing required frontmatter field \"name\""

  local fm_desc
  fm_desc="$(frontmatter_field "$skill_md" "description")"
  [[ -z "$fm_desc" ]] && record_fail "skill: \"$relpath/SKILL.md\" missing required frontmatter field \"description\""
}

validate_command() {
  local file="$1"
  local relpath="${file#"$CONTRIB_DIR/"}"

  if ! has_frontmatter "$file"; then
    record_fail "command: \"$relpath\" missing frontmatter block (must start with ---)"
    return
  fi

  local fm_name
  fm_name="$(frontmatter_field "$file" "name")"
  [[ -z "$fm_name" ]] && record_fail "command: \"$relpath\" missing required frontmatter field \"name\""

  local fm_desc
  fm_desc="$(frontmatter_field "$file" "description")"
  [[ -z "$fm_desc" ]] && record_fail "command: \"$relpath\" missing required frontmatter field \"description\""

  # Body must be non-empty (more than just frontmatter)
  local line_count
  line_count="$(wc -l < "$file")"
  if [[ "$line_count" -lt 6 ]]; then
    record_fail "command: \"$relpath\" body appears empty — command must contain instructions"
  fi
}

validate_hook() {
  local file="$1"
  local relpath="${file#"$CONTRIB_DIR/"}"

  if ! has_frontmatter "$file"; then
    record_fail "hook: \"$relpath\" missing frontmatter block"
    return
  fi

  local fm_name
  fm_name="$(frontmatter_field "$file" "name")"
  [[ -z "$fm_name" ]] && record_fail "hook: \"$relpath\" missing required frontmatter field \"name\""
}

# ─── 6. Process artifacts from manifest ──────────────────────────────────────

if [[ -n "$MANIFEST" ]]; then
  echo "  Checking artifacts..."

  # Parse artifacts from YAML — extract path/type pairs
  # This handles simple YAML arrays of objects
  in_artifacts=false
  current_path=""
  current_type=""

  while IFS= read -r line; do
    if echo "$line" | grep -qE '^artifacts:'; then
      in_artifacts=true
      continue
    fi
    if [[ "$in_artifacts" == true ]]; then
      # A top-level key (not indented) ends the artifacts block
      if echo "$line" | grep -qE '^[a-z]'; then
        in_artifacts=false
        continue
      fi
      # Extract path
      if echo "$line" | grep -qE '^\s+(- )?path:'; then
        current_path="$(echo "$line" | sed 's/.*path:[[:space:]]*//' | tr -d '"')"
      fi
      # Extract type
      if echo "$line" | grep -qE '^\s+type:'; then
        current_type="$(echo "$line" | sed 's/.*type:[[:space:]]*//' | tr -d '"')"
        # When we have both, validate this artifact
        if [[ -n "$current_path" && -n "$current_type" ]]; then
          artifact_abs="$CONTRIB_DIR/$current_path"
          if [[ ! -e "$artifact_abs" ]]; then
            record_fail "artifact not found: $current_path"
          else
            case "$current_type" in
              agent)   validate_agent "$artifact_abs" ;;
              skill)   validate_skill "$artifact_abs" ;;
              command) validate_command "$artifact_abs" ;;
              hook)    validate_hook "$artifact_abs" ;;
              *)       record_fail "artifact: \"$current_path\" unknown type \"$current_type\"" ;;
            esac
          fi
          current_path=""
          current_type=""
        fi
      fi
    fi
  done < "$MANIFEST"
fi

# ─── 7. Single-file mode ──────────────────────────────────────────────────────

if [[ "$SINGLE_FILE_MODE" == true ]]; then
  echo "  Checking single file..."
  # Infer type from path
  inferred_type=""
  if echo "$TARGET" | grep -qE '/agents?/'; then
    inferred_type="agent"
  elif echo "$TARGET" | grep -qE '/skills?/'; then
    inferred_type="skill"
  elif echo "$TARGET" | grep -qE '/commands?/'; then
    inferred_type="command"
  elif echo "$TARGET" | grep -qE '/hooks?/'; then
    inferred_type="hook"
  fi

  if [[ -z "$inferred_type" ]]; then
    record_warn "single-file: could not infer type from path — skipping frontmatter check (place file under agents/, skills/, commands/, or hooks/)"
  else
    case "$inferred_type" in
      agent)   validate_agent "$TARGET" ;;
      skill)   validate_skill "$(dirname "$TARGET")" ;;
      command) validate_command "$TARGET" ;;
      hook)    validate_hook "$TARGET" ;;
    esac
  fi
fi

# ─── 8. Duplicate name check ─────────────────────────────────────────────────

if [[ -n "$PKG_NAME" ]]; then
  echo "  Checking for duplicates..."

  # Check agents
  if [[ -d ~/.claude/agents ]]; then
    if ls ~/.claude/agents/ 2>/dev/null | sed 's/\.md$//' | grep -qxF "$PKG_NAME"; then
      record_warn "duplicate: \"$PKG_NAME\" already exists in ~/.claude/agents/ — installing will overwrite it"
    fi
  fi

  # Check commands
  if [[ -d ~/.claude/commands ]]; then
    if ls ~/.claude/commands/ 2>/dev/null | sed 's/\.md$//' | grep -qxF "$PKG_NAME"; then
      record_warn "duplicate: \"$PKG_NAME\" already exists in ~/.claude/commands/ — installing will overwrite it"
    fi
  fi

  # Check skills
  if [[ -d ~/.claude/skills ]]; then
    if ls ~/.claude/skills/ 2>/dev/null | grep -qxF "$PKG_NAME"; then
      record_warn "duplicate: \"$PKG_NAME\" already exists in ~/.claude/skills/ — installing will overwrite it"
    fi
  fi

  # Check catalog.yaml if present
  CATALOG_FILE="${CLAUDE_SUPER_SETUP_DIR:-$HOME/.claude-super-setup}/catalog.yaml"
  if [[ -f "$CATALOG_FILE" ]]; then
    if grep -E "^  name:" "$CATALOG_FILE" 2>/dev/null | awk '{print $2}' | tr -d '"' | grep -qxF "$PKG_NAME"; then
      record_warn "duplicate: package name \"$PKG_NAME\" conflicts with an entry in catalog.yaml"
    fi
  fi
fi

# ─── 9. Final report ─────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}  Validation Report${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -n "$PKG_NAME" || -n "$PKG_VERSION" ]]; then
  echo "  Package: ${PKG_NAME:-unknown} v${PKG_VERSION:-?} (${PKG_TYPE:-?}) by ${PKG_AUTHOR:-unknown}"
  echo ""
fi

if [[ ${#issues[@]} -eq 0 ]]; then
  echo "  Issues:  None"
else
  echo "  Issues:"
  for issue in "${issues[@]}"; do
    if [[ "$issue" == \[FAIL\]* ]]; then
      echo -e "    ${RED}${issue}${RESET}"
    else
      echo -e "    ${YELLOW}${issue}${RESET}"
    fi
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $fail_count -gt 0 ]]; then
  echo -e "  Result: ${RED}FAIL${RESET} — ${fail_count} error(s), ${warn_count} warning(s)"
  echo ""
  echo "  Fix the listed issues and re-run:"
  echo "    bash scripts/validate-contribution.sh $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 1
else
  echo -e "  Result: ${GREEN}PASS${RESET} — ${warn_count} warning(s)"
  echo ""
  echo "  Next step: open a PR to github.com/calebmambwe/claude-super-setup"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
fi
