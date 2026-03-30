"""A2A server configuration — reads from environment variables."""

import os
from pathlib import Path

# Server
A2A_HOST = os.getenv("A2A_HOST", "0.0.0.0")
A2A_PORT = int(os.getenv("A2A_PORT", "9999"))
A2A_BASE_URL = os.getenv("A2A_BASE_URL", f"http://localhost:{A2A_PORT}")

# Agent identity
AGENT_ID = os.getenv("A2A_AGENT_ID", "vps-claude")
AGENT_NAME = os.getenv("A2A_AGENT_NAME", "VPS Claude Agent")
AGENT_DESCRIPTION = os.getenv(
    "A2A_AGENT_DESCRIPTION",
    "Autonomous coding agent on Hostinger VPS — builds, tests, deploys, and coordinates",
)

# Claude CLI
CLAUDE_BIN = os.getenv("CLAUDE_BIN", "claude")
CLAUDE_PROJECT_DIR = os.getenv("CLAUDE_PROJECT_DIR", str(Path.home() / ".claude-super-setup"))

# External APIs
MANUS_API_KEY = os.getenv("MANUS_API_KEY", "")
MANUS_API_URL = os.getenv("MANUS_API_URL", "https://api.manus.ai/v1")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_API_URL = os.getenv(
    "GEMINI_API_URL",
    "https://generativelanguage.googleapis.com/v1beta",
)

# Security
A2A_API_KEY = os.getenv("A2A_API_KEY", "")  # Shared secret for agent auth

# Telegram notification
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "8328233140")

# Peer agents (direct config — no registry needed)
PEER_AGENTS: dict[str, str] = {}
_peers = os.getenv("A2A_PEERS", "")  # Format: "name=url,name2=url2"
if _peers:
    for pair in _peers.split(","):
        if "=" in pair:
            name, url = pair.split("=", 1)
            PEER_AGENTS[name.strip()] = url.strip()
