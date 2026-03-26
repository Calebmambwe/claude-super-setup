#!/usr/bin/env python3
"""
improvement-report.py — Generate an improvement report from benchmarks/history.jsonl

Usage:
    python3 scripts/improvement-report.py
    python3 scripts/improvement-report.py --telegram     # Telegram-friendly output (<4096 chars)
    python3 scripts/improvement-report.py --task reg-001 # Report for a single task
    python3 scripts/improvement-report.py --last 10      # Analyse only the last N runs
    python3 scripts/improvement-report.py --out report.md # Write to file

Reads benchmarks/history.jsonl and produces:
- Overall score trend (ascending / descending / flat)
- Improvement rate (% of runs that beat the previous run)
- Regression count
- Best and worst performing tasks
- Markdown report (or Telegram-condensed version)
"""

import argparse
import json
import math
import os
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
HISTORY_FILE = PROJECT_ROOT / "benchmarks" / "history.jsonl"


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def load_history(history_file: Path, last_n: int = 0) -> list[dict]:
    """Load benchmark history from JSONL. Returns list sorted oldest-first."""
    if not history_file.exists():
        print(f"ERROR: {history_file} not found. Run /benchmark first.", file=sys.stderr)
        sys.exit(1)

    records = []
    with open(history_file) as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(f"WARNING: Skipping malformed line {line_num}: {e}", file=sys.stderr)

    if not records:
        print("ERROR: No records found in history.jsonl.", file=sys.stderr)
        sys.exit(1)

    # Sort by timestamp ascending
    records.sort(key=lambda r: r.get("timestamp", ""))

    if last_n > 0:
        records = records[-last_n:]

    return records


# ---------------------------------------------------------------------------
# Analysis
# ---------------------------------------------------------------------------

def group_by_run(records: list[dict]) -> dict[str, list[dict]]:
    """Group records by run_id, preserving order."""
    runs: dict[str, list[dict]] = defaultdict(list)
    for rec in records:
        runs[rec.get("run_id", "unknown")].append(rec)
    return dict(runs)


def run_score(run_records: list[dict]) -> float:
    """Compute average score for a single run."""
    if not run_records:
        return 0.0
    return sum(r.get("score", 0) for r in run_records) / len(run_records)


def run_pass_rate(run_records: list[dict]) -> float:
    """Compute pass rate (fraction of tasks that passed) for a single run."""
    if not run_records:
        return 0.0
    passed = sum(1 for r in run_records if r.get("pass") is True)
    return passed / len(run_records)


def compute_trend(scores: list[float]) -> str:
    """
    Linear regression slope on scores over time.
    Returns 'ascending', 'descending', or 'flat'.
    """
    n = len(scores)
    if n < 2:
        return "flat"

    x_mean = (n - 1) / 2.0
    y_mean = sum(scores) / n

    numerator = sum((i - x_mean) * (scores[i] - y_mean) for i in range(n))
    denominator = sum((i - x_mean) ** 2 for i in range(n))

    if denominator == 0:
        return "flat"

    slope = numerator / denominator

    if slope > 0.5:
        return "ascending"
    elif slope < -0.5:
        return "descending"
    return "flat"


def compute_improvement_rate(run_scores: list[float]) -> float:
    """
    Percentage of consecutive run pairs where the score improved.
    e.g., [70, 75, 72, 80] → 2 improvements out of 3 pairs → 66.7%
    """
    if len(run_scores) < 2:
        return 0.0
    improvements = sum(
        1 for a, b in zip(run_scores, run_scores[1:]) if b > a
    )
    return (improvements / (len(run_scores) - 1)) * 100.0


def compute_per_task_stats(records: list[dict]) -> dict[str, dict]:
    """
    For each task_id, compute: avg_score, min_score, max_score,
    pass_rate, regression_count, run_count.
    """
    task_data: dict[str, list[dict]] = defaultdict(list)
    for rec in records:
        task_id = rec.get("task_id", "unknown")
        task_data[task_id].append(rec)

    stats = {}
    for task_id, task_records in task_data.items():
        scores = [r.get("score", 0) for r in task_records]
        passed = sum(1 for r in task_records if r.get("pass") is True)
        regressions = sum(1 for r in task_records if r.get("regression") is True)
        category = task_records[-1].get("category", "unknown")

        stats[task_id] = {
            "task_id": task_id,
            "category": category,
            "run_count": len(task_records),
            "avg_score": sum(scores) / len(scores),
            "min_score": min(scores),
            "max_score": max(scores),
            "pass_rate": (passed / len(task_records)) * 100.0,
            "regression_count": regressions,
        }

    return stats


