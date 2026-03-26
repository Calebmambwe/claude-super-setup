#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["httpx"]
# ///
"""
MCP Registry Fetch — fetch, normalize, and cache MCP server listings.

Fetches from multiple registries (LobeHub, Official MCP Registry, Smithery),
normalizes all entries to a common MCPServerEntry format, and stores a local
cache at ~/.claude/mcp-registry/cache.json with a 24-hour TTL.

Usage:
    uv run --with httpx scripts/mcp-registry-fetch.py
    python scripts/mcp-registry-fetch.py          # if httpx already installed
    python -c "from mcp_registry_fetch import load_cache; ..."  # importable

Environment:
    MCP_REGISTRY_CACHE_DIR  Override default cache directory (~/.claude/mcp-registry)
    MCP_REGISTRY_TTL        Override TTL in seconds (default 86400)
    MCP_REGISTRY_TIMEOUT    HTTP timeout in seconds (default 15)
"""

from __future__ import annotations

import json
import logging
import os
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from urllib.error import URLError
from urllib.request import Request, urlopen

# ---------------------------------------------------------------------------
# Logging setup — structured, level configurable via LOG_LEVEL env var
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s %(levelname)-8s %(name)s — %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger("mcp_registry_fetch")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
CACHE_DIR = Path(
    os.environ.get("MCP_REGISTRY_CACHE_DIR", Path.home() / ".claude" / "mcp-registry")
)
CACHE_FILE = CACHE_DIR / "cache.json"
SCHEMA_VERSION = "1.0.0"
DEFAULT_TTL = int(os.environ.get("MCP_REGISTRY_TTL", 86400))  # 24 h
HTTP_TIMEOUT = int(os.environ.get("MCP_REGISTRY_TIMEOUT", 15))

# Registry URLs — primary + fallback where applicable
LOBEHUB_URLS = [
    "https://registry.npmmirror.com/@lobehub/mcp-servers-index/latest/files/dist/index.json",
    "https://raw.githubusercontent.com/lobehub/lobe-chat-plugins/main/public/index.json",
]
MCP_OFFICIAL_URL = "https://registry.modelcontextprotocol.io/api/v0/servers"
SMITHERY_URL = "https://smithery.ai/api/servers"


# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------
@dataclass
class InstallConfig:
    command: str
    args: list[str] = field(default_factory=list)
    env: dict[str, str] = field(default_factory=dict)


@dataclass
class MCPServerEntry:
    identifier: str
    name: str
    registry: str
    cached_at: str
    description: str | None = None
    author: str | None = None
    registry_url: str | None = None
    transport: str = "stdio"
    categories: list[str] = field(default_factory=list)
    tags: list[str] = field(default_factory=list)
    stars: int | None = None
    install_config: InstallConfig | None = None
    last_updated: str | None = None

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        # Flatten install_config — keep as nested dict (already done by asdict)
        return d


@dataclass
class RegistryMeta:
    fetched_at: str
    success: bool
    server_count: int
    url: str | None = None
    error: str | None = None


@dataclass
class CacheFile:
    schema_version: str
    cached_at: str
    ttl_seconds: int
    registries: dict[str, RegistryMeta]
    servers: list[MCPServerEntry]

    def to_dict(self) -> dict[str, Any]:
        return {
            "$schema": "../schemas/mcp-registry-cache.schema.json",
            "schema_version": self.schema_version,
            "cached_at": self.cached_at,
            "ttl_seconds": self.ttl_seconds,
            "registries": {
                k: {key: val for key, val in asdict(v).items() if val is not None}
                for k, v in self.registries.items()
            },
            "servers": [s.to_dict() for s in self.servers],
        }


