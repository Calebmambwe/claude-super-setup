"""
Shared pytest fixtures for unit tests.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import pytest

# ---------------------------------------------------------------------------
# Source path registration
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]
MCP_SERVERS_DIR = REPO_ROOT / "mcp-servers"
SCRIPTS_DIR = REPO_ROOT / "scripts"

# Prepend both source dirs so individual test files can import directly.
for _p in (str(MCP_SERVERS_DIR), str(SCRIPTS_DIR)):
    if _p not in sys.path:
        sys.path.insert(0, _p)


# ---------------------------------------------------------------------------
# LobeHub JSON agent fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def lobehub_agent_full() -> dict[str, Any]:
    """A complete, well-formed LobeHub agent JSON object."""
    return {
        "author": "alice",
        "homepage": "https://example.com/agent",
        "identifier": "code-explainer",
        "locale": "en-US",
        "config": {
            "systemRole": "You are an expert code explainer. Break down complex code into simple terms.",
            "model": "gpt-4",
            "params": {
                "temperature": 0.7,
                "max_tokens": 2048,
            },
            "displayMode": "chat",
            "enableHistoryCount": True,
            "historyCount": 10,
        },
        "meta": {
            "avatar": "💡",
            "tags": ["code", "education", "programming"],
            "title": "Code Explainer",
            "description": "Explains complex code in plain English for developers of all skill levels.",
        },
    }


@pytest.fixture()
def lobehub_agent_minimal() -> dict[str, Any]:
    """A minimal LobeHub agent with only required fields."""
    return {
        "identifier": "minimal-agent",
        "config": {
            "systemRole": "You are a helpful assistant.",
        },
        "meta": {
            "title": "Minimal Agent",
        },
    }


@pytest.fixture()
def lobehub_agent_no_meta() -> dict[str, Any]:
    """LobeHub agent missing the meta block entirely."""
    return {
        "identifier": "no-meta-agent",
        "config": {
            "systemRole": "System role only.",
            "model": "claude-haiku",
        },
    }


@pytest.fixture()
def lobehub_agent_empty_system_role() -> dict[str, Any]:
    """LobeHub agent with an empty systemRole."""
    return {
        "identifier": "no-system-role",
        "config": {"systemRole": ""},
        "meta": {
            "title": "Silent Agent",
            "description": "An agent with no system prompt.",
        },
    }


# ---------------------------------------------------------------------------
# MCP registry cache fixture
# ---------------------------------------------------------------------------

@pytest.fixture()
def sample_cache_dict() -> dict[str, Any]:
    """A valid mcp-registry cache.json structure."""
    from datetime import datetime, timezone

    cached_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    return {
        "$schema": "../schemas/mcp-registry-cache.schema.json",
        "schema_version": "1.0.0",
        "cached_at": cached_at,
        "ttl_seconds": 86400,
        "registries": {
            "lobehub": {
                "fetched_at": cached_at,
                "success": True,
                "server_count": 2,
                "url": "https://example.com/lobehub",
            },
            "modelcontextprotocol": {
                "fetched_at": cached_at,
                "success": True,
                "server_count": 1,
                "url": "https://example.com/mcp",
            },
        },
        "servers": [
            {
                "identifier": "@lobehub/mcp-web-search",
                "name": "Web Search",
                "registry": "lobehub",
                "cached_at": cached_at,
                "description": "Perform web searches",
                "author": "lobehub",
                "transport": "stdio",
                "categories": ["search"],
                "tags": ["web", "search"],
                "stars": 42,
                "install_config": {
                    "command": "npx",
                    "args": ["-y", "@lobehub/mcp-web-search"],
                    "env": {},
                },
                "last_updated": None,
            },
            {
                "identifier": "@lobehub/mcp-image-gen",
                "name": "Image Generation",
                "registry": "lobehub",
                "cached_at": cached_at,
                "description": "Generate images with AI",
                "author": "lobehub",
                "transport": "stdio",
                "categories": ["image"],
                "tags": ["ai", "image"],
                "stars": 10,
                "install_config": None,
                "last_updated": None,
            },
            {
                "identifier": "@modelcontextprotocol/filesystem",
                "name": "Filesystem",
                "registry": "modelcontextprotocol",
                "cached_at": cached_at,
                "description": "Read and write local files",
                "author": "Anthropic",
                "transport": "stdio",
                "categories": ["utility"],
                "tags": [],
                "stars": None,
                "install_config": {
                    "command": "npx",
                    "args": ["-y", "@modelcontextprotocol/server-filesystem"],
                    "env": {},
                },
                "last_updated": None,
            },
        ],
    }


@pytest.fixture()
def cache_file(tmp_path: Path, sample_cache_dict: dict[str, Any]) -> Path:
    """Write sample_cache_dict to a tmp cache.json and return its path."""
    cache_path = tmp_path / "cache.json"
    cache_path.write_text(json.dumps(sample_cache_dict), encoding="utf-8")
    return cache_path