def analyse(records: list[dict]) -> dict:
    """Run full analysis on the loaded records."""
    runs = group_by_run(records)
    run_ids = list(runs.keys())
    run_scores = [run_score(runs[rid]) for rid in run_ids]
    run_timestamps = [
        runs[rid][0].get("timestamp", "") for rid in run_ids
    ]

    total_regressions = sum(
        1 for r in records if r.get("regression") is True
    )
    total_runs = len(run_ids)
    total_tasks = len(set(r.get("task_id") for r in records))
    overall_avg = sum(run_scores) / len(run_scores) if run_scores else 0.0
    trend = compute_trend(run_scores)
    improvement_rate = compute_improvement_rate(run_scores)

    per_task = compute_per_task_stats(records)

    # Best tasks: highest avg_score with >= 3 runs
    best_tasks = sorted(
        [t for t in per_task.values() if t["run_count"] >= 3],
        key=lambda t: t["avg_score"],
        reverse=True,
    )[:5]

    # Worst tasks: lowest avg_score with >= 3 runs
    worst_tasks = sorted(
        [t for t in per_task.values() if t["run_count"] >= 3],
        key=lambda t: t["avg_score"],
    )[:5]

    # Most regressed
    most_regressed = sorted(
        per_task.values(),
        key=lambda t: t["regression_count"],
        reverse=True,
    )[:3]

    # Recent vs earlier comparison (split records in half)
    mid = len(run_scores) // 2
    if mid >= 1:
        earlier_avg = sum(run_scores[:mid]) / mid
        recent_avg = sum(run_scores[mid:]) / len(run_scores[mid:])
        period_delta = recent_avg - earlier_avg
    else:
        earlier_avg = overall_avg
        recent_avg = overall_avg
        period_delta = 0.0

    # First and last run timestamps for the report header
    first_ts = run_timestamps[0] if run_timestamps else "unknown"
    last_ts = run_timestamps[-1] if run_timestamps else "unknown"

    return {
        "total_runs": total_runs,
        "total_tasks": total_tasks,
        "total_records": len(records),
        "total_regressions": total_regressions,
        "overall_avg_score": overall_avg,
        "trend": trend,
        "improvement_rate": improvement_rate,
        "run_scores": run_scores,
        "run_ids": run_ids,
        "earlier_avg": earlier_avg,
        "recent_avg": recent_avg,
        "period_delta": period_delta,
        "best_tasks": best_tasks,
        "worst_tasks": worst_tasks,
        "most_regressed": most_regressed,
        "first_ts": first_ts,
        "last_ts": last_ts,
        "per_task": per_task,
    }


# ---------------------------------------------------------------------------
# Report rendering
# ---------------------------------------------------------------------------

TREND_SYMBOL = {
    "ascending": "↑ Ascending",
    "descending": "↓ Descending",
    "flat": "→ Flat",
}


