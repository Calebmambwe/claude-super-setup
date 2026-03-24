#!/usr/bin/env bash
set -euo pipefail

# setup-vps.sh — One-command VPS bootstrap for claude-super-setup
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/Calebmambwe/claude-super-setup/main/scripts/setup-vps.sh | bash
#   bash scripts/setup-vps.sh [--dry-run] [--skip-docker] [--skip-tailscale]

VERSION="1.0.0"
REPO_URL="https://github.com/Calebmambwe/claude-super-setup.git"
REPO_DIR="$HOME/.claude-super-setup"
CLAUDE_DIR="$HOME/.claude"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
DRY_RUN=false
SKIP_DOCKER=false
SKIP_TAILSCALE=false
SKIP_CHEZMOI=false

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
dry()  { echo -e "${BLUE}[DRY-RUN]${NC} Would: $1"; }

run_cmd() {
  if $DRY_RUN; then
    dry "$*"
  else
    eval "$@"
  fi
}

usage() {
  cat <<USAGE
setup-vps.sh v${VERSION} — Bootstrap claude-super-setup on a fresh VPS

Usage: setup-vps.sh [OPTIONS]

Options:
  --dry-run          Show what would be done without doing it
  --skip-docker      Skip Docker installation
  --skip-tailscale   Skip Tailscale installation
  --skip-chezmoi     Skip chezmoi dotfiles setup
  --help             Show this help

Supports: Ubuntu 22.04+, Debian 12+, macOS (partial)
USAGE
  exit 0
}

# Parse arguments
for arg in "$@"; do
  case $arg in
    --dry-run)        DRY_RUN=true ;;
    --skip-docker)    SKIP_DOCKER=true ;;
    --skip-tailscale) SKIP_TAILSCALE=true ;;
    --skip-chezmoi)   SKIP_CHEZMOI=true ;;
    --help|-h)        usage ;;
    *) err "Unknown argument: $arg"; usage ;;
  esac
done

echo ""
echo -e "${BLUE}claude-super-setup VPS Bootstrap v${VERSION}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Phase 0: Detect OS ──────────────────────────────────────────────────────

detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

OS=$(detect_os)
info "Detected OS: $OS"

if [[ "$OS" == "unknown" ]]; then
  err "Unsupported OS. This script supports Ubuntu, Debian, and macOS."
  exit 1
fi

# ── Phase 1: System dependencies ────────────────────────────────────────────

info "Phase 1/9: Installing system dependencies..."

if [[ "$OS" == "macos" ]]; then
  if ! command -v brew &>/dev/null; then
    err "Homebrew is required on macOS. Install from https://brew.sh"
    exit 1
  fi
  run_cmd "brew install git curl jq tmux screen ffmpeg"
else
  run_cmd "sudo apt-get update -qq"
  run_cmd "sudo apt-get install -y -qq git curl jq tmux screen ffmpeg build-essential ca-certificates gnupg lsb-release"
fi

log "System dependencies installed."

# ── Phase 2: Node.js via nvm ────────────────────────────────────────────────

info "Phase 2/9: Installing Node.js 22 via nvm..."

if command -v node &>/dev/null && [[ "$(node -v)" == v22* ]]; then
  log "Node.js 22 already installed: $(node -v)"
else
  if [[ ! -d "$HOME/.nvm" ]]; then
    run_cmd "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash"
  fi
  if ! $DRY_RUN; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install 22
    nvm use 22
    nvm alias default 22
    log "Node.js installed: $(node -v)"
  else
    dry "nvm install 22 && nvm use 22"
  fi
fi

# ── Phase 3: Python via uv ──────────────────────────────────────────────────

info "Phase 3/9: Installing Python toolchain (uv)..."

if command -v uv &>/dev/null; then
  log "uv already installed: $(uv --version)"
else
  run_cmd "curl -LsSf https://astral.sh/uv/install.sh | sh"
  if ! $DRY_RUN; then
    export PATH="$HOME/.local/bin:$PATH"
    log "uv installed: $(uv --version)"
  fi
fi

# ── Phase 4: Docker (optional) ──────────────────────────────────────────────

if $SKIP_DOCKER; then
  info "Phase 4/9: Docker installation skipped (--skip-docker)"
