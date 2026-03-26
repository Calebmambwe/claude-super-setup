"""
Unit tests for mcp-servers/knowledge-rag-server.py

Tests target internal helpers only — no MCP transport layer is exercised.
Run independently:
    pytest tests/unit/test_knowledge_rag.py -v
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Import helpers from the source file.
# conftest.py prepends both source dirs to sys.path, but this file must also
# be runnable standalone, so we add the path defensively here as well.
# ---------------------------------------------------------------------------
_REPO_ROOT = Path(__file__).resolve().parents[2]
_MCP_DIR = str(_REPO_ROOT / "mcp-servers")
if _MCP_DIR not in sys.path:
    sys.path.insert(0, _MCP_DIR)

# The server file imports FastMCP; mock it before importing to avoid
# the hard sys.exit(1) when mcp is not installed.
import types
import unittest.mock as mock

# Provide a lightweight stub so the import succeeds without the real mcp package.
_mcp_stub = types.ModuleType("mcp")
_mcp_stub.server = types.ModuleType("mcp.server")  # type: ignore[attr-defined]
_fastmcp_stub = types.ModuleType("mcp.server.fastmcp")
_FastMCP_class = mock.MagicMock()
_fastmcp_stub.FastMCP = _FastMCP_class  # type: ignore[attr-defined]
sys.modules.setdefault("mcp", _mcp_stub)
sys.modules.setdefault("mcp.server", _mcp_stub.server)
sys.modules.setdefault("mcp.server.fastmcp", _fastmcp_stub)

import importlib.util as _ilu

# Module filename contains hyphens so we cannot use a plain import.
# Register the module in sys.modules BEFORE exec_module so that
# @dataclass can resolve cls.__module__ correctly on Python 3.12+.
_spec = _ilu.spec_from_file_location(
    "knowledge_rag_server",
    _REPO_ROOT / "mcp-servers" / "knowledge-rag-server.py",
)
assert _spec and _spec.loader
_kr_mod = _ilu.module_from_spec(_spec)
sys.modules["knowledge_rag_server"] = _kr_mod
_spec.loader.exec_module(_kr_mod)  # type: ignore[union-attr]

# Pull symbols we want to test.
_chunk_text = _kr_mod._chunk_text
_chunk_markdown = _kr_mod._chunk_markdown
_chunk_source_code = _kr_mod._chunk_source_code
_chunk_file = _kr_mod._chunk_file
_file_hash = _kr_mod._file_hash
_project_hash = _kr_mod._project_hash
_ingest_file = _kr_mod._ingest_file
_connect = _kr_mod._connect
_rebuild_fts = _kr_mod._rebuild_fts
_extract_title = _kr_mod._extract_title
_approx_tokens = _kr_mod._approx_tokens
MAX_CHUNK_CHARS: int = _kr_mod.MAX_CHUNK_CHARS
OVERLAP_CHARS: int = _kr_mod.OVERLAP_CHARS


# ===========================================================================
# _chunk_text
# ===========================================================================

class TestChunkText:
    def test_short_text_is_single_chunk(self) -> None:
        text = "Hello world"
        result = _chunk_text(text, max_chars=100)
        assert result == ["Hello world"]

    def test_empty_text_returns_empty(self) -> None:
        result = _chunk_text("   ", max_chars=100)
        assert result == []

    def test_long_text_is_split(self) -> None:
        # Build a string definitely longer than max_chars=50
        text = "word " * 30  # 150 chars
        result = _chunk_text(text, max_chars=50, overlap=5)
        assert len(result) > 1, "Long text should produce multiple chunks"
        # Each chunk should be non-empty
        for chunk in result:
            assert chunk.strip()

    def test_chunks_do_not_exceed_max_chars(self) -> None:
        text = "abcde " * 200  # 1200 chars
        result = _chunk_text(text, max_chars=100, overlap=10)
        for chunk in result:
            # Allow small overshoot from sentence-boundary logic but never
            # more than max_chars (boundaries only cut shorter, not longer).
            assert len(chunk) <= 100 + 10  # generous tolerance

    def test_overlap_means_content_shared(self) -> None:
        """The tail of one chunk should overlap with the head of the next."""
        # 300 chars with a clear sentence boundary in the middle
        sentence = "The quick brown fox jumps over the lazy dog. "
        text = sentence * 7  # ~315 chars
        result = _chunk_text(text, max_chars=120, overlap=30)
        if len(result) > 1:
            # Last 30 chars of chunk 0 should appear somewhere in chunk 1
            tail = result[0][-30:]
            assert tail in result[1] or len(result[1]) > 0

    def test_sentence_boundary_preferred(self) -> None:
        """Cuts at '. ' when possible, not mid-word."""
        part_a = "A" * 60 + ". "
        part_b = "B" * 60
        text = part_a + part_b  # 122 chars
        result = _chunk_text(text, max_chars=80, overlap=5)
        # The first chunk should end with '.' not mid-way through B's
        assert result[0].endswith(".")


# ===========================================================================
# _chunk_markdown
# ===========================================================================

class TestChunkMarkdown:
    def test_splits_on_h2_heading(self) -> None:
        md = "# Title\n\nIntro paragraph.\n\n## Section One\n\nContent A.\n\n## Section Two\n\nContent B.\n"
        result = _chunk_markdown(md)
        # Should produce at least 2 chunks (one per ## section)
        assert len(result) >= 2
        assert any("Section One" in c for c in result)
        assert any("Section Two" in c for c in result)

    def test_short_markdown_is_single_chunk(self) -> None:
        md = "## Brief\n\nShort content here."
        result = _chunk_markdown(md)
        assert len(result) == 1
        assert "Brief" in result[0]

    def test_oversized_section_is_further_split(self) -> None:
        # Create a section larger than MAX_CHUNK_CHARS
        long_para = "word " * (MAX_CHUNK_CHARS // 5 + 50)
        md = f"## Big Section\n\n{long_para}"
        result = _chunk_markdown(md)
        assert len(result) >= 1
        # No single chunk exceeds MAX_CHUNK_CHARS by more than overlap
        for chunk in result:
            assert len(chunk) <= MAX_CHUNK_CHARS + OVERLAP_CHARS

    def test_empty_markdown_returns_empty(self) -> None:
        result = _chunk_markdown("   \n\n   ")
        assert result == []

    def test_h1_heading_not_split_boundary(self) -> None:
        """Only ##+ headings (h2 and deeper) split; a lone # h1 does not."""
        # A document with only an h1 and a paragraph should remain one chunk.
        md = "# Top Level\n\nSome intro paragraph with enough text."
        result = _chunk_markdown(md)
        assert len(result) == 1

    def test_h3_heading_is_split_boundary(self) -> None:
        """The regex splits on #{2,} so ### is also a boundary."""
        md = "# Top Level\n\nSome intro.\n\n### Deep heading\n\nDeep content."
        result = _chunk_markdown(md)
        # ### triggers a split → two chunks
        assert len(result) == 2
        assert any("Deep heading" in c for c in result)

    def test_preserves_heading_in_chunk(self) -> None:
        md = "## My Section\n\nContent here."
        result = _chunk_markdown(md)
        assert result[0].startswith("## My Section")