def render_markdown(analysis: dict) -> str:
    """Render the full Markdown improvement report."""
    a = analysis
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    trend_label = TREND_SYMBOL.get(a["trend"], a["trend"])
    delta_sign = "+" if a["period_delta"] >= 0 else ""
    delta_label = f"{delta_sign}{a['period_delta']:.1f}%"

    lines = [
        "# Agent Benchmark Improvement Report",
        "",
        f"**Generated:** {now}  ",
        f"**Data range:** {a['first_ts']} → {a['last_ts']}  ",
        f"**Total runs:** {a['total_runs']}  ",
        f"**Unique tasks:** {a['total_tasks']}  ",
        f"**Total records:** {a['total_records']}",
        "",
        "---",
        "",
        "## Summary",
        "",
        f"| Metric | Value |",
        f"|--------|-------|",
        f"| Overall Average Score | {a['overall_avg_score']:.1f}% |",
        f"| Score Trend | {trend_label} |",
        f"| Improvement Rate | {a['improvement_rate']:.1f}% of runs beat previous |",
        f"| Total Regressions | {a['total_regressions']} |",
        f"| Period Delta (first half vs second half) | {delta_label} |",
        f"| Earlier Period Average | {a['earlier_avg']:.1f}% |",
        f"| Recent Period Average | {a['recent_avg']:.1f}% |",
        "",
    ]

    # Score history table (last 10 runs)
    lines += [
        "## Score History (Last 10 Runs)",
        "",
        "| Run ID | Score |",
        "|--------|-------|",
    ]
    recent_runs = list(zip(a["run_ids"], a["run_scores"]))[-10:]
    for run_id, score in recent_runs:
        lines.append(f"| {run_id} | {score:.1f}% |")
    lines.append("")

    # Best tasks
    if a["best_tasks"]:
        lines += [
            "## Best Performing Tasks",
            "",
            "| Task | Category | Avg Score | Pass Rate | Runs |",
            "|------|----------|-----------|-----------|------|",
        ]
        for t in a["best_tasks"]:
            lines.append(
                f"| {t['task_id']} | {t['category']} | {t['avg_score']:.1f}% "
                f"| {t['pass_rate']:.1f}% | {t['run_count']} |"
            )
        lines.append("")

    # Worst tasks
    if a["worst_tasks"]:
        lines += [
            "## Worst Performing Tasks",
            "",
            "| Task | Category | Avg Score | Pass Rate | Regressions | Runs |",
            "|------|----------|-----------|-----------|-------------|------|",
        ]
        for t in a["worst_tasks"]:
            lines.append(
                f"| {t['task_id']} | {t['category']} | {t['avg_score']:.1f}% "
                f"| {t['pass_rate']:.1f}% | {t['regression_count']} | {t['run_count']} |"
            )
        lines.append("")

    # Most regressed
    if a["most_regressed"] and a["most_regressed"][0]["regression_count"] > 0:
        lines += [
            "## Most Regressed Tasks",
            "",
            "| Task | Category | Regressions | Avg Score |",
            "|------|----------|-------------|-----------|",
        ]
        for t in a["most_regressed"]:
            if t["regression_count"] == 0:
                continue
            lines.append(
                f"| {t['task_id']} | {t['category']} "
                f"| {t['regression_count']} | {t['avg_score']:.1f}% |"
            )
        lines.append("")

    # Assessment and recommendations
    lines += ["## Assessment", ""]

    if a["trend"] == "ascending":
        lines.append("**Agent quality is improving.** Score trend is positive over the recorded history.")
    elif a["trend"] == "descending":
        lines.append(
            "**WARNING: Agent quality is declining.** Score trend is negative. "
            "Run `/evolve-skills` to address underperforming skills."
        )
    else:
        lines.append("**Agent quality is stable.** No significant upward or downward trend detected.")

    lines.append("")

    if a["improvement_rate"] >= 60:
        lines.append(f"- Improvement rate: {a['improvement_rate']:.1f}% — most runs are progressing.")
    elif a["improvement_rate"] >= 40:
        lines.append(f"- Improvement rate: {a['improvement_rate']:.1f}% — mixed results, some runs regress.")
    else:
        lines.append(
            f"- Improvement rate: {a['improvement_rate']:.1f}% — more runs regress than improve. "
            "Consider running `/self-improve` to trigger a full improvement cycle."
        )

    if a["total_regressions"] > 0:
        lines.append(
            f"- {a['total_regressions']} regression(s) recorded across all runs. "
            "Inspect `benchmarks/history.jsonl` for details."
        )

    if a["period_delta"] > 5:
        lines.append(f"- Period delta: {delta_label} — recent runs are outperforming earlier runs.")
    elif a["period_delta"] < -5:
        lines.append(
            f"- Period delta: {delta_label} — recent runs are underperforming earlier runs. "
            "This may indicate skill degradation after recent changes."
        )

    lines += [
        "",
        "## Recommended Actions",
        "",
    ]

    worst_below_70 = [t for t in (a["worst_tasks"] or []) if t["avg_score"] < 70]
    if worst_below_70:
        task_names = ", ".join(t["task_id"] for t in worst_below_70)
        lines.append(f"- Run `/evolve-skills` — tasks below 70% avg: {task_names}")
    else:
        lines.append("- All tracked tasks average above 70% — no immediate skill evolution needed.")

    lines += [
        "- Run `/benchmark` weekly to maintain score history.",
        "- Schedule automated improvement: `/telegram-cron \"0 3 * * 0\" /self-improve --quick --notify`",
        "",
    ]

    return "\n".join(lines)