else
  info "Phase 4/9: Installing Docker..."

  if command -v docker &>/dev/null; then
    log "Docker already installed: $(docker --version)"
  elif [[ "$OS" == "macos" ]]; then
    warn "Install Docker Desktop manually from https://docker.com/products/docker-desktop"
  else
    if ! $DRY_RUN; then
      # Use correct Docker repo for the detected OS (ubuntu vs debian)
      DOCKER_DISTRO="ubuntu"
      if [[ "$OS" == "debian" ]]; then
        DOCKER_DISTRO="debian"
      fi
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/${DOCKER_DISTRO}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DOCKER_DISTRO} \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo usermod -aG docker "$USER"
      log "Docker installed. You may need to log out and back in for group changes."
    else
      dry "Install Docker CE from official repo"
    fi
  fi
fi

# ── Phase 5: Claude Code CLI ────────────────────────────────────────────────

info "Phase 5/9: Installing Claude Code CLI..."

if command -v claude &>/dev/null; then
  log "Claude Code already installed: $(claude --version 2>/dev/null || echo 'installed')"
else
  run_cmd "npm install -g @anthropic-ai/claude-code"
  log "Claude Code CLI installed."
fi

echo ""
info "┌─────────────────────────────────────────────────────┐"
info "│  Authentication required for headless VPS usage:    │"
info "│                                                     │"
info "│  On your LOCAL machine, run:                        │"
info "│    claude setup-token                               │"
info "│                                                     │"
info "│  Then on this VPS, set:                             │"
info "│    export CLAUDE_CODE_OAUTH_TOKEN=<token>           │"
info "│                                                     │"
info "│  Add to ~/.claude/env for systemd services.         │"
info "└─────────────────────────────────────────────────────┘"
echo ""

# ── Phase 6: Clone repos ────────────────────────────────────────────────────

info "Phase 6/9: Cloning repositories..."

if [[ -d "$REPO_DIR" ]]; then
  info "Repository exists at $REPO_DIR — pulling latest..."
  run_cmd "cd \"$REPO_DIR\" && git pull --quiet origin main 2>/dev/null || true"
else
  run_cmd "git clone --quiet \"$REPO_URL\" \"$REPO_DIR\""
fi
log "claude-super-setup ready at $REPO_DIR"

# Run the installer
info "Running install.sh..."
if ! $DRY_RUN; then
  cd "$REPO_DIR"
  bash install.sh
else
  dry "bash $REPO_DIR/install.sh"
fi

# ── Phase 7: MCP servers ────────────────────────────────────────────────────

info "Phase 7/9: Setting up MCP servers..."

MCP_DIR="$CLAUDE_DIR/mcp-servers"
if [[ ! -d "$MCP_DIR" ]]; then
  run_cmd "mkdir -p \"$MCP_DIR\""
fi

# Copy MCP servers from repo (install.sh handles symlink mode,
# but for VPS we ensure they exist)
if [[ -f "$REPO_DIR/mcp-servers/learning-server.py" ]]; then
  if [[ ! -f "$MCP_DIR/learning-server.py" ]] && [[ ! -L "$MCP_DIR/learning-server.py" ]]; then
    run_cmd "ln -sf \"$REPO_DIR/mcp-servers/learning-server.py\" \"$MCP_DIR/learning-server.py\""
  fi
  log "Learning MCP server linked"
fi

if [[ -f "$REPO_DIR/mcp-servers/sandbox-server.py" ]]; then
  if [[ ! -f "$MCP_DIR/sandbox-server.py" ]] && [[ ! -L "$MCP_DIR/sandbox-server.py" ]]; then
    run_cmd "ln -sf \"$REPO_DIR/mcp-servers/sandbox-server.py\" \"$MCP_DIR/sandbox-server.py\""
  fi
  log "Sandbox MCP server linked"
fi

# Install Python deps for MCP servers
run_cmd "uv pip install mcp pydantic 2>/dev/null || true"

log "MCP servers configured."

# ── Phase 8: systemd services (Linux only) ──────────────────────────────────

