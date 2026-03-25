#!/usr/bin/env bash
set -euo pipefail

# Sync Claude Code config to VPS — makes VPS a mirror of local Mac setup
# Usage: bash scripts/sync-to-vps.sh [--dry-run] [--install-mcps] [--full]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[SYNC]${NC} $1"; }
warn() { echo -e "${YELLOW}[SYNC]${NC} $1"; }
err() { echo -e "${RED}[SYNC]${NC} $1"; }
info() { echo -e "${CYAN}[SYNC]${NC} $1"; }

DRY_RUN=false
INSTALL_MCPS=false
FULL=false

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --install-mcps) INSTALL_MCPS=true; shift ;;
    --full) FULL=true; INSTALL_MCPS=true; shift ;;
    *) err "Unknown arg: $1"; exit 1 ;;
  esac
done

# --- Load VPS credentials ---
ENV_FILE="$HOME/.claude/.env.local"
if [ ! -f "$ENV_FILE" ]; then
  err "Missing $ENV_FILE"
  exit 1
fi

VPS_IP=$(grep '^VPS_IP=' "$ENV_FILE" | sed 's/^VPS_IP=//' | tr -d '[:space:]' || echo "187.77.15.168")
VPS_PASS=$(grep '^VPS_PASS=' "$ENV_FILE" | sed 's/^VPS_PASS=//' | tr -d '[:space:]')
[ -z "$VPS_IP" ] && VPS_IP="187.77.15.168"

if [ -z "$VPS_PASS" ]; then
  err "VPS_PASS not set in $ENV_FILE"
  exit 1
fi

SSH="sshpass -p '$VPS_PASS' ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 root@$VPS_IP"
SCP="sshpass -p '$VPS_PASS' scp -o StrictHostKeyChecking=accept-new"

run_ssh() {
  if $DRY_RUN; then
    info "[DRY RUN] SSH: $1"
    return 0
  fi
  eval "$SSH '$1'"
}

echo ""
echo "========================================="
echo "  Claude Code VPS Sync"
echo "========================================="
echo "  Mac → VPS ($VPS_IP)"
echo "  Dry run: $DRY_RUN"
echo "  Install MCPs: $INSTALL_MCPS"
echo "========================================="
echo ""

# --- Step 1: Git pull on VPS ---
log "Step 1: Pulling latest code on VPS..."
run_ssh 'cd ~/.claude-super-setup && git pull -q 2>&1 && echo "Git pull: OK" || echo "Git pull: FAILED"'

# --- Step 2: Run install.sh on VPS ---
log "Step 2: Running install.sh (symlinks all modules)..."
run_ssh 'cd ~/.claude-super-setup && bash install.sh 2>&1 | tail -5'

# --- Step 3: Sync API keys ---
log "Step 3: Syncing API keys..."
MANUS_KEY=$(grep '^MANUS_API_KEY=' "$ENV_FILE" | sed 's/^MANUS_API_KEY=//')
GEMINI_KEY=$(grep '^GEMINI_API_KEY=' "$ENV_FILE" | sed 's/^GEMINI_API_KEY=//')
OPENAI_KEY=$(grep '^OPENAI_API_KEY=' "$ENV_FILE" | sed 's/^OPENAI_API_KEY=//')

if $DRY_RUN; then
  info "[DRY RUN] Would sync API keys (Manus, Gemini, OpenAI)"
else
  eval "$SSH" bash -c "'
    # Update claude user .env.local
    mkdir -p /home/claude/.claude
    cat > /home/claude/.claude/.env.local << ENVEOF
MANUS_API_KEY=$MANUS_KEY
GEMINI_API_KEY=$GEMINI_KEY
OPENAI_API_KEY=$OPENAI_KEY
ENVEOF
    chown claude:claude /home/claude/.claude/.env.local
    chmod 600 /home/claude/.claude/.env.local

    # Also update .claude/.env for existing scripts
    cat > /home/claude/.claude/.env << ENVEOF2
GEMINI_API_KEY=$GEMINI_KEY
OPENAI_API_KEY=$OPENAI_KEY
MANUS_API_KEY=$MANUS_KEY
ENVEOF2
    chown claude:claude /home/claude/.claude/.env
    chmod 600 /home/claude/.claude/.env

    echo \"API keys synced\"
  '"
fi

# --- Step 4: Sync MCP config ---
log "Step 4: Deploying MCP server config..."
if $DRY_RUN; then
  info "[DRY RUN] Would deploy .mcp.json with Context7, GitHub, Memory, Sequential Thinking, etc."