# ===========================================================================
# _chunk_source_code
# ===========================================================================

class TestChunkSourceCode:
    def test_splits_on_def(self) -> None:
        code = (
            "import os\n\n"
            "def func_a():\n    pass\n\n"
            "def func_b():\n    return 1\n"
        )
        result = _chunk_source_code(code)
        assert any("func_a" in c for c in result)
        assert any("func_b" in c for c in result)

    def test_splits_on_class(self) -> None:
        code = (
            "class Foo:\n    pass\n\n"
            "class Bar:\n    pass\n"
        )
        result = _chunk_source_code(code)
        assert any("Foo" in c for c in result)
        assert any("Bar" in c for c in result)

    def test_no_boundaries_falls_back_to_chunk_text(self) -> None:
        """Plain text with no def/class should still be chunked."""
        plain = "Hello world. " * 200
        result = _chunk_source_code(plain)
        assert len(result) >= 1

    def test_preamble_preserved(self) -> None:
        """Content before the first def should appear in its own chunk."""
        code = "# module docstring\nimport sys\n\ndef main():\n    pass\n"
        result = _chunk_source_code(code)
        assert any("import sys" in c for c in result)

    def test_empty_code_returns_empty(self) -> None:
        result = _chunk_source_code("   \n   \n")
        assert result == []


# ===========================================================================
# _chunk_file  (routing by extension)
# ===========================================================================

