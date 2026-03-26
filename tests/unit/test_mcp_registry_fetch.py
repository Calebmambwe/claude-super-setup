"""
Unit tests for scripts/mcp-registry-fetch.py

Tests target pure-logic helpers — no real HTTP calls are made.
Run independently:
    pytest tests/unit/test_mcp_registry_fetch.py -v
"""
from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from unittest import mock

import pytest

# ---------------------------------------------------------------------------
# Source import
# ---------------------------------------------------------------------------
_REPO_ROOT = Path(__file__).resolve().parents[2]
_SCRIPTS_DIR = str(_REPO_ROOT / "scripts")
if _SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, _SCRIPTS_DIR)

import importlib.util as _ilu

_spec = _ilu.spec_from_file_location(
    "mcp_registry_fetch",
    _REPO_ROOT / "scripts" / "mcp-registry-fetch.py",
)
assert _spec and _spec.loader
_mrf = _ilu.module_from_spec(_spec)
sys.modules["mcp_registry_fetch"] = _mrf
_spec.loader.exec_module(_mrf)  # type: ignore[union-attr]

# Helpers under test
_is_cache_fresh = _mrf._is_cache_fresh
_write_cache = _mrf._write_cache
load_cache = _mrf.load_cache
_deduplicate = _mrf._deduplicate
_normalize_lobehub = _mrf._normalize_lobehub
_normalize_mcp_official = _mrf._normalize_mcp_official
_normalize_smithery = _mrf._normalize_smithery
_resolve_transport = _mrf._resolve_transport
_safe_str = _mrf._safe_str
_safe_list = _mrf._safe_list
_fetch_lobehub = _mrf._fetch_lobehub
_fetch_mcp_official = _mrf._fetch_mcp_official
_dict_to_cache_file = _mrf._dict_to_cache_file
CacheFile = _mrf.CacheFile
MCPServerEntry = _mrf.MCPServerEntry
RegistryMeta = _mrf.RegistryMeta
InstallConfig = _mrf.InstallConfig
SCHEMA_VERSION = _mrf.SCHEMA_VERSION


# ===========================================================================
# Helpers
# ===========================================================================

def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _entry(identifier: str = "@test/server", registry: str = "test") -> MCPServerEntry:
    return MCPServerEntry(
        identifier=identifier,
        name="Test Server",
        registry=registry,
        cached_at=_now(),
    )


# ===========================================================================
# _is_cache_fresh
# ===========================================================================

class TestIsCacheFresh:
    def test_missing_file_is_stale(self, tmp_path: Path) -> None:
        cache_path = tmp_path / "cache.json"
        assert _is_cache_fresh(cache_path, ttl=86400) is False

    def test_fresh_cache_is_fresh(self, tmp_path: Path) -> None:
        cached_at = _now()  # right now → well within TTL
        data = {"cached_at": cached_at}
        cache_path = tmp_path / "cache.json"
        cache_path.write_text(json.dumps(data), encoding="utf-8")
        assert _is_cache_fresh(cache_path, ttl=86400) is True

    def test_expired_cache_is_stale(self, tmp_path: Path) -> None:
        # cached_at is 2 days ago
        old = (datetime.now(timezone.utc) - timedelta(days=2)).isoformat(timespec="seconds")
        data = {"cached_at": old}
        cache_path = tmp_path / "cache.json"
        cache_path.write_text(json.dumps(data), encoding="utf-8")
        assert _is_cache_fresh(cache_path, ttl=86400) is False

    def test_exactly_at_boundary_is_stale(self, tmp_path: Path) -> None:
        # cached_at exactly TTL seconds ago — age == timedelta(seconds=ttl) → NOT fresh
        ttl = 3600
        at_boundary = (datetime.now(timezone.utc) - timedelta(seconds=ttl)).isoformat(timespec="seconds")
        data = {"cached_at": at_boundary}
        cache_path = tmp_path / "cache.json"
        cache_path.write_text(json.dumps(data), encoding="utf-8")
        # age >= ttl means stale
        assert _is_cache_fresh(cache_path, ttl=ttl) is False

    def test_corrupt_cache_returns_false(self, tmp_path: Path) -> None:
        cache_path = tmp_path / "cache.json"
        cache_path.write_text("not json at all {{{", encoding="utf-8")
        assert _is_cache_fresh(cache_path, ttl=86400) is False

    def test_missing_cached_at_field_returns_false(self, tmp_path: Path) -> None:
        cache_path = tmp_path / "cache.json"
        cache_path.write_text(json.dumps({"schema_version": "1.0.0"}), encoding="utf-8")
        assert _is_cache_fresh(cache_path, ttl=86400) is False


# ===========================================================================
# _write_cache / load_cache
# ===========================================================================

