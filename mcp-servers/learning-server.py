#!/usr/bin/env python3
"""
Learning MCP Server — wraps the SQLite learning ledger with 5 tools.

Runs as a stdio MCP server. Register in ~/.claude/settings.json under mcpServers.

Tools:
  search_learnings       — text/semantic search over past learnings
  record_learning        — record a new learning mid-session
  get_project_learnings  — all learnings for a project directory
  get_learning_stats     — ledger statistics
  promote_learning       — mark a learning as promoted + append to CLAUDE.md
"""

import sys
import os
import json
import shutil
import hashlib
from pathlib import Path
from datetime import datetime
from typing import Optional

# Add the reflect/scripts directory so we can import LearningLedger
# Uses HOME env var for portability across machines
SCRIPTS_DIR = Path.home() / ".claude" / "skills" / "reflect" / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from learning_ledger import LearningLedger  # noqa: E402

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

mcp = FastMCP("learning-ledger")
ledger = LearningLedger()

GLOBAL_CLAUDE_MD = Path.home() / ".claude" / "CLAUDE.md"
BACKUP_DIR = Path.home() / ".claude" / "backups"

# ── Optional: OpenAI embeddings ───────────────────────────────────────────────

def _get_embedding(text: str) -> Optional[list]:
    """Return embedding vector if OPENAI_API_KEY is set, else None."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None
    try:
        import urllib.request
        payload = json.dumps({"model": "text-embedding-3-small", "input": text}).encode()
        req = urllib.request.Request(
            "https://api.openai.com/v1/embeddings",
            data=payload,
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {api_key}"},
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
            return data["data"][0]["embedding"]
    except Exception:
        return None


# ── Tools ─────────────────────────────────────────────────────────────────────

@mcp.tool()
def search_learnings(
    query: str,
    project_dir: str = "",
    type: str = "",
    top_k: int = 5,
) -> str:
    """Search past learnings by keyword or semantic similarity.

    Args:
        query: Search text (can be empty to get recent learnings)
        project_dir: Filter to a specific project directory (optional)
        type: Filter by learning type: correction, success, pattern (optional)
        top_k: Maximum number of results to return (default 5)
    """
    results = []
    pd = project_dir.strip() or None

    # Try semantic search if we can get an embedding
    if query.strip():
        embedding = _get_embedding(query)
        if embedding:
            results = ledger.semantic_search(embedding, top_k=top_k, project_dir=pd)
        else:
            results = ledger.search(query, limit=top_k)
    elif pd:
        results = ledger.get_project_learnings(pd, limit=top_k)
    else:
        # Return most recent active learnings
        import sqlite3
        conn = ledger._connect()
        cur = conn.execute(
            "SELECT * FROM learnings WHERE status != 'archived' ORDER BY last_seen DESC LIMIT ?",
            (top_k,)
        )
        results = [dict(r) for r in cur.fetchall()]
        conn.close()

    # Apply type filter
    if type.strip():
        results = [r for r in results if r.get("learning_type") == type.strip()]

    if not results:
        return "No learnings found."

    lines = [f"Found {len(results)} learning(s):\n"]
    for r in results:
        score = r.get("similarity_score", "")
        score_str = f" (score: {score:.2f})" if isinstance(score, float) else ""
        lines.append(
            f"[{r['fingerprint'][:8]}] [{r.get('learning_type', '?')}]{score_str}\n"
            f"  {r['content']}\n"
            f"  confidence: {r.get('confidence', 0):.2f} | seen: {r.get('count', 1)}x | "
            f"status: {r.get('status', 'pending')}"
        )
    return "\n".join(lines)


@mcp.tool()
def record_learning(
    content: str,
    type: str = "correction",
    confidence: float = 0.8,
    project_dir: str = "",
    tags: str = "",
) -> str:
    """Record a new learning to the ledger.

    Args:
        content: The learning to record (be specific and actionable)
        type: One of: correction, success, pattern, preference
        confidence: 0.0–1.0 (corrections=0.9, successes=0.75, patterns=0.8)
        project_dir: Project directory this learning applies to (optional)
        tags: Comma-separated tags (optional)
    """
    tags_list = [t.strip() for t in tags.split(",") if t.strip()] if tags else []
    pd = project_dir.strip() or None

    # Try to get embedding
    embedding = _get_embedding(content)

    if embedding:
        result = ledger.record_with_embedding(
            content=content,
            learning_type=type,
            confidence=confidence,
            embedding=embedding,
            project_dir=pd,
            tags=tags_list,
        )
    else:
        result = ledger.record_learning(
            content=content,
            learning_type=type,
            skill_name="general",
            confidence=confidence,
            project_dir=pd,
            tags=tags_list,
        )

    action = result.get("action", "unknown")
    fp = result.get("fingerprint", "")[:8]
    repo_count = result.get("repo_count", 1)

    msg = f"Learning {action} [{fp}] — seen in {repo_count} repo(s)."
    if repo_count >= 2:
        msg += " Eligible for promotion to CLAUDE.md."
    return msg


@mcp.tool()
def get_project_learnings(project_dir: str, limit: int = 10) -> str:
    """Get all learnings recorded for a specific project directory.

    Args:
        project_dir: Absolute path to the project directory
        limit: Max number of learnings to return (default 10)
    """
    results = ledger.get_project_learnings(project_dir, limit=limit)
    if not results:
        return f"No learnings found for {project_dir}."

    lines = [f"{len(results)} learning(s) for {project_dir}:\n"]
    for r in results:
        lines.append(
            f"[{r['fingerprint'][:8]}] [{r.get('learning_type', '?')}] "
            f"confidence={r.get('confidence', 0):.2f}\n  {r['content']}"
        )
    return "\n".join(lines)


@mcp.tool()
def get_learning_stats() -> str:
    """Return statistics about the learning ledger."""
    stats = ledger.get_stats()
    lines = [
        f"Total learnings: {stats['total_learnings']}",
        f"With embeddings: {stats.get('with_embeddings', 0)}",
        f"Promotion eligible: {stats['promotion_eligible']}",
        f"Total promotions: {stats['total_promotions']}",
        "",
        "By status:",
    ]
    for k, v in stats.get("by_status", {}).items():
        lines.append(f"  {k}: {v}")
    lines.append("\nBy type:")
    for k, v in stats.get("by_type", {}).items():
        lines.append(f"  {k}: {v}")
    lines.append("\nTop skills:")
    for k, v in stats.get("by_skill", {}).items():
        lines.append(f"  {k}: {v}")
    return "\n".join(lines)


@mcp.tool()
def promote_learning(fingerprint: str) -> str:
    """Mark a learning as promoted and append it to ~/.claude/CLAUDE.md.

    Args:
        fingerprint: The 8–16 char fingerprint from search_learnings output
    """
    # Accept short (8-char) or full (16-char) fingerprints
    fp = fingerprint.strip()

    # Find the full fingerprint if a prefix was given
    if len(fp) < 16:
        conn = ledger._connect()
        cur = conn.execute(
            "SELECT fingerprint FROM learnings WHERE fingerprint LIKE ?",
            (f"{fp}%",)
        )
        row = cur.fetchone()
        conn.close()
        if not row:
            return f"No learning found with fingerprint starting '{fp}'."
        fp = row["fingerprint"]

    eligibility = ledger.check_promotion_eligibility(fp)
    if not eligibility["eligible"]:
        return f"Not eligible: {eligibility['reason']}"

    learning = ledger.get_learning(fp)
    content = learning["content"]
    skill = learning.get("skill_name", "general")
    repos = json.loads(learning.get("repo_ids", "[]"))

    # Format the entry
    entry = (
        f"\n## From {skill} (auto-promoted)\n\n"
        f"{content}\n\n"
        f"<!-- Promoted: {datetime.utcnow().isoformat()} | "
        f"Seen in {len(repos)} repos | "
        f"Fingerprint: {fp[:8]} -->\n"
    )

    # Backup + append
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    if GLOBAL_CLAUDE_MD.exists():
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        shutil.copy2(GLOBAL_CLAUDE_MD, BACKUP_DIR / f"CLAUDE.md.{ts}.bak")

    GLOBAL_CLAUDE_MD.parent.mkdir(parents=True, exist_ok=True)
    with open(GLOBAL_CLAUDE_MD, "a") as f:
        f.write(entry)

    ledger.mark_promoted(fp, f"Seen in {len(repos)} repos")

    return f"Promoted [{fp[:8]}] to CLAUDE.md: {content[:80]}..."


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    mcp.run(transport="stdio")