# ---------------------------------------------------------------------------
# HTTP helper — uses stdlib urllib to avoid hard dependency when not run via uv
# ---------------------------------------------------------------------------
def _http_get(url: str, timeout: int = HTTP_TIMEOUT) -> Any:
    """Fetch URL and return parsed JSON. Raises on any failure."""
    # Try httpx first (better error messages + HTTP/2), fall back to urllib
    try:
        import httpx  # type: ignore[import]

        response = httpx.get(url, timeout=timeout, follow_redirects=True)
        response.raise_for_status()
        return response.json()
    except ImportError:
        log.debug("httpx not available, falling back to urllib")

    req = Request(url, headers={"User-Agent": "mcp-registry-fetch/1.0 (+claude-super-setup)"})
    try:
        with urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except URLError as exc:
        raise RuntimeError(f"HTTP error fetching {url}: {exc}") from exc


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _safe_str(val: Any) -> str | None:
    if val is None:
        return None
    s = str(val).strip()
    return s if s else None


def _safe_list(val: Any) -> list[str]:
    if isinstance(val, list):
        return [str(x) for x in val if x]
    return []


# ---------------------------------------------------------------------------
# LobeHub normalizer
# ---------------------------------------------------------------------------
def _fetch_lobehub(cached_at: str) -> tuple[list[MCPServerEntry], RegistryMeta]:
    """Try each LobeHub URL in order; return on first success."""
    last_error: str = "no URLs tried"
    for url in LOBEHUB_URLS:
        log.info("Fetching LobeHub registry from %s", url)
        try:
            raw = _http_get(url)
            entries = _normalize_lobehub(raw, cached_at, url)
            meta = RegistryMeta(
                fetched_at=cached_at,
                success=True,
                server_count=len(entries),
                url=url,
            )
            log.info("LobeHub: fetched %d entries", len(entries))
            return entries, meta
        except Exception as exc:
            last_error = str(exc)
            log.warning("LobeHub URL %s failed: %s", url, exc)

    meta = RegistryMeta(
        fetched_at=cached_at,
        success=False,
        server_count=0,
        error=last_error,
    )
    return [], meta


def _normalize_lobehub(raw: Any, cached_at: str, source_url: str) -> list[MCPServerEntry]:
    """Normalize LobeHub index response to MCPServerEntry list."""
    entries: list[MCPServerEntry] = []

    # The LobeHub index may be a list or a dict with a 'plugins'/'items'/'data' key
    items: list[Any] = []
    if isinstance(raw, list):
        items = raw
    elif isinstance(raw, dict):
        for key in ("items", "plugins", "data", "servers", "mcpServers"):
            if isinstance(raw.get(key), list):
                items = raw[key]
                break

    if not items:
        log.warning("LobeHub: unexpected response shape — no list found in payload")
        return entries

    for item in items:
        if not isinstance(item, dict):
            continue
        try:
            identifier = _safe_str(
                item.get("identifier") or item.get("id") or item.get("name") or item.get("npmName")
            )
            if not identifier:
                continue

            # Ensure @lobehub/ prefix if bare name
            if not identifier.startswith("@"):
                identifier = f"@lobehub/{identifier}"

            name = _safe_str(item.get("meta", {}).get("title") or item.get("name") or identifier) or identifier

            description = _safe_str(
                item.get("meta", {}).get("description") or item.get("description")
            )
            author = _safe_str(
                item.get("author") or item.get("meta", {}).get("author")
            )

            tags = _safe_list(item.get("tags") or item.get("meta", {}).get("tags"))
            categories = _safe_list(item.get("categories"))

            stars = None
            if isinstance(item.get("stars"), int):
                stars = item["stars"]

            install_config = _parse_lobehub_install(item)

            entry = MCPServerEntry(
                identifier=identifier,
                name=name,
                description=description,
                author=author,
                registry="lobehub",
                registry_url=_safe_str(item.get("homepage") or item.get("url")),
                transport="stdio",
                categories=categories,
                tags=tags,
                stars=stars,
                install_config=install_config,
                last_updated=_safe_str(item.get("updatedAt") or item.get("updated_at")),
                cached_at=cached_at,
            )
            entries.append(entry)
        except Exception as exc:
            log.warning("LobeHub: skipping malformed item %s: %s", item.get("id", "?"), exc)

    return entries