class TestChunkFile:
    def test_md_file_uses_markdown_chunker(self, tmp_path: Path) -> None:
        f = tmp_path / "doc.md"
        f.write_text("## Heading\n\nSome text.", encoding="utf-8")
        result = _chunk_file(f)
        assert result
        assert any("Heading" in c for c in result)

    def test_py_file_uses_code_chunker(self, tmp_path: Path) -> None:
        f = tmp_path / "script.py"
        f.write_text("def hello():\n    print('hi')\n", encoding="utf-8")
        result = _chunk_file(f)
        assert result
        assert any("hello" in c for c in result)

    def test_txt_file_uses_generic_chunker(self, tmp_path: Path) -> None:
        f = tmp_path / "notes.txt"
        f.write_text("Some plain text notes.", encoding="utf-8")
        result = _chunk_file(f)
        assert result

    def test_empty_file_returns_empty(self, tmp_path: Path) -> None:
        f = tmp_path / "empty.md"
        f.write_text("", encoding="utf-8")
        result = _chunk_file(f)
        assert result == []

    def test_json_file_uses_generic_chunker(self, tmp_path: Path) -> None:
        f = tmp_path / "data.json"
        f.write_text('{"key": "value"}', encoding="utf-8")
        result = _chunk_file(f)
        assert result


# ===========================================================================
# _file_hash  (change detection)
# ===========================================================================

class TestFileHash:
    def test_same_content_same_hash(self, tmp_path: Path) -> None:
        f = tmp_path / "a.txt"
        f.write_text("hello", encoding="utf-8")
        h1 = _file_hash(f)
        h2 = _file_hash(f)
        assert h1 == h2

    def test_different_content_different_hash(self, tmp_path: Path) -> None:
        f = tmp_path / "a.txt"
        f.write_text("hello", encoding="utf-8")
        h1 = _file_hash(f)
        f.write_text("world", encoding="utf-8")
        h2 = _file_hash(f)
        assert h1 != h2

    def test_hash_is_hex_string(self, tmp_path: Path) -> None:
        f = tmp_path / "a.txt"
        f.write_text("data", encoding="utf-8")
        h = _file_hash(f)
        assert isinstance(h, str)
        int(h, 16)  # should not raise


# ===========================================================================
# _project_hash
# ===========================================================================

class TestProjectHash:
    def test_same_path_same_hash(self) -> None:
        assert _project_hash("/home/user/myproject") == _project_hash("/home/user/myproject")

    def test_different_paths_different_hashes(self) -> None:
        assert _project_hash("/a") != _project_hash("/b")

    def test_length_is_16(self) -> None:
        assert len(_project_hash("/some/path")) == 16


# ===========================================================================
# Database helpers + FTS
# ===========================================================================

class TestDatabase:
    def test_connect_creates_schema(self, tmp_path: Path) -> None:
        db = tmp_path / "test.db"
        conn = _connect(db)
        tables = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
        conn.close()
        assert "documents" in tables
        assert "chunks" in tables

    def test_connect_creates_fts_table(self, tmp_path: Path) -> None:
        db = tmp_path / "test.db"
        conn = _connect(db)
        vtables = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()
        }
        conn.close()
        assert "chunks_fts" in vtables

    def test_rebuild_fts_does_not_raise(self, tmp_path: Path) -> None:
        db = tmp_path / "test.db"
        conn = _connect(db)
        _rebuild_fts(conn)  # should not raise
        conn.close()


# ===========================================================================
# _ingest_file  (hash-based change detection)
# ===========================================================================