class TestWriteAndLoadCache:
    def _make_cache(self) -> CacheFile:
        now = _now()
        return CacheFile(
            schema_version=SCHEMA_VERSION,
            cached_at=now,
            ttl_seconds=86400,
            registries={
                "lobehub": RegistryMeta(fetched_at=now, success=True, server_count=1),
            },
            servers=[_entry()],
        )

    def test_write_creates_file(self, tmp_path: Path) -> None:
        cache_path = tmp_path / "sub" / "cache.json"
        cache = self._make_cache()
        _write_cache(cache, cache_path)
        assert cache_path.exists()

    def test_write_creates_parent_dirs(self, tmp_path: Path) -> None:
        cache_path = tmp_path / "deep" / "nested" / "cache.json"
        _write_cache(self._make_cache(), cache_path)
        assert cache_path.exists()

    def test_written_file_is_valid_json(self, tmp_path: Path) -> None:
        cache_path = tmp_path / "cache.json"
        _write_cache(self._make_cache(), cache_path)
        with cache_path.open(encoding="utf-8") as fh:
            data = json.load(fh)
        assert isinstance(data, dict)

    def test_written_file_has_schema_version(self, tmp_path: Path) -> None:
        cache_path = tmp_path / "cache.json"
        _write_cache(self._make_cache(), cache_path)
        data = json.loads(cache_path.read_text(encoding="utf-8"))
        assert data["schema_version"] == SCHEMA_VERSION

    def test_written_file_contains_servers(self, tmp_path: Path) -> None:
        cache_path = tmp_path / "cache.json"
        _write_cache(self._make_cache(), cache_path)
        data = json.loads(cache_path.read_text(encoding="utf-8"))
        assert len(data["servers"]) == 1

    def test_load_cache_returns_dict(self, cache_file: Path) -> None:
        result = load_cache(cache_file)
        assert isinstance(result, dict)

    def test_load_cache_returns_none_for_missing(self, tmp_path: Path) -> None:
        assert load_cache(tmp_path / "nonexistent.json") is None

    def test_load_cache_returns_none_for_corrupt(self, tmp_path: Path) -> None:
        bad = tmp_path / "bad.json"
        bad.write_text("{ not valid json", encoding="utf-8")
        assert load_cache(bad) is None

    def test_roundtrip_server_count(self, tmp_path: Path) -> None:
        cache_path = tmp_path / "cache.json"
        cache = self._make_cache()
        _write_cache(cache, cache_path)
        loaded = load_cache(cache_path)
        assert loaded is not None
        assert len(loaded["servers"]) == len(cache.servers)


# ===========================================================================
# _deduplicate
# ===========================================================================

class TestDeduplicate:
    def test_no_duplicates_unchanged(self) -> None:
        servers = [_entry("@a/s1"), _entry("@b/s2"), _entry("@c/s3")]
        result = _deduplicate(servers)
        assert len(result) == 3

    def test_duplicate_identifier_removed(self) -> None:
        servers = [
            _entry("@a/dup", "registry1"),
            _entry("@b/unique"),
            _entry("@a/dup", "registry2"),  # duplicate
        ]
        result = _deduplicate(servers)
        assert len(result) == 2

    def test_first_occurrence_kept(self) -> None:
        s1 = MCPServerEntry(identifier="@x/s", name="First", registry="r1", cached_at=_now())
        s2 = MCPServerEntry(identifier="@x/s", name="Second", registry="r2", cached_at=_now())
        result = _deduplicate([s1, s2])
        assert len(result) == 1
        assert result[0].name == "First"

    def test_empty_list_returns_empty(self) -> None:
        assert _deduplicate([]) == []


# ===========================================================================
# _normalize_lobehub
# ===========================================================================

