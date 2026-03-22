#!/usr/bin/env python3
"""
Non-interactive auto-extraction of learning signals from transcripts.

Called by the SessionEnd hook. Extracts HIGH/MEDIUM signals and records
them directly to the learning ledger without user interaction.

HIGH confidence → recorded with status='active'
MEDIUM confidence → recorded with status='pending' (queued for review)
LOW confidence → dropped
"""

import os
import sys
import json
import logging
from pathlib import Path
from datetime import datetime

# Ensure the scripts directory is on the path
SCRIPTS_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPTS_DIR))

from extract_signals import extract_signals
from learning_ledger import LearningLedger

LOG_DIR = Path.home() / ".claude" / "logs"
LOG_FILE = LOG_DIR / "auto-learn.log"


def setup_logging():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        filename=str(LOG_FILE),
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )


def auto_extract(transcript_path: str, project_dir: str = None) -> dict:
    """Extract signals from transcript and record to ledger."""
    setup_logging()
    logger = logging.getLogger(__name__)

    project_dir = project_dir or os.getcwd()
    timestamp = datetime.utcnow().isoformat()

    logger.info(f"auto_extract start transcript={transcript_path} project={project_dir}")

    try:
        signals_by_skill = extract_signals(transcript_path, use_semantic=False)
    except Exception as e:
        logger.error(f"extract_signals failed: {e}")
        return {"error": str(e), "recorded": 0}

    ledger = LearningLedger()
    recorded = 0
    pending = 0
    dropped = 0

    for skill_name, signals in signals_by_skill.items():
        for signal in signals:
            confidence_label = signal.get("confidence", "LOW")
            confidence_score = signal.get("confidence_score", 0.5)
            signal_type = signal.get("type", "correction")

            # Use the extracted_learning if available, else fall back to description or content
            content = (
                signal.get("extracted_learning")
                or signal.get("description")
                or signal.get("content", "")
            )
            if not content or len(content.strip()) < 10:
                dropped += 1
                continue

            if confidence_label == "HIGH":
                result = ledger.record_learning(
                    content=content,
                    learning_type=signal_type,
                    skill_name=skill_name,
                    confidence=confidence_score,
                    project_dir=project_dir,
                )
                # Immediately mark as active
                if result.get("action") == "created":
                    ledger.set_status(result["fingerprint"], "active")
                recorded += 1
                logger.info(f"recorded HIGH [{signal_type}] {content[:60]}")

            elif confidence_label == "MEDIUM":
                ledger.record_learning(
                    content=content,
                    learning_type=signal_type,
                    skill_name=skill_name,
                    confidence=confidence_score,
                    project_dir=project_dir,
                )
                pending += 1
                logger.info(f"queued MEDIUM [{signal_type}] {content[:60]}")

            else:
                dropped += 1

    summary = {
        "timestamp": timestamp,
        "transcript": transcript_path,
        "project_dir": project_dir,
        "recorded": recorded,
        "pending": pending,
        "dropped": dropped,
    }
    logger.info(f"auto_extract done: {summary}")
    return summary


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Auto-extract learning signals from transcript")
    parser.add_argument("transcript", nargs="?", help="Path to transcript file")
    parser.add_argument("--project-dir", help="Project directory (defaults to cwd)")
    args = parser.parse_args()

    result = auto_extract(
        transcript_path=args.transcript,
        project_dir=args.project_dir,
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
