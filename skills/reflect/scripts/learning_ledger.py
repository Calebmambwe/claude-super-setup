#!/usr/bin/env python3
"""
Learning Ledger - SQLite-based tracking for cross-skill learning.

Tracks learnings across multiple skills and repositories.
When a learning appears in 2+ repos, it becomes eligible for promotion to global.
"""

import os
import sys
import json
import math
import sqlite3
import hashlib
import subprocess
from pathlib import Path
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

# Storage location
REFLECT_DIR = Path.home() / ".claude" / "reflect"
LEDGER_DB = REFLECT_DIR / "learnings.db"

# Promotion threshold (seen in N repos → eligible for global)
DEFAULT_PROMOTION_THRESHOLD = 2


class LearningLedger:
    """Manages the cross-skill learning database."""

    def __init__(self, db_path: Path = LEDGER_DB):
        self.db_path = db_path
        self._ensure_db()

    def _ensure_db(self):
        """Create database and tables if they don't exist."""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)

        conn = sqlite3.connect(self.db_path)
        conn.executescript('''
            CREATE TABLE IF NOT EXISTS learnings (
                id TEXT PRIMARY KEY,
                fingerprint TEXT UNIQUE NOT NULL,
                content TEXT NOT NULL,
                learning_type TEXT,
                skill_name TEXT,
                repo_ids TEXT DEFAULT '[]',
                count INTEGER DEFAULT 1,
                confidence REAL DEFAULT 0.5,
                status TEXT DEFAULT 'pending',
                first_seen TEXT,
                last_seen TEXT,
                promoted_at TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS promotions (
                id TEXT PRIMARY KEY,
                fingerprint TEXT NOT NULL,
                from_scope TEXT,
                to_scope TEXT,
                reason TEXT,
                promoted_at TEXT DEFAULT CURRENT_TIMESTAMP
            );

            CREATE INDEX IF NOT EXISTS idx_fingerprint ON learnings(fingerprint);
            CREATE INDEX IF NOT EXISTS idx_status ON learnings(status);
            CREATE INDEX IF NOT EXISTS idx_skill ON learnings(skill_name);
        ''')
        conn.commit()

        # Add new columns if they don't exist (migration)
        for col, definition in [
            ("embedding", "TEXT"),
            ("tags", "TEXT DEFAULT '[]'"),
            ("project_dir", "TEXT"),
        ]:
            try:
                conn.execute(f"ALTER TABLE learnings ADD COLUMN {col} {definition}")
                conn.commit()
            except sqlite3.OperationalError:
                pass  # Column already exists

        conn.close()

    def _connect(self) -> sqlite3.Connection:
        """Get database connection."""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _generate_fingerprint(self, content: str) -> str:
        """Generate stable fingerprint for a learning."""
        normalized = ' '.join(content.lower().split())
        return hashlib.sha256(normalized.encode()).hexdigest()[:16]

    def _get_repo_id(self) -> str:
        """Get stable hash of current repository."""
        try:
            result = subprocess.run(
                ["git", "remote", "get-url", "origin"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                return hashlib.sha256(result.stdout.strip().encode()).hexdigest()[:12]
        except Exception:
            pass
        return hashlib.sha256(os.getcwd().encode()).hexdigest()[:12]

    def _cosine_similarity(self, a: List[float], b: List[float]) -> float:
        """Compute cosine similarity between two vectors."""
        if not a or not b or len(a) != len(b):
            return 0.0
        dot = sum(x * y for x, y in zip(a, b))
        norm_a = math.sqrt(sum(x * x for x in a))
        norm_b = math.sqrt(sum(x * x for x in b))
        if norm_a == 0 or norm_b == 0:
            return 0.0
        return dot / (norm_a * norm_b)

    def record_learning(
        self,
        content: str,
        learning_type: str = "correction",
        skill_name: str = "general",
        confidence: float = 0.5,
        project_dir: Optional[str] = None,
        tags: Optional[List[str]] = None,
    ) -> Dict:
        """Record a learning in the ledger."""
        fingerprint = self._generate_fingerprint(content)
        repo_id = self._get_repo_id()
        now = datetime.now(timezone.utc).isoformat()
        project_dir = project_dir or os.getcwd()
        tags_json = json.dumps(tags or [])

        conn = self._connect()
        cursor = conn.execute(
            "SELECT * FROM learnings WHERE fingerprint = ?",
            (fingerprint,)
        )
        existing = cursor.fetchone()

        if existing:
            repo_ids = json.loads(existing['repo_ids'] or '[]')
            if repo_id not in repo_ids:
                repo_ids.append(repo_id)

            existing_tags = existing['tags'] or '[]'
            tags_update = tags_json if tags else existing_tags

            conn.execute('''
                UPDATE learnings
                SET repo_ids = ?, count = count + 1, last_seen = ?,
                    confidence = MAX(confidence, ?), updated_at = ?,
                    project_dir = COALESCE(project_dir, ?), tags = ?
                WHERE fingerprint = ?
            ''', (json.dumps(repo_ids), now, confidence, now,
                  project_dir, tags_update, fingerprint))

            result = {
                "action": "updated",
                "fingerprint": fingerprint,
                "repo_count": len(repo_ids),
                "total_count": existing['count'] + 1
            }
        else:
            learning_id = hashlib.md5(f"{fingerprint}{now}".encode()).hexdigest()[:8]

            conn.execute('''
                INSERT INTO learnings
                (id, fingerprint, content, learning_type, skill_name, repo_ids,
                 confidence, first_seen, last_seen, project_dir, tags)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (learning_id, fingerprint, content, learning_type, skill_name,
                  json.dumps([repo_id]), confidence, now, now, project_dir, tags_json))

            result = {
                "action": "created",
                "fingerprint": fingerprint,
                "repo_count": 1,
                "total_count": 1
            }

        conn.commit()
        conn.close()
        return result

    def record_with_embedding(
        self,
        content: str,
        learning_type: str = "correction",
        confidence: float = 0.5,
        embedding: Optional[List[float]] = None,
        project_dir: Optional[str] = None,
        tags: Optional[List[str]] = None,
    ) -> Dict:
        """Record a learning with an embedding vector for semantic search."""
        result = self.record_learning(
            content=content,
            learning_type=learning_type,
            confidence=confidence,
            project_dir=project_dir,
            tags=tags,
        )

        if embedding:
            fingerprint = self._generate_fingerprint(content)
            conn = self._connect()
            conn.execute(
                "UPDATE learnings SET embedding = ? WHERE fingerprint = ?",
                (json.dumps(embedding), fingerprint)
            )
            conn.commit()
            conn.close()
            result["has_embedding"] = True

        return result

    def semantic_search(
        self,
        query_embedding: List[float],
        top_k: int = 5,
        project_dir: Optional[str] = None,
    ) -> List[Dict]:
        """Search learnings using cosine similarity over stored embeddings.

        Falls back to returning all active learnings sorted by recency
        if no embeddings are stored.
        """
        conn = self._connect()
        if project_dir:
            cursor = conn.execute(
                "SELECT * FROM learnings WHERE status != 'archived' AND project_dir = ? ORDER BY last_seen DESC",
                (project_dir,)
            )
        else:
            cursor = conn.execute(
                "SELECT * FROM learnings WHERE status != 'archived' ORDER BY last_seen DESC"
            )
        rows = [dict(row) for row in cursor.fetchall()]
        conn.close()

        scored = []
        has_embeddings = False
        for row in rows:
            emb_json = row.get("embedding")
            if emb_json:
                has_embeddings = True
                emb = json.loads(emb_json)
                score = self._cosine_similarity(query_embedding, emb)
            else:
                score = 0.0
            scored.append((score, row))

        if has_embeddings:
            scored.sort(key=lambda x: x[0], reverse=True)
        # else: already sorted by recency

        results = []
        for score, row in scored[:top_k]:
            row["similarity_score"] = score
            results.append(row)
        return results

    def get_project_learnings(self, project_dir: str, limit: int = 10) -> List[Dict]:
        """Get all learnings for a specific project directory."""
        conn = self._connect()
        cursor = conn.execute('''
            SELECT * FROM learnings
            WHERE project_dir = ? AND status != 'archived'
            ORDER BY last_seen DESC
            LIMIT ?
        ''', (project_dir, limit))
        results = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return results

    def archive_stale(self, days: int = 90) -> int:
        """Archive learnings older than N days with low confidence."""
        cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
        conn = self._connect()
        conn.execute('''
            UPDATE learnings
            SET status = 'archived', updated_at = ?
            WHERE status = 'pending'
              AND confidence < 0.7
              AND last_seen < ?
        ''', (datetime.now(timezone.utc).isoformat(), cutoff))
        archived = conn.total_changes
        conn.commit()
        conn.close()
        return archived

    def get_learning(self, fingerprint: str) -> Optional[Dict]:
        """Get a learning by fingerprint."""
        conn = self._connect()
        cursor = conn.execute(
            "SELECT * FROM learnings WHERE fingerprint = ?",
            (fingerprint,)
        )
        row = cursor.fetchone()
        conn.close()
        return dict(row) if row else None

    def set_status(self, fingerprint: str, status: str) -> bool:
        """Set status on a learning and update updated_at."""
        conn = self._connect()
        now = datetime.now(timezone.utc).isoformat()
        conn.execute(
            "UPDATE learnings SET status = ?, updated_at = ? WHERE fingerprint = ?",
            (status, now, fingerprint)
        )
        affected = conn.total_changes
        conn.commit()
        conn.close()
        return affected > 0

    def get_promotion_candidates(self, threshold: int = DEFAULT_PROMOTION_THRESHOLD) -> List[Dict]:
        """Get learnings eligible for promotion to global."""
        conn = self._connect()
        cursor = conn.execute('''
            SELECT * FROM learnings
            WHERE status != 'promoted'
            AND json_array_length(repo_ids) >= ?
            ORDER BY count DESC, last_seen DESC
        ''', (threshold,))

        results = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return results

    def check_promotion_eligibility(self, fingerprint: str, threshold: int = DEFAULT_PROMOTION_THRESHOLD) -> Dict:
        """Check if a learning is eligible for promotion."""
        learning = self.get_learning(fingerprint)

        if not learning:
            return {"eligible": False, "reason": "Learning not found"}

        repo_ids = json.loads(learning['repo_ids'] or '[]')
        repo_count = len(repo_ids)

        if learning['status'] == 'promoted':
            return {
                "eligible": False,
                "reason": "Already promoted",
                "fingerprint": fingerprint,
                "repo_count": repo_count
            }

        eligible = repo_count >= threshold

        return {
            "eligible": eligible,
            "fingerprint": fingerprint,
            "content": learning['content'],
            "repo_count": repo_count,
            "threshold": threshold,
            "reason": f"Seen in {repo_count}/{threshold} repos" if not eligible else "Ready for promotion",
            "skill_name": learning['skill_name']
        }

    def mark_promoted(self, fingerprint: str, reason: str = "Multi-repo threshold") -> bool:
        """Mark a learning as promoted to global."""
        conn = self._connect()
        now = datetime.now(timezone.utc).isoformat()

        conn.execute('''
            UPDATE learnings
            SET status = 'promoted', promoted_at = ?, updated_at = ?
            WHERE fingerprint = ?
        ''', (now, now, fingerprint))

        promo_id = hashlib.md5(f"{fingerprint}{now}".encode()).hexdigest()[:8]
        conn.execute('''
            INSERT INTO promotions (id, fingerprint, from_scope, to_scope, reason)
            VALUES (?, ?, 'skill', 'global', ?)
        ''', (promo_id, fingerprint, reason))

        affected = conn.total_changes
        conn.commit()
        conn.close()
        return affected > 0

    def get_stats(self) -> Dict:
        """Get ledger statistics."""
        conn = self._connect()
        stats = {}

        cursor = conn.execute("SELECT COUNT(*) FROM learnings")
        stats["total_learnings"] = cursor.fetchone()[0]

        cursor = conn.execute('''
            SELECT status, COUNT(*) as count
            FROM learnings GROUP BY status
        ''')
        stats["by_status"] = {row['status'] or 'pending': row['count'] for row in cursor.fetchall()}

        cursor = conn.execute('''
            SELECT skill_name, COUNT(*) as count
            FROM learnings GROUP BY skill_name
            ORDER BY count DESC LIMIT 10
        ''')
        stats["by_skill"] = {row['skill_name']: row['count'] for row in cursor.fetchall()}

        cursor = conn.execute('''
            SELECT learning_type, COUNT(*) as count
            FROM learnings GROUP BY learning_type
            ORDER BY count DESC
        ''')
        stats["by_type"] = {row['learning_type'] or 'unknown': row['count'] for row in cursor.fetchall()}

        cursor = conn.execute('''
            SELECT COUNT(*) FROM learnings
            WHERE json_array_length(repo_ids) >= 2
        ''')
        stats["multi_repo"] = cursor.fetchone()[0]

        cursor = conn.execute('''
            SELECT COUNT(*) FROM learnings
            WHERE status != 'promoted'
            AND json_array_length(repo_ids) >= 2
        ''')
        stats["promotion_eligible"] = cursor.fetchone()[0]

        cursor = conn.execute("SELECT COUNT(*) FROM promotions")
        stats["total_promotions"] = cursor.fetchone()[0]

        cursor = conn.execute("SELECT COUNT(*) FROM learnings WHERE embedding IS NOT NULL")
        stats["with_embeddings"] = cursor.fetchone()[0]

        conn.close()
        return stats

    def get_skill_learnings(self, skill_name: str) -> List[Dict]:
        """Get all learnings for a specific skill."""
        conn = self._connect()
        cursor = conn.execute('''
            SELECT * FROM learnings
            WHERE skill_name = ?
            ORDER BY last_seen DESC
        ''', (skill_name,))

        results = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return results

    def search(self, query: str, limit: int = 20) -> List[Dict]:
        """Search learnings by content (LIKE-based text search)."""
        conn = self._connect()
        cursor = conn.execute('''
            SELECT * FROM learnings
            WHERE content LIKE ?
            AND status != 'archived'
            ORDER BY last_seen DESC
            LIMIT ?
        ''', (f"%{query}%", limit))

        results = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return results


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Learning Ledger CLI")
    subparsers = parser.add_subparsers(dest="command")

    record_parser = subparsers.add_parser("record", help="Record a learning")
    record_parser.add_argument("content", help="Learning content")
    record_parser.add_argument("--type", default="correction", help="Learning type")
    record_parser.add_argument("--skill", default="general", help="Skill name")
    record_parser.add_argument("--confidence", type=float, default=0.5)

    subparsers.add_parser("stats", help="Show statistics")

    cand_parser = subparsers.add_parser("candidates", help="Show promotion candidates")
    cand_parser.add_argument("--threshold", type=int, default=2, help="Repo threshold")

    search_parser = subparsers.add_parser("search", help="Search learnings")
    search_parser.add_argument("query", help="Search query")

    check_parser = subparsers.add_parser("check", help="Check promotion eligibility")
    check_parser.add_argument("fingerprint", help="Learning fingerprint")

    archive_parser = subparsers.add_parser("archive", help="Archive stale learnings")
    archive_parser.add_argument("--days", type=int, default=90)

    args = parser.parse_args()
    ledger = LearningLedger()

    if args.command == "record":
        result = ledger.record_learning(args.content, args.type, args.skill, args.confidence)
        print(json.dumps(result, indent=2))

    elif args.command == "stats":
        stats = ledger.get_stats()
        print(json.dumps(stats, indent=2))

    elif args.command == "candidates":
        candidates = ledger.get_promotion_candidates(args.threshold)
        print(f"Found {len(candidates)} promotion candidates:")
        for c in candidates:
            repos = json.loads(c['repo_ids'] or '[]')
            print(f"  [{c['fingerprint'][:8]}] ({len(repos)} repos) {c['content'][:60]}...")

    elif args.command == "search":
        results = ledger.search(args.query)
        print(json.dumps(results, indent=2))

    elif args.command == "check":
        result = ledger.check_promotion_eligibility(args.fingerprint)
        print(json.dumps(result, indent=2))

    elif args.command == "archive":
        count = ledger.archive_stale(args.days)
        print(f"Archived {count} stale learnings.")

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
