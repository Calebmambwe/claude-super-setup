#!/usr/bin/env python3
"""
Knowledge RAG MCP Server — file ingestion into a per-project SQLite knowledge base.

Runs as a stdio MCP server. Register in ~/.claude/settings.json under mcpServers.

Tools:
  knowledge_ingest  — ingest files/directories into the knowledge base
  knowledge_status  — show knowledge base statistics
  knowledge_search  — semantic/full-text search over the knowledge base
  knowledge_clear   — clear all data from the project knowledge base
"""

import hashlib
import logging
import os
import re
import sqlite3
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

# ── Optional embedding support ────────────────────────────────────────────────

try:
    from sentence_transformers import SentenceTransformer
    _embed_model: Optional[Any] = SentenceTransformer("all-MiniLM-L6-v2")
    HAS_EMBEDDINGS = True
except ImportError:
    _embed_model = None
    HAS_EMBEDDINGS = False

# ── Optional sqlite-vss support ───────────────────────────────────────────────

HAS_VSS = False
try:
    import sqlite_vss  # type: ignore[import]
    HAS_VSS = True
except ImportError:
    pass

# ── MCP SDK ──────────────────────────────────────────────────────────────────
try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    print(
        "ERROR: mcp package not installed. Run:\n"
        "  uv pip install mcp\n"
        "or register this server with:\n"
        '  "command": "uv", "args": ["run", "--with", "mcp", "python3", "<path>"]',
        file=sys.stderr,
    )
    sys.exit(1)

# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger("knowledge-rag")

# ── Constants ─────────────────────────────────────────────────────────────────

KNOWLEDGE_DIR = Path.home() / ".claude" / "knowledge"
KNOWLEDGE_DIR.mkdir(parents=True, exist_ok=True)

DEFAULT_FILE_TYPES: list[str] = ["md", "txt", "py", "ts", "tsx", "js", "json", "yaml", "yml"]

# Chunking sizes (approximate: 1 token ≈ 4 chars)
MAX_CHUNK_CHARS: int = 2048   # ~512 tokens
OVERLAP_CHARS: int = 200      # ~50 tokens

# ── Schema ────────────────────────────────────────────────────────────────────

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL UNIQUE,
    file_hash TEXT NOT NULL,
    file_type TEXT NOT NULL,
    title TEXT,
    chunk_count INTEGER DEFAULT 0,
    ingested_at TEXT NOT NULL,
    updated_at TEXT
);

CREATE TABLE IF NOT EXISTS chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    content TEXT NOT NULL,
    token_count INTEGER NOT NULL,
    created_at TEXT NOT NULL
);

CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
    content, content='chunks', content_rowid='id'
);
"""

# ── Dataclasses ───────────────────────────────────────────────────────────────

@dataclass
class IngestResult:
    files_ingested: int = 0
    chunks_created: int = 0
    files_skipped: int = 0
    files_errored: int = 0
    errors: list[str] = field(default_factory=list)


@dataclass
class KnowledgeStatus:
    document_count: int
    chunk_count: int
    database_size_bytes: int
    last_ingestion_time: Optional[str]
    db_path: str


# ── Database helpers ──────────────────────────────────────────────────────────

def _project_hash(project_dir: str) -> str:
    """Compute a stable 16-char hex hash for a project directory path."""
    return hashlib.sha256(project_dir.encode()).hexdigest()[:16]


def _db_path(project_dir: str) -> Path:
    """Return the SQLite database path for a given project directory."""
    return KNOWLEDGE_DIR / f"{_project_hash(project_dir)}.db"


def _connect(db_file: Path) -> sqlite3.Connection:
    """Open (or create) the SQLite database and apply the schema."""
    conn = sqlite3.connect(str(db_file))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.executescript(SCHEMA_SQL)
    conn.commit()
    return conn


# ── Hashing ───────────────────────────────────────────────────────────────────

def _file_hash(path: Path) -> str:
    """Compute SHA-256 hex digest for a file."""
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(65536), b""):
            h.update(block)
    return h.hexdigest()


# ── Chunking ─────────────────────────────────────────────────────────────────

def _chunk_text(text: str, max_chars: int = MAX_CHUNK_CHARS, overlap: int = OVERLAP_CHARS) -> list[str]:
    """
    Split text into overlapping chunks of at most max_chars characters.
    Tries to split on sentence boundaries ('. ') before hard-cutting.
    """
    if len(text) <= max_chars:
        return [text] if text.strip() else []

    chunks: list[str] = []
    start = 0
    length = len(text)

    while start < length:
        end = min(start + max_chars, length)
        segment = text[start:end]

        if end < length:
            # Try to cut at the last sentence boundary
            boundary = segment.rfind(". ")
            if boundary > max_chars // 2:
                end = start + boundary + 1  # include the period
                segment = text[start:end]

        stripped = segment.strip()
        if stripped:
            chunks.append(stripped)

        # Advance, applying overlap so context is shared between chunks
        start = end - overlap if end - overlap > start else end

    return chunks


def _chunk_markdown(text: str) -> list[str]:
    """
    Chunk markdown content. Splits on ## headings first, then falls back
    to _chunk_text for sections that are still too long.
    """
    # Split on level-2+ headings (## ...), keeping the heading in each section
    sections = re.split(r"(?m)^(?=#{2,}\s)", text)
    chunks: list[str] = []
    for section in sections:
        section = section.strip()
        if not section:
            continue
        if len(section) <= MAX_CHUNK_CHARS:
            chunks.append(section)
        else:
            # Try splitting on paragraphs (double newline)
            paragraphs = re.split(r"\n{2,}", section)
            buffer = ""
            for para in paragraphs:
                para = para.strip()
                if not para:
                    continue
                if len(buffer) + len(para) + 2 <= MAX_CHUNK_CHARS:
                    buffer = (buffer + "\n\n" + para).strip() if buffer else para
                else:
                    if buffer:
                        chunks.extend(_chunk_text(buffer))
                    buffer = para
            if buffer:
                chunks.extend(_chunk_text(buffer))
    return chunks


# Regex patterns that signal the start of a top-level code construct
_CODE_BOUNDARY_RE = re.compile(
    r"^(?:def |class |function |const |export |async def |async function )",
    re.MULTILINE,
)


def _chunk_source_code(text: str) -> list[str]:
    """
    Chunk source code by splitting on function/class boundaries, then
    falling back to _chunk_text for blocks that are still too large.
    """
    # Find all match positions
    boundaries = [m.start() for m in _CODE_BOUNDARY_RE.finditer(text)]

    if not boundaries:
        return _chunk_text(text)

    sections: list[str] = []
    # Text before the first boundary (imports, module-level code)
    if boundaries[0] > 0:
        sections.append(text[: boundaries[0]])

    for i, start in enumerate(boundaries):
        end = boundaries[i + 1] if i + 1 < len(boundaries) else len(text)
        sections.append(text[start:end])

    chunks: list[str] = []
    for section in sections:
        section = section.strip()
        if not section:
            continue
        chunks.extend(_chunk_text(section))
    return chunks


def _chunk_file(path: Path) -> list[str]:
    """Read a file and return a list of text chunks."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        logger.warning("Cannot read %s: %s", path, exc)
        return []

    if not text.strip():
        return []

    ext = path.suffix.lstrip(".").lower()

    if ext == "md":
        return _chunk_markdown(text)
    if ext in {"py", "ts", "tsx", "js"}:
        return _chunk_source_code(text)
    # json, yaml, yml, txt — generic chunking
    return _chunk_text(text)