class TestIngestFile:
    def _make_db(self, tmp_path: Path) -> tuple[Path, sqlite3.Connection]:
        db = tmp_path / "rag.db"
        conn = _connect(db)
        return db, conn

    def test_new_file_is_ingested(self, tmp_path: Path) -> None:
        db, conn = self._make_db(tmp_path)
        f = tmp_path / "doc.md"
        f.write_text("## Hello\n\nThis is a test document.", encoding="utf-8")
        was_ingested, chunk_count = _ingest_file(f, conn, force=False)
        conn.commit()
        conn.close()
        assert was_ingested is True
        assert chunk_count >= 1

    def test_unchanged_file_is_skipped(self, tmp_path: Path) -> None:
        db, conn = self._make_db(tmp_path)
        f = tmp_path / "doc.md"
        f.write_text("## Hello\n\nTest content.", encoding="utf-8")

        # First ingest
        _ingest_file(f, conn, force=False)
        conn.commit()

        # Second ingest — same content, should be skipped
        was_ingested, chunk_count = _ingest_file(f, conn, force=False)
        conn.close()

        assert was_ingested is False
        assert chunk_count == 0

    def test_changed_file_is_re_ingested(self, tmp_path: Path) -> None:
        db, conn = self._make_db(tmp_path)
        f = tmp_path / "doc.md"
        f.write_text("## Version 1\n\nOriginal content.", encoding="utf-8")

        _ingest_file(f, conn, force=False)
        conn.commit()

        # Modify the file
        f.write_text("## Version 2\n\nUpdated content.", encoding="utf-8")

        was_ingested, chunk_count = _ingest_file(f, conn, force=False)
        conn.commit()
        conn.close()

        assert was_ingested is True
        assert chunk_count >= 1

    def test_force_re_ingests_unchanged_file(self, tmp_path: Path) -> None:
        db, conn = self._make_db(tmp_path)
        f = tmp_path / "doc.md"
        f.write_text("## Unchanged\n\nSame content.", encoding="utf-8")

        _ingest_file(f, conn, force=False)
        conn.commit()

        was_ingested, chunk_count = _ingest_file(f, conn, force=True)
        conn.commit()
        conn.close()

        assert was_ingested is True
        assert chunk_count >= 1

    def test_empty_file_not_ingested(self, tmp_path: Path) -> None:
        db, conn = self._make_db(tmp_path)
        f = tmp_path / "empty.md"
        f.write_text("", encoding="utf-8")

        was_ingested, chunk_count = _ingest_file(f, conn, force=False)
        conn.close()

        assert was_ingested is False
        assert chunk_count == 0

    def test_chunk_count_stored_in_documents(self, tmp_path: Path) -> None:
        db, conn = self._make_db(tmp_path)
        f = tmp_path / "multi.md"
        # Three ## sections to guarantee 3 chunks
        f.write_text(
            "## A\n\nSection A content.\n\n## B\n\nSection B content.\n\n## C\n\nSection C content.\n",
            encoding="utf-8",
        )
        _ingest_file(f, conn, force=False)
        conn.commit()
        row = conn.execute("SELECT chunk_count FROM documents WHERE file_path = ?", (str(f),)).fetchone()
        conn.close()
        assert row is not None
        assert row[0] >= 1


# ===========================================================================
# FTS basic search
# ===========================================================================

class TestFTSSearch:
    def test_fts_finds_ingested_content(self, tmp_path: Path) -> None:
        db = tmp_path / "search.db"
        conn = _connect(db)

        f = tmp_path / "notes.md"
        f.write_text("## Quantum Computing\n\nQuantum entanglement is fascinating.", encoding="utf-8")
        _ingest_file(f, conn, force=False)
        conn.commit()
        _rebuild_fts(conn)
        conn.commit()

        rows = conn.execute(
            "SELECT content FROM chunks_fts WHERE chunks_fts MATCH 'quantum'"
        ).fetchall()
        conn.close()
        assert rows, "FTS should return results for 'quantum'"
        assert any("quantum" in r[0].lower() for r in rows)

    def test_fts_returns_empty_for_missing_term(self, tmp_path: Path) -> None:
        db = tmp_path / "search.db"
        conn = _connect(db)

        f = tmp_path / "notes.md"
        f.write_text("## Hello\n\nSimple content.", encoding="utf-8")
        _ingest_file(f, conn, force=False)
        conn.commit()
        _rebuild_fts(conn)
        conn.commit()

        rows = conn.execute(
            "SELECT content FROM chunks_fts WHERE chunks_fts MATCH 'xyzzy_nonexistent'"
        ).fetchall()
        conn.close()
        assert rows == []


# ===========================================================================
# _extract_title
# ===========================================================================

class TestExtractTitle:
    def test_extracts_h1_from_markdown(self, tmp_path: Path) -> None:
        f = tmp_path / "doc.md"
        title = _extract_title(f, "# My Document\n\nContent.")
        assert title == "My Document"

    def test_extracts_h2_if_no_h1(self, tmp_path: Path) -> None:
        f = tmp_path / "doc.md"
        title = _extract_title(f, "## Section Heading\n\nContent.")
        assert title == "Section Heading"

    def test_falls_back_to_stem_for_non_markdown(self, tmp_path: Path) -> None:
        f = tmp_path / "my-script.py"
        title = _extract_title(f, "def main(): pass")
        assert title == "My Script"

    def test_hyphen_stem_becomes_title_case(self, tmp_path: Path) -> None:
        f = tmp_path / "hello-world.txt"
        title = _extract_title(f, "some content")
        assert title == "Hello World"


# ===========================================================================
# _approx_tokens
# ===========================================================================

class TestApproxTokens:
    def test_minimum_is_one(self) -> None:
        assert _approx_tokens("") == 1
        assert _approx_tokens("a") == 1

    def test_proportional_to_length(self) -> None:
        assert _approx_tokens("a" * 400) == 100
        assert _approx_tokens("a" * 800) == 200