if [[ "$OS" != "macos" ]]; then
  info "Phase 8/9: Installing systemd services..."

  SYSTEMD_SRC="$REPO_DIR/config/systemd"
  if [[ -d "$SYSTEMD_SRC" ]]; then
    for svc in "$SYSTEMD_SRC"/*.service; do
      svc_name=$(basename "$svc")
      if $DRY_RUN; then
        dry "cp $svc /etc/systemd/system/$svc_name"
      else
        sudo cp "$svc" "/etc/systemd/system/$svc_name"
        log "Installed $svc_name"
      fi
    done

    run_cmd "sudo systemctl daemon-reload"

    # Enable template services (user can start them after setting auth tokens)
    # Template units use @.service suffix — enable with @$USER instance
    for svc_name in claude-telegram claude-learning claude-sandbox; do
      if [[ -f "/etc/systemd/system/${svc_name}@.service" ]]; then
        run_cmd "sudo systemctl enable ${svc_name}@${USER} 2>/dev/null || true"
      fi
    done

    log "systemd services installed and enabled (not started — set auth tokens first)."
  else
    warn "No systemd service files found at $SYSTEMD_SRC"
  fi
else
  info "Phase 8/9: Skipped — systemd not available on macOS"
  info "Use launchd or manual 'screen' sessions instead."
fi

# ── Phase 9: Tailscale (optional) ───────────────────────────────────────────

if $SKIP_TAILSCALE; then
  info "Phase 9/9: Tailscale installation skipped (--skip-tailscale)"
else
  info "Phase 9/9: Installing Tailscale..."

  if command -v tailscale &>/dev/null; then
    log "Tailscale already installed."
  elif [[ "$OS" == "macos" ]]; then
    warn "Install Tailscale from the Mac App Store or https://tailscale.com/download"
  else
    run_cmd "curl -fsSL https://tailscale.com/install.sh | sh"
    echo ""
    info "Run 'sudo tailscale up' to connect to your Tailscale network."
  fi
fi

# ── Health check ─────────────────────────────────────────────────────────────

echo ""
info "Running health check..."

ERRORS=0
check_cmd() {
  if command -v "$1" &>/dev/null; then
    log "$1: $(command -v "$1")"
  else
    warn "$1: NOT FOUND"
    ERRORS=$((ERRORS + 1))
  fi
}

if ! $DRY_RUN; then
  check_cmd git
  check_cmd node
  check_cmd npm
  check_cmd uv
  check_cmd claude
  check_cmd jq
  check_cmd screen
  check_cmd tmux

  if ! $SKIP_DOCKER; then
    check_cmd docker
  fi

  # Check repo
  if [[ -d "$REPO_DIR" ]]; then
    log "Repo: $REPO_DIR"
  else
    warn "Repo not found at $REPO_DIR"
    ERRORS=$((ERRORS + 1))
  fi

  # Check Claude config
  if [[ -d "$CLAUDE_DIR" ]]; then
    CMD_COUNT=$(find "$CLAUDE_DIR/commands" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    log "Claude config: $CLAUDE_DIR ($CMD_COUNT commands)"
  else
    warn "Claude config not found at $CLAUDE_DIR"
    ERRORS=$((ERRORS + 1))
  fi

  # Check MCP servers
  if [[ -f "$CLAUDE_DIR/mcp-servers/learning-server.py" ]] || [[ -L "$CLAUDE_DIR/mcp-servers/learning-server.py" ]]; then
    log "Learning MCP server: present"
  else
    warn "Learning MCP server: missing"
    ERRORS=$((ERRORS + 1))
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if $DRY_RUN; then
  echo -e "${BLUE}VPS Bootstrap Dry Run Complete${NC}"
  echo "  (No changes were made)"
else
  if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}VPS Bootstrap Complete!${NC}"
  else
    echo -e "${YELLOW}VPS Bootstrap Complete with $ERRORS warning(s)${NC}"
  fi
fi
echo ""
echo "  Next steps:"
echo "  1. Set auth: export CLAUDE_CODE_OAUTH_TOKEN=<token>"
echo "  2. Save to: echo 'CLAUDE_CODE_OAUTH_TOKEN=<token>' >> ~/.claude/env"
if [[ "$OS" != "macos" ]]; then
  echo "  3. Start services:"
  echo "       sudo systemctl start claude-telegram@$USER"
  echo "       sudo systemctl start claude-learning@$USER"
fi
echo ""
echo "  Verify: bash $REPO_DIR/scripts/inventory-check.sh"
echo ""