class TestNormalizeLobehub:
    def _base_item(self) -> dict[str, Any]:
        return {
            "identifier": "my-tool",
            "meta": {
                "title": "My Tool",
                "description": "Does something useful",
                "tags": ["utility"],
            },
            "author": "author1",
            "homepage": "https://example.com",
        }

    def test_parses_identifier(self) -> None:
        raw = {"items": [self._base_item()]}
        entries = _normalize_lobehub(raw, _now(), "https://test.com")
        assert len(entries) == 1
        assert entries[0].identifier == "@lobehub/my-tool"

    def test_prefixes_at_lobehub(self) -> None:
        item = self._base_item()
        item["identifier"] = "bare-name"
        entries = _normalize_lobehub({"items": [item]}, _now(), "https://test.com")
        assert entries[0].identifier.startswith("@lobehub/")

    def test_already_prefixed_unchanged(self) -> None:
        item = self._base_item()
        item["identifier"] = "@myorg/mytool"
        entries = _normalize_lobehub({"items": [item]}, _now(), "https://test.com")
        assert entries[0].identifier == "@myorg/mytool"

    def test_skips_item_without_identifier(self) -> None:
        item = {"meta": {"title": "No ID"}}
        entries = _normalize_lobehub({"items": [item]}, _now(), "https://test.com")
        assert entries == []

    def test_list_payload_parsed(self) -> None:
        raw_list = [self._base_item()]
        entries = _normalize_lobehub(raw_list, _now(), "https://test.com")
        assert len(entries) == 1

    def test_dict_with_plugins_key(self) -> None:
        raw = {"plugins": [self._base_item()]}
        entries = _normalize_lobehub(raw, _now(), "https://test.com")
        assert len(entries) == 1

    def test_empty_payload_returns_empty(self) -> None:
        entries = _normalize_lobehub({}, _now(), "https://test.com")
        assert entries == []

    def test_tags_extracted(self) -> None:
        entries = _normalize_lobehub({"items": [self._base_item()]}, _now(), "https://test.com")
        assert "utility" in entries[0].tags

    def test_stars_extracted_when_int(self) -> None:
        item = self._base_item()
        item["stars"] = 99
        entries = _normalize_lobehub({"items": [item]}, _now(), "https://test.com")
        assert entries[0].stars == 99

    def test_install_config_inferred_from_npm_name(self) -> None:
        item = self._base_item()
        item["npmName"] = "@lobehub/my-tool"
        entries = _normalize_lobehub({"items": [item]}, _now(), "https://test.com")
        ic = entries[0].install_config
        assert ic is not None
        assert ic.command == "npx"
        assert "@lobehub/my-tool" in ic.args

    def test_registry_is_lobehub(self) -> None:
        entries = _normalize_lobehub({"items": [self._base_item()]}, _now(), "https://test.com")
        assert entries[0].registry == "lobehub"


# ===========================================================================
# _normalize_mcp_official
# ===========================================================================

class TestNormalizeMcpOfficial:
    def _base_item(self) -> dict[str, Any]:
        return {
            "id": "filesystem",
            "name": "Filesystem",
            "description": "Read and write local files",
            "author": "Anthropic",
        }

    def test_prefixes_at_modelcontextprotocol(self) -> None:
        raw = {"servers": [self._base_item()]}
        entries = _normalize_mcp_official(raw, _now(), "https://test.com")
        assert entries[0].identifier == "@modelcontextprotocol/filesystem"

    def test_list_payload(self) -> None:
        entries = _normalize_mcp_official([self._base_item()], _now(), "https://test.com")
        assert len(entries) == 1

    def test_skips_missing_identifier(self) -> None:
        entries = _normalize_mcp_official({"servers": [{"description": "orphan"}]}, _now(), "https://test.com")
        assert entries == []

    def test_registry_is_modelcontextprotocol(self) -> None:
        entries = _normalize_mcp_official({"servers": [self._base_item()]}, _now(), "https://test.com")
        assert entries[0].registry == "modelcontextprotocol"

    def test_install_config_from_package(self) -> None:
        item = self._base_item()
        item["package"] = "@mcp/filesystem"
        entries = _normalize_mcp_official({"servers": [item]}, _now(), "https://test.com")
        ic = entries[0].install_config
        assert ic is not None
        assert ic.command == "npx"

    def test_transport_resolved(self) -> None:
        item = self._base_item()
        item["transport"] = "http"
        entries = _normalize_mcp_official({"servers": [item]}, _now(), "https://test.com")
        assert entries[0].transport == "http"


# ===========================================================================
# _normalize_smithery
# ===========================================================================

class TestNormalizeSmithery:
    def _base_item(self) -> dict[str, Any]:
        return {
            "qualifiedName": "myorg/my-server",
            "displayName": "My Server",
            "description": "A useful server",
            "owner": "myorg",
        }

    def test_prefixes_at_smithery(self) -> None:
        raw = {"servers": [self._base_item()]}
        entries = _normalize_smithery(raw, _now(), "https://smithery.ai")
        assert entries[0].identifier == "@smithery/myorg/my-server"

    def test_already_prefixed_unchanged(self) -> None:
        item = self._base_item()
        item["qualifiedName"] = "@myorg/my-server"
        entries = _normalize_smithery({"servers": [item]}, _now(), "https://smithery.ai")
        assert entries[0].identifier == "@myorg/my-server"

    def test_registry_url_constructed(self) -> None:
        entries = _normalize_smithery({"servers": [self._base_item()]}, _now(), "https://smithery.ai")
        assert "smithery.ai/server/" in entries[0].registry_url  # type: ignore[operator]

    def test_use_count_used_as_stars(self) -> None:
        item = self._base_item()
        item["useCount"] = 500
        entries = _normalize_smithery({"servers": [item]}, _now(), "https://smithery.ai")
        assert entries[0].stars == 500

    def test_default_install_config_uses_smithery_cli(self) -> None:
        entries = _normalize_smithery({"servers": [self._base_item()]}, _now(), "https://smithery.ai")
        ic = entries[0].install_config
        assert ic is not None
        assert ic.command == "npx"
        assert "@smithery/cli" in ic.args