def _parse_lobehub_install(item: dict[str, Any]) -> InstallConfig | None:
    """Extract install config from a LobeHub item."""
    # Various possible keys
    config = item.get("installConfig") or item.get("install") or item.get("mcpConfig") or {}
    if not isinstance(config, dict):
        return None

    command = _safe_str(config.get("command"))
    if not command:
        # Infer from npmName / identifier
        npm_name = _safe_str(item.get("npmName") or item.get("identifier"))
        if npm_name:
            command = "npx"
            return InstallConfig(
                command=command,
                args=["-y", npm_name],
                env={},
            )
        return None

    args = config.get("args", [])
    if not isinstance(args, list):
        args = []

    env_raw = config.get("env", {})
    env: dict[str, str] = {}
    if isinstance(env_raw, dict):
        env = {k: str(v) for k, v in env_raw.items()}

    return InstallConfig(command=command, args=[str(a) for a in args], env=env)


# ---------------------------------------------------------------------------
# Official MCP Registry normalizer
# ---------------------------------------------------------------------------
def _fetch_mcp_official(cached_at: str) -> tuple[list[MCPServerEntry], RegistryMeta]:
    url = MCP_OFFICIAL_URL
    log.info("Fetching Official MCP Registry from %s", url)
    try:
        raw = _http_get(url)
        entries = _normalize_mcp_official(raw, cached_at, url)
        meta = RegistryMeta(
            fetched_at=cached_at,
            success=True,
            server_count=len(entries),
            url=url,
        )
        log.info("MCP Official: fetched %d entries", len(entries))
        return entries, meta
    except Exception as exc:
        log.warning("MCP Official registry fetch failed: %s", exc)
        return [], RegistryMeta(
            fetched_at=cached_at,
            success=False,
            server_count=0,
            url=url,
            error=str(exc),
        )


def _normalize_mcp_official(raw: Any, cached_at: str, source_url: str) -> list[MCPServerEntry]:
    """Normalize the official MCP registry API response."""
    entries: list[MCPServerEntry] = []

    items: list[Any] = []
    if isinstance(raw, list):
        items = raw
    elif isinstance(raw, dict):
        for key in ("servers", "items", "data", "results"):
            if isinstance(raw.get(key), list):
                items = raw[key]
                break

    if not items:
        log.warning("MCP Official: unexpected response shape")
        return entries

    for item in items:
        if not isinstance(item, dict):
            continue
        try:
            # Official registry uses 'id', 'name', 'description', 'repository', etc.
            identifier = _safe_str(
                item.get("id") or item.get("identifier") or item.get("name")
            )
            if not identifier:
                continue

            if not identifier.startswith("@"):
                identifier = f"@modelcontextprotocol/{identifier}"

            name = _safe_str(item.get("name") or item.get("displayName") or identifier) or identifier

            # Transport detection
            transport_raw = _safe_str(item.get("transport") or item.get("connection_type"))
            transport = _resolve_transport(transport_raw)

            install_config = _parse_mcp_official_install(item)

            entry = MCPServerEntry(
                identifier=identifier,
                name=name,
                description=_safe_str(item.get("description") or item.get("summary")),
                author=_safe_str(
                    item.get("author")
                    or item.get("publisher")
                    or (item.get("repository") or {}).get("owner")
                ),
                registry="modelcontextprotocol",
                registry_url=_safe_str(
                    item.get("url")
                    or item.get("homepage")
                    or (item.get("repository") or {}).get("url")
                ),
                transport=transport,
                categories=_safe_list(item.get("categories") or item.get("tags")),
                tags=_safe_list(item.get("tags")),
                stars=item.get("stars") if isinstance(item.get("stars"), int) else None,
                install_config=install_config,
                last_updated=_safe_str(item.get("updated_at") or item.get("updatedAt")),
                cached_at=cached_at,
            )
            entries.append(entry)
        except Exception as exc:
            log.warning("MCP Official: skipping malformed item %s: %s", item.get("id", "?"), exc)

    return entries


