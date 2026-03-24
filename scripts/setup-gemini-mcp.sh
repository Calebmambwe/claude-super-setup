#!/usr/bin/env bash
set -euo pipefail

# Setup Gemini MCP for claude-super-setup
# Usage: bash scripts/setup-gemini-mcp.sh [--dry-run] [--with-fal]
#
# Adds Gemini MCP to the user's Claude Code configuration.
# Requires: GEMINI_API_KEY environment variable or ~/.claude/channels/telegram/.env
#
# Options:
#   --dry-run    Show what would be done without making changes
#   --with-fal   Also add fal.ai MCP (requires FAL_KEY env var)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

DRY_RUN=false
WITH_FAL=false

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --with-fal) WITH_FAL=true ;;
    *) err "Unknown argument: $arg"; exit 1 ;;
  esac
done

echo ""
echo -e "${BLUE}Gemini MCP Setup${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check for GEMINI_API_KEY
if [ -z "${GEMINI_API_KEY:-}" ]; then
  # Try loading from telegram .env
  TELEGRAM_ENV="$HOME/.claude/channels/telegram/.env"
  if [ -f "$TELEGRAM_ENV" ]; then
    GEMINI_API_KEY=$(grep -s '^GEMINI_API_KEY=' "$TELEGRAM_ENV" | head -1 | sed 's/^GEMINI_API_KEY=//' | sed 's/[[:space:]]*#.*//' | sed "s/^[\"']\(.*\)[\"']$/\1/" | tr -d '\r' || true)
  fi
fi

if [ -z "${GEMINI_API_KEY:-}" ]; then
  err "GEMINI_API_KEY not found."
  echo ""
  echo "Set it with one of:"
  echo "  export GEMINI_API_KEY=your-key-here"
  echo "  # or add to ~/.claude/channels/telegram/.env:"
  echo "  echo 'GEMINI_API_KEY=your-key-here' >> ~/.claude/channels/telegram/.env"
  echo ""
  echo "Get a key at: https://aistudio.google.com/apikey"
  exit 1
fi

log "GEMINI_API_KEY found"

# Validate API key format (prevent shell injection via crafted key values)
if ! [[ "$GEMINI_API_KEY" =~ ^[A-Za-z0-9_-]{10,}$ ]]; then
  err "GEMINI_API_KEY contains unexpected characters. Expected alphanumeric, hyphens, underscores."
  exit 1
fi

# Check for npx
if ! command -v npx &>/dev/null; then
  err "npx not found. Install Node.js first: nvm install 22"
  exit 1
fi

# Add Gemini MCP via claude CLI
if command -v claude &>/dev/null; then
  if $DRY_RUN; then
    info "[DRY-RUN] Would run: claude mcp add gemini -s user -- env GEMINI_API_KEY=*** npx -y @rlabs-inc/gemini-mcp@0.1.2"
  else
    info "Adding Gemini MCP via claude CLI..."
    # Pass keys via environment (not -e flag) to avoid exposure in ps aux
    GEMINI_API_KEY="$GEMINI_API_KEY" GEMINI_TOOL_PRESET="media" \
      claude mcp add gemini -s user -- npx -y @rlabs-inc/gemini-mcp@0.1.2 2>/dev/null && \
      log "Gemini MCP added to Claude Code" || \
      warn "claude mcp add failed — may already exist. Check with: claude mcp list"
  fi
else
  warn "claude CLI not found. Add Gemini MCP manually to ~/.mcp.json:"
  cat <<'MANUAL'
{
  "mcpServers": {
    "gemini": {
      "command": "npx",
      "args": ["-y", "@rlabs-inc/gemini-mcp"],
      "env": {
        "GEMINI_API_KEY": "your-key-here",
        "GEMINI_TOOL_PRESET": "media"
      }
    }
  }
}
MANUAL
fi

# Optionally add fal.ai MCP
if $WITH_FAL; then
  if [ -z "${FAL_KEY:-}" ]; then
    warn "FAL_KEY not set. Skipping fal.ai MCP."
    echo "  Set it with: export FAL_KEY=your-key-here"
    echo "  Get a key at: https://fal.ai/dashboard/keys"
  elif ! [[ "$FAL_KEY" =~ ^[A-Za-z0-9_:-]{10,}$ ]]; then
    err "FAL_KEY contains unexpected characters. Expected alphanumeric, hyphens, underscores, colons."
    exit 1
  else
    if command -v claude &>/dev/null; then
      if $DRY_RUN; then
        info "[DRY-RUN] Would run: claude mcp add fal-ai --transport http https://mcp.fal.ai/mcp"
      else
        info "Adding fal.ai MCP via claude CLI..."
        FAL_KEY="$FAL_KEY" \
          claude mcp add fal-ai --transport http "https://mcp.fal.ai/mcp" -s user 2>/dev/null && \
          log "fal.ai MCP added to Claude Code" || \
          warn "fal.ai MCP add failed — may already exist."
      fi
    fi
  fi
fi

# Pre-cache the package
if ! $DRY_RUN; then
  info "Pre-caching @rlabs-inc/gemini-mcp package..."
  npx -y @rlabs-inc/gemini-mcp@0.1.2 --help >/dev/null 2>&1 || true
  log "Package cached"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Gemini MCP setup complete!${NC}"
echo ""
echo "Available tools (37 via @rlabs-inc/gemini-mcp):"
echo "  - Image generation (Imagen 3)"
echo "  - Video generation (Veo 2)"
echo "  - Text-to-speech"
echo "  - Image editing and understanding"
echo ""
echo "Test with: /prototype 'a minimal habit tracker app with dark mode'"
echo ""
