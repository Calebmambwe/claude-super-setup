#!/usr/bin/env python3
"""
LobeHub agent format converter: LobeHub JSON -> our Markdown agent format.

Usage (CLI):
    python3 scripts/agent-converter.py import agent.json
    python3 scripts/agent-converter.py import agent.json --output-dir agents/community/imported/
    python3 scripts/agent-converter.py import https://example.com/agent.json

Usage (module):
    from agent_converter import lobehub_to_markdown
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import sys
import urllib.request
import urllib.error
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s: %(message)s",
)
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Model tier mapping
# ---------------------------------------------------------------------------

# Maps known LobeHub/OpenAI/Anthropic model strings to our three tiers.
# Unrecognised models fall back to "sonnet" (middle ground).
_MODEL_TIER_MAP: dict[str, str] = {
    # Opus-tier (most capable / expensive)
    "gpt-4": "opus",
    "gpt-4-turbo": "opus",
    "gpt-4-turbo-preview": "opus",
    "gpt-4o": "opus",
    "gpt-4-32k": "opus",
    "claude-opus": "opus",
    "claude-3-opus": "opus",
    "claude-3-opus-20240229": "opus",
    "claude-opus-4": "opus",
    "o1": "opus",
    "o1-preview": "opus",
    "o3": "opus",
    # Sonnet-tier (balanced)
    "gpt-3.5-turbo": "sonnet",
    "gpt-3.5-turbo-16k": "sonnet",
    "claude-sonnet": "sonnet",
    "claude-3-sonnet": "sonnet",
    "claude-3-sonnet-20240229": "sonnet",
    "claude-3-5-sonnet": "sonnet",
    "claude-3-5-sonnet-20241022": "sonnet",
    "claude-sonnet-4": "sonnet",
    "o1-mini": "sonnet",
    "o3-mini": "sonnet",
    # Haiku-tier (fast / cheap)
    "gpt-3.5": "haiku",
    "claude-haiku": "haiku",
    "claude-3-haiku": "haiku",
    "claude-3-haiku-20240307": "haiku",
    "claude-3-5-haiku": "haiku",
}

_VALID_TIERS = {"haiku", "sonnet", "opus", "custom"}


def _map_model(model_str: str | None) -> str:
    """Return our model tier for a raw LobeHub model string."""
    if not model_str:
        return "sonnet"
    normalised = model_str.lower().strip()
    if normalised in _MODEL_TIER_MAP:
        return _MODEL_TIER_MAP[normalised]
    # Partial match heuristics
    if "opus" in normalised or "gpt-4" in normalised or "o1" in normalised or "o3" in normalised:
        return "opus"
    if "haiku" in normalised or "3.5" in normalised:
        return "haiku"
    log.warning("Unrecognised model %r — defaulting to 'sonnet'", model_str)
    return "sonnet"


# ---------------------------------------------------------------------------
# Name sanitisation
# ---------------------------------------------------------------------------

def _to_kebab(text: str) -> str:
    """Convert an arbitrary string to a valid kebab-case agent identifier."""
    # Lowercase and replace non-alphanumeric sequences with hyphens
    result = re.sub(r"[^a-z0-9]+", "-", text.lower().strip())
    # Strip leading/trailing hyphens
    result = result.strip("-")
    # Must start with a letter (schema requires ^[a-z][a-z0-9-]*$)
    if result and not result[0].isalpha():
        result = "agent-" + result
    # Collapse multiple hyphens that might have survived
    result = re.sub(r"-{2,}", "-", result)
    return result or "imported-agent"


# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------

@dataclass
class LobeHubConfig:
    """Parsed representation of the LobeHub JSON config block."""
    system_role: str = ""
    model: str | None = None
    params: dict[str, Any] = field(default_factory=dict)
    display_mode: str | None = None
    enable_history_count: bool = False
    history_count: int | None = None


@dataclass
class LobeHubMeta:
    """Parsed representation of the LobeHub JSON meta block."""
    avatar: str = ""
    tags: list[str] = field(default_factory=list)
    title: str = "Untitled Agent"
    description: str = ""


@dataclass
class LobeHubAgent:
    """Full parsed LobeHub agent."""
    author: str = ""
    homepage: str = ""
    identifier: str = ""
    locale: str = "en-US"
    config: LobeHubConfig = field(default_factory=LobeHubConfig)
    meta: LobeHubMeta = field(default_factory=LobeHubMeta)

    # Populated after parsing
    agent_name: str = ""     # kebab-case identifier for our system
    model_tier: str = "sonnet"


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------

def _parse_lobehub(raw: dict[str, Any]) -> LobeHubAgent:
    """Parse a raw LobeHub JSON dict into a LobeHubAgent dataclass."""

    # --- config block ---
    cfg_raw: dict[str, Any] = raw.get("config") or {}
    config = LobeHubConfig(
        system_role=cfg_raw.get("systemRole") or "",
        model=cfg_raw.get("model"),
        params=cfg_raw.get("params") or {},
        display_mode=cfg_raw.get("displayMode"),
        enable_history_count=bool(cfg_raw.get("enableHistoryCount", False)),
        history_count=cfg_raw.get("historyCount"),
    )

    # --- meta block ---
    meta_raw: dict[str, Any] = raw.get("meta") or {}
    tags_raw = meta_raw.get("tags") or []
    tags: list[str] = [str(t) for t in tags_raw if t]

    meta = LobeHubMeta(
        avatar=str(meta_raw.get("avatar") or ""),
        tags=tags,
        title=str(meta_raw.get("title") or "Untitled Agent").strip(),
        description=str(meta_raw.get("description") or "").strip(),
    )

    agent = LobeHubAgent(
        author=str(raw.get("author") or "").strip(),
        homepage=str(raw.get("homepage") or "").strip(),
        identifier=str(raw.get("identifier") or "").strip(),
        locale=str(raw.get("locale") or "en-US"),
        config=config,
        meta=meta,
    )

    # Derive our fields
    agent.agent_name = _to_kebab(meta.title) if meta.title else _to_kebab(agent.identifier)
    agent.model_tier = _map_model(config.model)

    return agent


# ---------------------------------------------------------------------------
# Renderer
# ---------------------------------------------------------------------------

def _render_frontmatter(agent: LobeHubAgent) -> str:
    """Render the YAML frontmatter block for our Markdown format."""
    lines: list[str] = ["---"]

    lines.append(f"name: {agent.agent_name}")

    # Department defaults to "community" for imported agents
    lines.append("department: community")

    description = agent.meta.description or f"Imported LobeHub agent: {agent.meta.title}"
    # Ensure minimum length to satisfy schema (minLength: 10)
    if len(description) < 10:
        description = description + " (imported from LobeHub)"
    lines.append(f"description: {description}")

    lines.append(f"model: {agent.model_tier}")

    if agent.meta.tags:
        tags_yaml = ", ".join(agent.meta.tags)
        lines.append(f"tags: [{tags_yaml}]")

    if agent.meta.avatar:
        lines.append(f"avatar: {agent.meta.avatar}")

    if agent.author:
        lines.append(f"author: {agent.author}")

    if agent.homepage:
        lines.append(f"homepage: {agent.homepage}")

    if agent.identifier:
        lines.append(f"lobehub_id: {agent.identifier}")

    lines.append("source: lobehub")
    lines.append("---")

    return "\n".join(lines)


def _render_config_note(agent: LobeHubAgent) -> str:
    """Render an optional config-note section for LobeHub-specific params."""
    config = agent.config
    lines: list[str] = []

    has_params = bool(config.params)
    has_history = config.enable_history_count and config.history_count is not None
    has_display = bool(config.display_mode)
    has_model = bool(config.model)

    if not (has_params or has_history or has_display or has_model):
        return ""

    lines.append("## LobeHub Configuration")
    lines.append("")
    lines.append("_Original LobeHub settings preserved for reference:_")
    lines.append("")

    if has_model:
        lines.append(f"- **Original model:** `{config.model}` → mapped to `{agent.model_tier}`")

    if has_display:
        lines.append(f"- **Display mode:** {config.display_mode}")

    if has_history:
        lines.append(f"- **History:** enabled, {config.history_count} turns")

    if has_params:
        lines.append("- **Sampling parameters:**")
        for key, value in sorted(config.params.items()):
            lines.append(f"  - `{key}`: {value}")

    return "\n".join(lines)


def lobehub_to_markdown(raw: dict[str, Any]) -> tuple[str, str]:
    """
    Convert a LobeHub agent JSON dict to our Markdown agent format.

    Returns:
        (filename, markdown_content)
        - filename: suggested output filename, e.g. "code-explainer.md"
        - markdown_content: full Markdown text with YAML frontmatter

    Raises:
        ValueError: if the input dict is missing required structure.
    """
    if not isinstance(raw, dict):
        raise ValueError(f"Expected a JSON object (dict), got {type(raw).__name__}")

    agent = _parse_lobehub(raw)

    # Warn on important missing fields
    if not agent.meta.title or agent.meta.title == "Untitled Agent":
        log.warning("No meta.title found; agent will be named 'untitled-agent'")
    if not agent.config.system_role:
        log.warning("config.systemRole is empty — the agent body will have a placeholder")
    if not agent.meta.description:
        log.warning("No meta.description found — a default description will be used")

    # Build the document sections
    frontmatter = _render_frontmatter(agent)

    heading = f"# {agent.meta.title}"

    # System prompt body
    system_role = agent.config.system_role.strip()
    if system_role:
        body = system_role
    else:
        body = "_No system prompt provided in the original LobeHub agent._"

    config_note = _render_config_note(agent)

    # Assemble the full document
    parts = [frontmatter, heading, body]
    if config_note:
        parts.append(config_note)

    content = "\n\n".join(parts) + "\n"
    filename = f"{agent.agent_name}.md"

    return filename, content


# ---------------------------------------------------------------------------
# JSON / URL loading
# ---------------------------------------------------------------------------

def _load_json_from_path(path: Path) -> dict[str, Any]:
    """Load and parse a JSON file from a local path."""
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise SystemExit(f"Cannot read file {path}: {exc}") from exc
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"Expected a JSON object at the top level, got {type(data).__name__}")
    return data


def _load_json_from_url(url: str) -> dict[str, Any]:
    """Download and parse a JSON file from a URL."""
    log.info("Fetching %s", url)
    try:
        with urllib.request.urlopen(url, timeout=30) as response:  # noqa: S310
            raw_bytes = response.read()
    except urllib.error.URLError as exc:
        raise SystemExit(f"Failed to fetch {url}: {exc}") from exc
    try:
        data = json.loads(raw_bytes)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON from {url}: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"Expected a JSON object at the top level, got {type(data).__name__}")
    return data


def _load_source(source: str) -> dict[str, Any]:
    """Load LobeHub JSON from a local file path or HTTP(S) URL."""
    if source.startswith("http://") or source.startswith("https://"):
        return _load_json_from_url(source)
    path = Path(source)
    if not path.exists():
        raise SystemExit(f"File not found: {source}")
    return _load_json_from_path(path)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _cmd_import(args: argparse.Namespace) -> None:
    """Handle the `import` sub-command."""
    raw = _load_source(args.source)

    try:
        filename, content = lobehub_to_markdown(raw)
    except ValueError as exc:
        raise SystemExit(f"Conversion failed: {exc}") from exc

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    output_path = output_dir / filename

    # Avoid silent overwrites unless --force is given
    if output_path.exists() and not args.force:
        raise SystemExit(
            f"Output file already exists: {output_path}\n"
            "Use --force to overwrite."
        )

    output_path.write_text(content, encoding="utf-8")
    log.info("Written: %s", output_path.resolve())
    print(str(output_path.resolve()))


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="agent-converter.py",
        description="Convert LobeHub agent JSON to our Markdown agent format.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    import_parser = sub.add_parser(
        "import",
        help="Convert a LobeHub JSON file (or URL) to our Markdown format.",
    )
    import_parser.add_argument(
        "source",
        metavar="<json-file-or-url>",
        help="Path to a local .json file, or an HTTPS URL.",
    )
    import_parser.add_argument(
        "--output-dir",
        default="agents/community/imported",
        metavar="DIR",
        help="Directory to write the converted Markdown file into. "
             "(default: agents/community/imported)",
    )
    import_parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite the output file if it already exists.",
    )

    return parser


def main(argv: list[str] | None = None) -> None:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.command == "import":
        _cmd_import(args)
    else:
        # Should never reach here because sub-commands are required
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