def _parse_mcp_official_install(item: dict[str, Any]) -> InstallConfig | None:
    """Extract install config from an official MCP registry item."""
    # Try various known keys
    for key in ("install", "installConfig", "config", "run"):
        config = item.get(key)
        if isinstance(config, dict) and config.get("command"):
            command = str(config["command"])
            args = [str(a) for a in config.get("args", [])] if isinstance(config.get("args"), list) else []
            env_raw = config.get("env", {})
            env = {k: str(v) for k, v in env_raw.items()} if isinstance(env_raw, dict) else {}
            return InstallConfig(command=command, args=args, env=env)

    # Infer from package name
    pkg = _safe_str(item.get("package") or item.get("npm") or item.get("id"))
    if pkg:
        return InstallConfig(command="npx", args=["-y", pkg], env={})

    return None


# ---------------------------------------------------------------------------
# Smithery normalizer (optional third source)
# ---------------------------------------------------------------------------
def _fetch_smithery(cached_at: str) -> tuple[list[MCPServerEntry], RegistryMeta]:
    url = SMITHERY_URL
    log.info("Fetching Smithery registry from %s", url)
    try:
        raw = _http_get(url)
        entries = _normalize_smithery(raw, cached_at, url)
        meta = RegistryMeta(
            fetched_at=cached_at,
            success=True,
            server_count=len(entries),
            url=url,
        )
        log.info("Smithery: fetched %d entries", len(entries))
        return entries, meta
    except Exception as exc:
        log.warning("Smithery registry fetch failed (optional): %s", exc)
        return [], RegistryMeta(
            fetched_at=cached_at,
            success=False,
            server_count=0,
            url=url,
            error=str(exc),
        )


def _normalize_smithery(raw: Any, cached_at: str, source_url: str) -> list[MCPServerEntry]:
    """Normalize Smithery API response."""
    entries: list[MCPServerEntry] = []

    items: list[Any] = []
    if isinstance(raw, list):
        items = raw
    elif isinstance(raw, dict):
        for key in ("servers", "items", "data", "results", "packages"):
            if isinstance(raw.get(key), list):
                items = raw[key]
                break

    if not items:
        log.warning("Smithery: unexpected response shape")
        return entries

    for item in items:
        if not isinstance(item, dict):
            continue
        try:
            identifier = _safe_str(
                item.get("qualifiedName")
                or item.get("identifier")
                or item.get("id")
                or item.get("name")
            )
            if not identifier:
                continue

            if not identifier.startswith("@"):
                identifier = f"@smithery/{identifier}"

            name = _safe_str(item.get("displayName") or item.get("name") or identifier) or identifier

            transport_raw = _safe_str(item.get("transport") or item.get("connectionType"))
            transport = _resolve_transport(transport_raw)

            # Smithery uses 'useCount' as a proxy for popularity
            stars: int | None = None
            if isinstance(item.get("useCount"), int):
                stars = item["useCount"]
            elif isinstance(item.get("stars"), int):
                stars = item["stars"]

            entry = MCPServerEntry(
                identifier=identifier,
                name=name,
                description=_safe_str(item.get("description") or item.get("summary")),
                author=_safe_str(item.get("owner") or item.get("author") or item.get("publisher")),
                registry="smithery",
                registry_url=f"https://smithery.ai/server/{identifier.lstrip('@')}",
                transport=transport,
                categories=_safe_list(item.get("categories")),
                tags=_safe_list(item.get("tags")),
                stars=stars,
                install_config=_parse_smithery_install(item, identifier),
                last_updated=_safe_str(item.get("updatedAt") or item.get("updated_at")),
                cached_at=cached_at,
            )
            entries.append(entry)
        except Exception as exc:
            log.warning("Smithery: skipping malformed item %s: %s", item.get("id", "?"), exc)

    return entries


def _parse_smithery_install(item: dict[str, Any], identifier: str) -> InstallConfig | None:
    """Extract install config from Smithery item."""
    for key in ("install", "installConfig", "config"):
        config = item.get(key)
        if isinstance(config, dict) and config.get("command"):
            command = str(config["command"])
            args = [str(a) for a in config.get("args", [])] if isinstance(config.get("args"), list) else []
            env_raw = config.get("env", {})
            env = {k: str(v) for k, v in env_raw.items()} if isinstance(env_raw, dict) else {}
            return InstallConfig(command=command, args=args, env=env)

    # Smithery servers are typically installed via npx @smithery/cli
    npm_name = _safe_str(item.get("npmName") or item.get("package"))
    if npm_name:
        return InstallConfig(command="npx", args=["-y", npm_name], env={})

    # Default: use smithery CLI
    return InstallConfig(
        command="npx",
        args=["-y", "@smithery/cli", "run", identifier],
        env={},
    )


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------
def _resolve_transport(raw: str | None) -> str:
    if raw is None:
        return "stdio"
    normalized = raw.lower().strip()
    if normalized in {"stdio", "http", "sse"}:
        return normalized
    if "http" in normalized:
        return "http"
    if "sse" in normalized:
        return "sse"
    return "stdio"