def _approx_tokens(text: str) -> int:
    """Approximate token count (1 token ≈ 4 chars)."""
    return max(1, len(text) // 4)


def _extract_title(path: Path, content: str) -> Optional[str]:
    """Try to extract a meaningful title from the file."""
    ext = path.suffix.lstrip(".").lower()
    if ext == "md":
        # First # heading
        match = re.search(r"^#{1,2}\s+(.+)$", content, re.MULTILINE)
        if match:
            return match.group(1).strip()
    # Fall back to the filename stem
    return path.stem.replace("-", " ").replace("_", " ").title()


# ── Ingestion logic ───────────────────────────────────────────────────────────

def _ingest_file(
    path: Path,
    conn: sqlite3.Connection,
    force: bool,
) -> tuple[bool, int]:
    """
    Ingest a single file into the database.

    Returns:
        (was_ingested: bool, chunks_created: int)
        was_ingested is False when the file is unchanged and force=False (skipped).
    """
    file_hash = _file_hash(path)
    file_type = path.suffix.lstrip(".").lower()
    now = datetime.now(timezone.utc).isoformat()
    path_str = str(path)

    # Check if file already exists and is unchanged
    existing = conn.execute(
        "SELECT id, file_hash FROM documents WHERE file_path = ?",
        (path_str,),
    ).fetchone()

    if existing and existing["file_hash"] == file_hash and not force:
        logger.debug("Skipping unchanged file: %s", path)
        return False, 0

    chunks = _chunk_file(path)
    if not chunks:
        logger.debug("No content to ingest from: %s", path)
        return False, 0

    # Try to read full content for title extraction (first chunk is fine)
    try:
        full_text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        full_text = chunks[0] if chunks else ""

    title = _extract_title(path, full_text)

    if existing:
        # Update existing document record
        conn.execute(
            """
            UPDATE documents
               SET file_hash = ?, file_type = ?, title = ?, chunk_count = ?,
                   updated_at = ?
             WHERE file_path = ?
            """,
            (file_hash, file_type, title, len(chunks), now, path_str),
        )
        doc_id = existing["id"]
        # Remove old chunks (FTS will be rebuilt via trigger or manually)
        conn.execute("DELETE FROM chunks WHERE document_id = ?", (doc_id,))
    else:
        cur = conn.execute(
            """
            INSERT INTO documents (file_path, file_hash, file_type, title, chunk_count, ingested_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (path_str, file_hash, file_type, title, len(chunks), now),
        )
        doc_id = cur.lastrowid

    # Insert new chunks
    for idx, chunk_text in enumerate(chunks):
        conn.execute(
            """
            INSERT INTO chunks (document_id, chunk_index, content, token_count, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (doc_id, idx, chunk_text, _approx_tokens(chunk_text), now),
        )

    logger.info("Ingested %s → %d chunk(s)", path, len(chunks))
    return True, len(chunks)


def _rebuild_fts(conn: sqlite3.Connection) -> None:
    """Rebuild the FTS index from the chunks table."""
    try:
        conn.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')")
    except sqlite3.OperationalError as exc:
        logger.warning("FTS rebuild failed (non-fatal): %s", exc)


# ── MCP server ────────────────────────────────────────────────────────────────

mcp = FastMCP("knowledge-rag")


@mcp.tool()
def knowledge_ingest(
    path: str,
    project_dir: str,
    file_types: Optional[list[str]] = None,
    force: bool = False,
) -> str:
    """Ingest files or a directory into the project knowledge base.

    Args:
        path: Absolute path to a file or directory to ingest
        project_dir: Absolute path to the project root (used to determine the DB)
        file_types: File extensions to include without the leading dot
                    (default: md, txt, py, ts, tsx, js, json, yaml, yml)
        force: Re-ingest files even if their content has not changed (default False)
    """
    target = Path(path).expanduser().resolve()
    # Security: ensure path is under HOME to prevent data exfiltration
    home = Path.home()
    if not target.is_relative_to(home):
        return f"Error: path must be under {home}. Got: {target}"
    if not target.exists():
        return f"ERROR: Path does not exist: {target}"

    allowed_exts: set[str] = {
        ext.lstrip(".").lower() for ext in (file_types or DEFAULT_FILE_TYPES)
    }

    db_file = _db_path(project_dir)
    conn = _connect(db_file)
    result = IngestResult()

    try:
        if target.is_file():
            candidates = [target]
        else:
            candidates = [
                p for p in target.rglob("*")
                if p.is_file() and p.suffix.lstrip(".").lower() in allowed_exts
            ]

        for file_path in sorted(candidates):
            # Skip hidden directories (e.g. .git, .venv, node_modules)
            parts = file_path.parts
            if any(part.startswith(".") or part in {"node_modules", "__pycache__", "dist", "build"}
                   for part in parts):
                logger.debug("Skipping hidden/ignored path: %s", file_path)
                continue

            try:
                was_ingested, chunk_count = _ingest_file(file_path, conn, force=force)
                if was_ingested:
                    result.files_ingested += 1
                    result.chunks_created += chunk_count
                else:
                    result.files_skipped += 1
            except Exception as exc:
                logger.error("Error ingesting %s: %s", file_path, exc)
                result.files_errored += 1
                result.errors.append(f"{file_path}: {exc}")

        conn.commit()
        _rebuild_fts(conn)
        conn.commit()

    finally:
        conn.close()

    lines = [
        f"Ingestion complete for: {target}",
        f"  Files ingested : {result.files_ingested}",
        f"  Chunks created : {result.chunks_created}",
        f"  Files skipped  : {result.files_skipped} (unchanged)",
        f"  Files errored  : {result.files_errored}",
        f"  Database       : {db_file}",
    ]
    if result.errors:
        lines.append("\nErrors:")
        for err in result.errors[:10]:
            lines.append(f"  {err}")
        if len(result.errors) > 10:
            lines.append(f"  … and {len(result.errors) - 10} more")

    return "\n".join(lines)


@mcp.tool()
def knowledge_status(project_dir: str) -> str:
    """Show knowledge base statistics for a project.

    Args:
        project_dir: Absolute path to the project root
    """
    db_file = _db_path(project_dir)

    if not db_file.exists():
        return (
            f"No knowledge base found for project: {project_dir}\n"
            f"Expected database at: {db_file}\n"
            "Run knowledge_ingest first."
        )

    conn = _connect(db_file)
    try:
        doc_row = conn.execute("SELECT COUNT(*) AS cnt FROM documents").fetchone()
        chunk_row = conn.execute("SELECT COUNT(*) AS cnt FROM chunks").fetchone()
        last_row = conn.execute(
            "SELECT MAX(COALESCE(updated_at, ingested_at)) AS ts FROM documents"
        ).fetchone()

        document_count = doc_row["cnt"] if doc_row else 0
        chunk_count = chunk_row["cnt"] if chunk_row else 0
        last_ingestion = last_row["ts"] if last_row else None
        db_size = db_file.stat().st_size

    finally:
        conn.close()

    def _fmt_bytes(n: int) -> str:
        for unit in ("B", "KB", "MB", "GB"):
            if n < 1024:
                return f"{n:.1f} {unit}"
            n /= 1024  # type: ignore[assignment]
        return f"{n:.1f} TB"

    lines = [
        f"Knowledge base: {project_dir}",
        f"  Database path  : {db_file}",
        f"  Documents      : {document_count}",
        f"  Chunks         : {chunk_count}",
        f"  Database size  : {_fmt_bytes(db_file.stat().st_size)}",
        f"  Last ingestion : {last_ingestion or 'never'}",
    ]
    return "\n".join(lines)


@mcp.tool()
def knowledge_search(
    query: str,
    project_dir: str,
    top_k: int = 5,
    file_type: Optional[str] = None,
) -> str:
    """Search the project knowledge base using full-text (FTS5/BM25) and optional vector search.

    Args:
        query: The search query string
        project_dir: Absolute path to the project root
        top_k: Maximum number of results to return (default 5)
        file_type: Optional file extension filter without leading dot (e.g. "md", "py")
    """
    # Security: ensure project_dir is under HOME to prevent data exfiltration
    resolved_project_dir = Path(project_dir).expanduser().resolve()
    home = Path.home()
    if not resolved_project_dir.is_relative_to(home):
        return f"Error: path must be under {home}. Got: {resolved_project_dir}"

    db_file = _db_path(project_dir)
    if not db_file.exists():
        return (
            f"No knowledge base found for project: {project_dir}\n"
            "Run knowledge_ingest first."
        )

    if not query.strip():
        return "ERROR: query must not be empty."

    conn = _connect(db_file)

    # Load sqlite-vss extension if available
    if HAS_VSS:
        try:
            conn.enable_load_extension(True)
            sqlite_vss.load(conn)  # type: ignore[union-attr]
        except Exception as exc:
            logger.warning("sqlite-vss load failed (non-fatal): %s", exc)

    try:
        # ── FTS5 full-text search ─────────────────────────────────────────────
        # Escape FTS5 special chars to avoid query syntax errors
        fts_query = re.sub(r'["\(\)\*\:\^]', " ", query).strip()
        if not fts_query:
            fts_query = query

        fts_sql = """
            SELECT
                c.id          AS chunk_id,
                c.chunk_index,
                c.content,
                d.file_path,
                d.file_type,
                (-1.0 * rank) AS fts_score
            FROM chunks_fts
            JOIN chunks   c ON c.id = chunks_fts.rowid
            JOIN documents d ON d.id = c.document_id
            WHERE chunks_fts MATCH ?
        """
        params: list[Any] = [fts_query]

        if file_type:
            fts_sql += " AND d.file_type = ?"
            params.append(file_type.lstrip(".").lower())

        fts_sql += " ORDER BY rank LIMIT ?"
        params.append(top_k * 2)  # over-fetch so we can merge/re-rank

        try:
            fts_rows = conn.execute(fts_sql, params).fetchall()
        except sqlite3.OperationalError as exc:
            logger.warning("FTS query failed (%s), falling back to LIKE search", exc)
            fts_rows = []

        # Build a dict keyed by chunk_id for deduplication
        results: dict[int, dict[str, Any]] = {}
        for row in fts_rows:
            results[row["chunk_id"]] = {
                "chunk_id": row["chunk_id"],
                "chunk_index": row["chunk_index"],
                "file_path": row["file_path"],
                "content": row["content"],
                "relevance_score": float(row["fts_score"]),
            }

        # ── Optional vector search ────────────────────────────────────────────
        if HAS_EMBEDDINGS and HAS_VSS and _embed_model is not None:
            try:
                query_vec: list[float] = _embed_model.encode(query).tolist()  # type: ignore[union-attr]
                vec_sql = """
                    SELECT
                        c.id          AS chunk_id,
                        c.chunk_index,
                        c.content,
                        d.file_path,
                        v.distance    AS vec_distance
                    FROM vss_chunks v
                    JOIN chunks    c ON c.id = v.rowid
                    JOIN documents d ON d.id = c.document_id
                    WHERE vss_search(v.embedding, ?)
                    LIMIT ?
                """
                vec_rows = conn.execute(vec_sql, (str(query_vec), top_k * 2)).fetchall()
                for row in vec_rows:
                    cid = row["chunk_id"]
                    # Convert distance to a score (smaller distance = higher score)
                    vec_score = 1.0 / (1.0 + float(row["vec_distance"]))
                    if cid in results:
                        # Merge: blend both scores
                        results[cid]["relevance_score"] = (
                            results[cid]["relevance_score"] * 0.5 + vec_score * 0.5
                        )
                    else:
                        results[cid] = {
                            "chunk_id": cid,
                            "chunk_index": row["chunk_index"],
                            "file_path": row["file_path"],
                            "content": row["content"],
                            "relevance_score": vec_score,
                        }
            except Exception as exc:
                logger.warning("Vector search failed (non-fatal): %s", exc)

        if not results:
            return f"No results found for query: {query!r}"

        # Sort by relevance descending and take top_k
        ranked = sorted(results.values(), key=lambda r: r["relevance_score"], reverse=True)[:top_k]

        lines = [f"Search results for: {query!r}  (top {len(ranked)} of {len(results)} matches)\n"]
        for i, hit in enumerate(ranked, start=1):
            snippet = hit["content"][:500].strip()
            if len(hit["content"]) > 500:
                snippet += "…"
            lines.append(
                f"[{i}] {hit['file_path']}  (chunk #{hit['chunk_index']}, "
                f"score: {hit['relevance_score']:.4f})\n"
                f"{snippet}\n"
            )

        return "\n".join(lines)

    finally:
        conn.close()


@mcp.tool()
def knowledge_clear(
    project_dir: str,
    confirm: bool = False,
) -> str:
    """Clear all data from the project knowledge base.

    Args:
        project_dir: Absolute path to the project root
        confirm: Must be True to actually delete data (safety guard, default False)
    """
    if not confirm:
        return (
            "WARNING: This will permanently delete all documents and chunks from the "
            f"knowledge base for project: {project_dir}\n"
            "Pass confirm=True to proceed."
        )

    db_file = _db_path(project_dir)
    if not db_file.exists():
        return f"No knowledge base found for project: {project_dir}. Nothing to clear."

    conn = _connect(db_file)
    try:
        conn.execute("DELETE FROM chunks")
        conn.execute("DELETE FROM documents")
        conn.commit()

        # Rebuild (now empty) FTS index
        _rebuild_fts(conn)
        conn.commit()

    finally:
        conn.close()

    return (
        f"Knowledge base cleared for project: {project_dir}\n"
        f"Database: {db_file}\n"
        "All documents and chunks have been deleted. FTS index has been rebuilt."
    )


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    mcp.run(transport="stdio")
