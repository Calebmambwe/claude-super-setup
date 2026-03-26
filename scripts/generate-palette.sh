#!/usr/bin/env bash
# generate-palette.sh
# Wrapper around oklch-math.mjs that validates input and optionally writes
# the generated CSS to a file.
#
# Usage:
#   ./scripts/generate-palette.sh "#3ECF8E"
#   ./scripts/generate-palette.sh "#0081F2" --output src/app/globals.css
#   ./scripts/generate-palette.sh "#000000"
#
# Exit codes:
#   0  success
#   1  bad arguments / invalid hex
#   2  Node.js not found
#   3  mjs script not found

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $(basename "$0") <hex-color> [--output <path>]

Arguments:
  <hex-color>       A CSS hex colour, e.g. "#3ECF8E" or "3ecf8e"
  --output <path>   (optional) Write the CSS to this file instead of stdout

Examples:
  $(basename "$0") "#3ECF8E"
  $(basename "$0") "#0081F2" --output src/app/globals.css
EOF
}

err() {
  echo "error: $*" >&2
}

# ---------------------------------------------------------------------------
# Locate the mjs script relative to this script's own directory
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MJS_SCRIPT="${SCRIPT_DIR}/oklch-math.mjs"

if [[ ! -f "${MJS_SCRIPT}" ]]; then
  err "oklch-math.mjs not found at ${MJS_SCRIPT}"
  exit 3
fi

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

HEX_INPUT=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output|-o)
      if [[ -z "${2-}" ]]; then
        err "--output requires a path argument"
        exit 1
      fi
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [[ -n "${HEX_INPUT}" ]]; then
        err "Unexpected argument: $1 (hex color already set to '${HEX_INPUT}')"
        usage
        exit 1
      fi
      HEX_INPUT="$1"
      shift
      ;;
  esac
done

if [[ -z "${HEX_INPUT}" ]]; then
  err "No hex color provided."
  usage
  exit 1
fi

# ---------------------------------------------------------------------------
# Validate hex format
# ---------------------------------------------------------------------------

# Strip leading '#' for the regex check, then restore canonical form
HEX_CLEAN="${HEX_INPUT#\#}"

if [[ ! "${HEX_CLEAN}" =~ ^[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$ ]]; then
  err "\"${HEX_INPUT}\" is not a valid hex color."
  err "Expected 3 or 6 hex digits, e.g. \"#3ECF8E\" or \"#RGB\"."
  exit 1
fi

# Normalise: ensure the '#' prefix is present for the Node script
HEX_NORMALISED="#${HEX_CLEAN}"

# ---------------------------------------------------------------------------
# Dependency check: Node.js
# ---------------------------------------------------------------------------

if ! command -v node &>/dev/null; then
  err "Node.js is required but was not found in PATH."
  err "Install it from https://nodejs.org or via your package manager."
  exit 2
fi

NODE_VERSION="$(node --version 2>/dev/null)"
REQUIRED_MAJOR=14

# Extract major version number
NODE_MAJOR="${NODE_VERSION#v}"
NODE_MAJOR="${NODE_MAJOR%%.*}"

if (( NODE_MAJOR < REQUIRED_MAJOR )); then
  err "Node.js ${NODE_VERSION} is too old. Version ${REQUIRED_MAJOR}+ is required."
  exit 2
fi

# ---------------------------------------------------------------------------
# Run the generator
# ---------------------------------------------------------------------------

CSS_OUTPUT="$(node "${MJS_SCRIPT}" "${HEX_NORMALISED}")"

if [[ -z "${OUTPUT_FILE}" ]]; then
  # Print to stdout
  printf '%s\n' "${CSS_OUTPUT}"
else
  # Ensure the parent directory exists
  OUTPUT_DIR="$(dirname "${OUTPUT_FILE}")"
  if [[ ! -d "${OUTPUT_DIR}" ]]; then
    err "Output directory does not exist: ${OUTPUT_DIR}"
    exit 1
  fi

  printf '%s\n' "${CSS_OUTPUT}" > "${OUTPUT_FILE}"
  echo "Palette written to: ${OUTPUT_FILE}" >&2
fi