def _deduplicate(servers: list[MCPServerEntry]) -> list[MCPServerEntry]:
    """Remove duplicate identifiers — prefer the first occurrence (registry priority order)."""
    seen: set[str] = set()
    result: list[MCPServerEntry] = []
    for s in servers:
        if s.identifier not in seen:
            seen.add(s.identifier)
            result.append(s)
        else:
            log.debug("Deduplicating %s (keeping first occurrence)", s.identifier)
    return result


# ---------------------------------------------------------------------------
# Cache management
# ---------------------------------------------------------------------------
def _is_cache_fresh(cache_path: Path, ttl: int) -> bool:
    """Return True if the cache file exists and is within TTL."""
    if not cache_path.exists():
        return False
    try:
        with cache_path.open(encoding="utf-8") as fh:
            data = json.load(fh)
        cached_at_str = data.get("cached_at", "")
        cached_at = datetime.fromisoformat(cached_at_str)
        if cached_at.tzinfo is None:
            cached_at = cached_at.replace(tzinfo=timezone.utc)
        age = datetime.now(timezone.utc) - cached_at
        return age < timedelta(seconds=ttl)
    except Exception as exc:
        log.warning("Could not read existing cache for freshness check: %s", exc)
        return False


def _write_cache(cache: CacheFile, path: Path) -> None:
    """Write cache to disk, creating parent dirs as needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with tmp.open("w", encoding="utf-8") as fh:
        json.dump(cache.to_dict(), fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    tmp.replace(path)
    log.info("Cache written to %s (%d servers)", path, len(cache.servers))


def load_cache(cache_path: Path = CACHE_FILE) -> dict[str, Any] | None:
    """Load and return the cache dict, or None if it doesn't exist / is invalid."""
    if not cache_path.exists():
        return None
    try:
        with cache_path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except Exception as exc:
        log.warning("Failed to load cache from %s: %s", cache_path, exc)
        return None


# ---------------------------------------------------------------------------
# Main fetch orchestration
# ---------------------------------------------------------------------------
def fetch_all(
    *,
    force: bool = False,
    ttl: int = DEFAULT_TTL,
    cache_path: Path = CACHE_FILE,
) -> CacheFile:
    """
    Fetch MCP servers from all registries, normalize, deduplicate, and cache.

    Args:
        force: Skip TTL check and always re-fetch.
        ttl: Cache TTL in seconds.
        cache_path: Where to write the cache file.

    Returns:
        CacheFile dataclass with all fetched servers and registry metadata.
    """
    if not force and _is_cache_fresh(cache_path, ttl):
        log.info("Cache is fresh (TTL %ds). Loading from disk.", ttl)
        raw = load_cache(cache_path)
        if raw is not None:
            # Re-hydrate into CacheFile for consistent return type
            log.info("Loaded %d servers from cache", len(raw.get("servers", [])))
            # Return early — callers can use load_cache() directly for dict access
            return _dict_to_cache_file(raw)

    log.info("Fetching MCP registries...")
    cached_at = _now_iso()
    all_servers: list[MCPServerEntry] = []
    registry_metas: dict[str, RegistryMeta] = {}

    # Registry 1: LobeHub
    lobehub_servers, lobehub_meta = _fetch_lobehub(cached_at)
    all_servers.extend(lobehub_servers)
    registry_metas["lobehub"] = lobehub_meta

    # Registry 2: Official MCP Registry
    mcp_servers, mcp_meta = _fetch_mcp_official(cached_at)
    all_servers.extend(mcp_servers)
    registry_metas["modelcontextprotocol"] = mcp_meta

    # Registry 3: Smithery (optional)
    smithery_servers, smithery_meta = _fetch_smithery(cached_at)
    all_servers.extend(smithery_servers)
    registry_metas["smithery"] = smithery_meta

    deduplicated = _deduplicate(all_servers)
    log.info(
        "Total: %d servers before dedup, %d after (from %d registries)",
        len(all_servers),
        len(deduplicated),
        len(registry_metas),
    )

    cache = CacheFile(
        schema_version=SCHEMA_VERSION,
        cached_at=cached_at,
        ttl_seconds=ttl,
        registries=registry_metas,
        servers=deduplicated,
    )
    _write_cache(cache, cache_path)
    return cache