else
  # Get GitHub token from Mac if available
  GH_TOKEN=$(gh auth token 2>/dev/null || echo "")

  eval "$SSH" bash -c "'
    cat > /home/claude/.claude/.mcp.json << MCPEOF
{
  \"mcpServers\": {
    \"context7\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"@upstash/context7-mcp@latest\"]
    },
    \"github\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"@modelcontextprotocol/server-github\"],
      \"env\": {
        \"GITHUB_PERSONAL_ACCESS_TOKEN\": \"$GH_TOKEN\"
      }
    },
    \"memory\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"@modelcontextprotocol/server-memory\"]
    },
    \"sequential-thinking\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"@modelcontextprotocol/server-sequential-thinking\"]
    },
    \"code-review-graph\": {
      \"command\": \"uvx\",
      \"args\": [\"code-review-graph\", \"serve\"]
    },
    \"knowledge-rag\": {
      \"command\": \"npx\",
      \"args\": [\"-y\", \"knowledge-rag\", \"serve\"],
      \"env\": {
        \"KNOWLEDGE_RAG_DIR\": \"./docs:./agent_docs\",
        \"KNOWLEDGE_RAG_EXTENSIONS\": \".md,.mdx,.txt,.yaml,.yml\"
      }
    },
    \"learning\": {
      \"command\": \"python3\",
      \"args\": [\"/home/claude/.claude/mcp-servers/learning-server.py\"],
      \"env\": {
        \"OPENAI_API_KEY\": \"$OPENAI_KEY\"
      }
    },
    \"playwright\": {
      \"command\": \"npx\",
      \"args\": [\"@playwright/mcp@latest\"]
    }
  }
}
MCPEOF
    chown claude:claude /home/claude/.claude/.mcp.json
    echo \"MCP config deployed (8 servers)\"
  '"
fi

# --- Step 5: Install MCP server dependencies ---
if $INSTALL_MCPS; then
  log "Step 5: Installing MCP server npm packages on VPS..."
  run_ssh '
    export NVM_DIR="/home/claude/.nvm"
    source "$NVM_DIR/nvm.sh" 2>/dev/null || export PATH="/home/claude/.nvm/versions/node/v22.22.2/bin:$PATH"

    echo "Pre-installing MCP packages (so Claude starts faster)..."
    su - claude -s /bin/bash -c "
      export PATH=/home/claude/.nvm/versions/node/v22.22.2/bin:\$PATH
      npx -y @upstash/context7-mcp@latest --help > /dev/null 2>&1 &
      npx -y @modelcontextprotocol/server-github --help > /dev/null 2>&1 &
      npx -y @modelcontextprotocol/server-memory --help > /dev/null 2>&1 &
      npx -y @modelcontextprotocol/server-sequential-thinking --help > /dev/null 2>&1 &
      npx -y @playwright/mcp@latest --help > /dev/null 2>&1 &
      wait
      echo \"MCP packages pre-installed\"
    " 2>&1 | tail -3
  '
else
  warn "Step 5: Skipped MCP installation (use --install-mcps to install)"
fi

# --- Step 6: GitHub CLI auth ---
if $FULL; then
  log "Step 6: Setting up GitHub CLI auth on VPS..."
  GH_TOKEN=$(gh auth token 2>/dev/null || echo "")
  if [ -n "$GH_TOKEN" ]; then
    run_ssh "
      # Install gh if missing
      which gh > /dev/null 2>&1 || {
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        echo 'deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' > /etc/apt/sources.list.d/github-cli.list
        apt-get update -qq && apt-get install -y -qq gh > /dev/null 2>&1
      }

      # Auth with token
      su - claude -s /bin/bash -c \"echo '$GH_TOKEN' | gh auth login --with-token 2>&1\" || echo 'gh auth failed'
      su - claude -c 'gh auth status 2>&1' || echo 'gh not authed'
    "
  else
    warn "No GitHub token found locally — skipping gh auth"
  fi
else
  warn "Step 6: Skipped GitHub CLI auth (use --full)"
fi

# --- Step 7: Verify ---
log "Step 7: Verifying VPS configuration..."
run_ssh '
  echo "=== VPS Config Summary ==="
  echo "Settings: $(cat /home/claude/.claude/settings.json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"{len(d.get(chr(112)+chr(101)+chr(114)+chr(109)+chr(105)+chr(115)+chr(115)+chr(105)+chr(111)+chr(110)+chr(115),{}).get(chr(97)+chr(108)+chr(108)+chr(111)+chr(119),[]))} permissions\")" 2>/dev/null || echo "error")"
  echo "MCP servers: $(cat /home/claude/.claude/.mcp.json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get(chr(109)+chr(99)+chr(112)+chr(83)+chr(101)+chr(114)+chr(118)+chr(101)+chr(114)+chr(115),{})))" 2>/dev/null || echo "error")"
  echo "Commands: $(ls /home/claude/.claude/commands/ 2>/dev/null | wc -l | tr -d \" \")"
  echo "Agents: $(find /home/claude/.claude/agents/ -name \"*.md\" 2>/dev/null | wc -l | tr -d \" \")"
  echo "Hooks: $(ls /home/claude/.claude/hooks/ 2>/dev/null | wc -l | tr -d \" \")"
  echo "API keys: $(cat /home/claude/.claude/.env.local 2>/dev/null | wc -l | tr -d \" \") keys"
  echo "CLAUDE.md: $(wc -l < /home/claude/.claude/CLAUDE.md 2>/dev/null || echo 0) lines"
  echo "Plugins: $(ls /home/claude/.claude/plugins/marketplaces/ 2>/dev/null | wc -l | tr -d \" \")"
  which gh > /dev/null 2>&1 && echo "gh CLI: $(su - claude -c \"gh auth status 2>&1 | head -1\" || echo \"not authed\")" || echo "gh CLI: not installed"
'

echo ""
log "Sync complete!"