# ===========================================================================
# _resolve_transport
# ===========================================================================

class TestResolveTransport:
    def test_none_defaults_to_stdio(self) -> None:
        assert _resolve_transport(None) == "stdio"

    def test_stdio(self) -> None:
        assert _resolve_transport("stdio") == "stdio"

    def test_http(self) -> None:
        assert _resolve_transport("http") == "http"

    def test_sse(self) -> None:
        assert _resolve_transport("sse") == "sse"

    def test_http_variant(self) -> None:
        assert _resolve_transport("HTTP/2") == "http"

    def test_unknown_defaults_to_stdio(self) -> None:
        assert _resolve_transport("websocket") == "stdio"

    def test_case_insensitive(self) -> None:
        assert _resolve_transport("STDIO") == "stdio"
        assert _resolve_transport("HTTP") == "http"


# ===========================================================================
# _safe_str / _safe_list
# ===========================================================================

class TestSafeHelpers:
    def test_safe_str_none(self) -> None:
        assert _safe_str(None) is None

    def test_safe_str_empty_string(self) -> None:
        assert _safe_str("   ") is None

    def test_safe_str_non_empty(self) -> None:
        assert _safe_str(" hello ") == "hello"

    def test_safe_str_non_string(self) -> None:
        assert _safe_str(42) == "42"

    def test_safe_list_list(self) -> None:
        assert _safe_list(["a", "b"]) == ["a", "b"]

    def test_safe_list_non_list(self) -> None:
        assert _safe_list("not a list") == []

    def test_safe_list_filters_falsy(self) -> None:
        assert _safe_list(["a", None, "", "b"]) == ["a", "b"]


# ===========================================================================
# Graceful failure per registry (mock HTTP errors)
# ===========================================================================

class TestGracefulRegistryFailure:
    def test_lobehub_failure_returns_empty_with_error_meta(self) -> None:
        with mock.patch.object(_mrf, "_http_get", side_effect=RuntimeError("connection refused")):
            entries, meta = _fetch_lobehub(_now())
        assert entries == []
        assert meta.success is False
        assert meta.error is not None

    def test_mcp_official_failure_returns_empty_with_error_meta(self) -> None:
        with mock.patch.object(_mrf, "_http_get", side_effect=RuntimeError("timeout")):
            entries, meta = _fetch_mcp_official(_now())
        assert entries == []
        assert meta.success is False
        assert meta.server_count == 0

    def test_lobehub_falls_back_to_second_url(self) -> None:
        """First LobeHub URL fails, second should be attempted."""
        call_count = 0

        def _flaky(url: str, **_kwargs: Any) -> Any:
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                raise RuntimeError("first URL failed")
            # Second call returns a valid (empty) response
            return {"items": []}

        with mock.patch.object(_mrf, "_http_get", side_effect=_flaky):
            entries, meta = _fetch_lobehub(_now())

        # Should have called _http_get twice and succeeded on the second
        assert call_count == 2
        assert meta.success is True


# ===========================================================================
# Cache format validation (_dict_to_cache_file)
# ===========================================================================

class TestDictToCacheFile:
    def test_roundtrips_schema_version(self, sample_cache_dict: dict[str, Any]) -> None:
        cache = _dict_to_cache_file(sample_cache_dict)
        assert cache.schema_version == "1.0.0"

    def test_roundtrips_server_count(self, sample_cache_dict: dict[str, Any]) -> None:
        cache = _dict_to_cache_file(sample_cache_dict)
        assert len(cache.servers) == len(sample_cache_dict["servers"])

    def test_roundtrips_install_config(self, sample_cache_dict: dict[str, Any]) -> None:
        cache = _dict_to_cache_file(sample_cache_dict)
        server_with_ic = next(s for s in cache.servers if s.install_config is not None)
        assert server_with_ic.install_config.command == "npx"

    def test_registry_metas_hydrated(self, sample_cache_dict: dict[str, Any]) -> None:
        cache = _dict_to_cache_file(sample_cache_dict)
        assert "lobehub" in cache.registries
        assert cache.registries["lobehub"].success is True

    def test_missing_install_config_is_none(self, sample_cache_dict: dict[str, Any]) -> None:
        cache = _dict_to_cache_file(sample_cache_dict)
        server_no_ic = next(s for s in cache.servers if s.install_config is None)
        assert server_no_ic.install_config is None

    def test_ttl_preserved(self, sample_cache_dict: dict[str, Any]) -> None:
        cache = _dict_to_cache_file(sample_cache_dict)
        assert cache.ttl_seconds == 86400