def _dict_to_cache_file(raw: dict[str, Any]) -> CacheFile:
    """Re-hydrate a cache dict into CacheFile (best-effort, for fresh-cache path)."""
    registries: dict[str, RegistryMeta] = {}
    for k, v in raw.get("registries", {}).items():
        registries[k] = RegistryMeta(
            fetched_at=v.get("fetched_at", ""),
            success=v.get("success", False),
            server_count=v.get("server_count", 0),
            url=v.get("url"),
            error=v.get("error"),
        )

    servers: list[MCPServerEntry] = []
    for s in raw.get("servers", []):
        ic_raw = s.get("install_config")
        ic: InstallConfig | None = None
        if isinstance(ic_raw, dict) and ic_raw.get("command"):
            ic = InstallConfig(
                command=ic_raw["command"],
                args=ic_raw.get("args", []),
                env=ic_raw.get("env", {}),
            )
        servers.append(
            MCPServerEntry(
                identifier=s.get("identifier", ""),
                name=s.get("name", ""),
                description=s.get("description"),
                author=s.get("author"),
                registry=s.get("registry", "unknown"),
                registry_url=s.get("registry_url"),
                transport=s.get("transport", "stdio"),
                categories=s.get("categories", []),
                tags=s.get("tags", []),
                stars=s.get("stars"),
                install_config=ic,
                last_updated=s.get("last_updated"),
                cached_at=s.get("cached_at", ""),
            )
        )

    return CacheFile(
        schema_version=raw.get("schema_version", SCHEMA_VERSION),
        cached_at=raw.get("cached_at", ""),
        ttl_seconds=raw.get("ttl_seconds", DEFAULT_TTL),
        registries=registries,
        servers=servers,
    )


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
def _cli() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        description="Fetch and cache MCP server listings from multiple registries.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ignore TTL and re-fetch even if cache is fresh",
    )
    parser.add_argument(
        "--cache-path",
        type=Path,
        default=CACHE_FILE,
        help=f"Path to cache file (default: {CACHE_FILE})",
    )
    parser.add_argument(
        "--ttl",
        type=int,
        default=DEFAULT_TTL,
        help=f"Cache TTL in seconds (default: {DEFAULT_TTL})",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Print a summary of cached servers to stdout",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="output_json",
        help="Output the full cache as JSON to stdout",
    )
    args = parser.parse_args()

    cache = fetch_all(force=args.force, ttl=args.ttl, cache_path=args.cache_path)

    if args.output_json:
        print(json.dumps(cache.to_dict(), indent=2, ensure_ascii=False))
        return

    if args.list:
        print(f"\n{'Registry':<22} {'Transport':<10} {'Name'}")
        print("-" * 70)
        for s in cache.servers:
            print(f"{s.registry:<22} {s.transport:<10} {s.name}  [{s.identifier}]")
        print(f"\nTotal: {len(cache.servers)} servers")
        return

    # Default: summary
    successful = sum(1 for m in cache.registries.values() if m.success)
    total = len(cache.registries)
    print(
        f"\nFetched {len(cache.servers)} MCP servers from {successful}/{total} registries."
    )
    for name, meta in cache.registries.items():
        status = "OK" if meta.success else f"FAILED ({meta.error or 'unknown error'})"
        print(f"  {name:<25} {status}  ({meta.server_count} servers)")
    print(f"\nCache: {args.cache_path}")


if __name__ == "__main__":
    _cli()