def render_telegram(analysis: dict, max_chars: int = 4096) -> str:
    """Render a condensed Telegram-friendly report."""
    a = analysis
    trend_label = TREND_SYMBOL.get(a["trend"], a["trend"])
    delta_sign = "+" if a["period_delta"] >= 0 else ""

    worst_line = ""
    if a["worst_tasks"]:
        worst = a["worst_tasks"][0]
        worst_line = f"\nWorst: {worst['task_id']} ({worst['avg_score']:.0f}% avg)"

    best_line = ""
    if a["best_tasks"]:
        best = a["best_tasks"][0]
        best_line = f"\nBest: {best['task_id']} ({best['avg_score']:.0f}% avg)"

    recent_runs = list(zip(a["run_ids"], a["run_scores"]))[-3:]
    history_line = " | ".join(f"{rid.split('-', 1)[-1]}: {sc:.0f}%" for rid, sc in recent_runs)

    text = (
        f"Benchmark Improvement Report\n"
        f"{'=' * 30}\n"
        f"Avg Score:        {a['overall_avg_score']:.1f}%\n"
        f"Trend:            {trend_label}\n"
        f"Improvement Rate: {a['improvement_rate']:.1f}%\n"
        f"Regressions:      {a['total_regressions']}\n"
        f"Period Delta:     {delta_sign}{a['period_delta']:.1f}%\n"
        f"Runs Analysed:    {a['total_runs']}"
        f"{best_line}"
        f"{worst_line}\n"
        f"\nRecent Runs: {history_line}\n"
    )

    if a["trend"] == "descending":
        text += "\nWARNING: Score is declining. Run /self-improve."
    elif a["improvement_rate"] < 40:
        text += "\nTIP: Low improvement rate. Run /evolve-skills."
    else:
        text += "\nSystem health: OK"

    if len(text) > max_chars:
        text = text[: max_chars - 3] + "..."

    return text


def render_task_report(analysis: dict, task_id: str) -> str:
    """Render a single-task report."""
    task = analysis["per_task"].get(task_id)
    if not task:
        return f"ERROR: Task '{task_id}' not found in history."

    return (
        f"# Task Report: {task_id}\n\n"
        f"| Metric | Value |\n"
        f"|--------|-------|\n"
        f"| Category | {task['category']} |\n"
        f"| Run Count | {task['run_count']} |\n"
        f"| Avg Score | {task['avg_score']:.1f}% |\n"
        f"| Min Score | {task['min_score']}% |\n"
        f"| Max Score | {task['max_score']}% |\n"
        f"| Pass Rate | {task['pass_rate']:.1f}% |\n"
        f"| Regressions | {task['regression_count']} |\n"
    )


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate an improvement report from benchmarks/history.jsonl"
    )
    parser.add_argument(
        "--telegram",
        action="store_true",
        help="Output condensed Telegram-friendly report (<4096 chars)",
    )
    parser.add_argument(
        "--task",
        metavar="TASK_ID",
        help="Report for a single task only (e.g. reg-001)",
    )
    parser.add_argument(
        "--last",
        type=int,
        default=0,
        metavar="N",
        help="Analyse only the last N records (0 = all)",
    )
    parser.add_argument(
        "--out",
        metavar="FILE",
        help="Write report to a file instead of stdout",
    )
    parser.add_argument(
        "--history",
        metavar="FILE",
        default=str(HISTORY_FILE),
        help=f"Path to history.jsonl (default: {HISTORY_FILE})",
    )
    args = parser.parse_args()

    history_path = Path(args.history)
    records = load_history(history_path, last_n=args.last)
    analysis = analyse(records)

    if args.task:
        report = render_task_report(analysis, args.task)
    elif args.telegram:
        report = render_telegram(analysis)
    else:
        report = render_markdown(analysis)

    if args.out:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(report)
        print(f"Report written to {out_path}")
    else:
        print(report)


if __name__ == "__main__":
    main()
