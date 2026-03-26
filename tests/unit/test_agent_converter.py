"""
Unit tests for scripts/agent-converter.py

Tests target the pure-logic helpers:
  - lobehub_to_markdown  (full pipeline)
  - _map_model           (model tier mapping)
  - _to_kebab            (name sanitisation)
  - _parse_lobehub       (JSON parser)
  - _render_frontmatter  (YAML block)

Run independently:
    pytest tests/unit/test_agent_converter.py -v
"""
from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import pytest

# ---------------------------------------------------------------------------
# Source import — also works standalone (conftest.py handles it for the suite)
# ---------------------------------------------------------------------------
_REPO_ROOT = Path(__file__).resolve().parents[2]
_SCRIPTS_DIR = str(_REPO_ROOT / "scripts")
if _SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, _SCRIPTS_DIR)

import importlib.util as _ilu

_spec = _ilu.spec_from_file_location(
    "agent_converter",
    _REPO_ROOT / "scripts" / "agent-converter.py",
)
assert _spec and _spec.loader
_ac = _ilu.module_from_spec(_spec)
sys.modules["agent_converter"] = _ac
_spec.loader.exec_module(_ac)  # type: ignore[union-attr]

lobehub_to_markdown = _ac.lobehub_to_markdown
_map_model = _ac._map_model
_to_kebab = _ac._to_kebab
_parse_lobehub = _ac._parse_lobehub
_render_frontmatter = _ac._render_frontmatter


# ===========================================================================
# lobehub_to_markdown — full pipeline
# ===========================================================================

class TestLobeHubToMarkdown:
    def test_returns_tuple_of_filename_and_content(self, lobehub_agent_full: dict[str, Any]) -> None:
        filename, content = lobehub_to_markdown(lobehub_agent_full)
        assert isinstance(filename, str)
        assert isinstance(content, str)
        assert filename.endswith(".md")

    def test_filename_is_kebab_case(self, lobehub_agent_full: dict[str, Any]) -> None:
        filename, _ = lobehub_to_markdown(lobehub_agent_full)
        # title is "Code Explainer" → "code-explainer.md"
        assert filename == "code-explainer.md"

    def test_content_has_yaml_frontmatter(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert content.startswith("---\n")
        assert "\n---\n" in content

    def test_frontmatter_contains_name(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert "name: code-explainer" in content

    def test_frontmatter_department_is_community(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert "department: community" in content

    def test_frontmatter_model_is_mapped(self, lobehub_agent_full: dict[str, Any]) -> None:
        # model gpt-4 → opus
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert "model: opus" in content

    def test_frontmatter_source_is_lobehub(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert "source: lobehub" in content

    def test_frontmatter_contains_tags(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert "tags: [code, education, programming]" in content

    def test_content_contains_h1_title(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert "# Code Explainer" in content

    def test_content_contains_system_role(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert "expert code explainer" in content

    def test_content_contains_lobehub_config_section(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        # Has model + params in config block
        assert "## LobeHub Configuration" in content

    def test_empty_system_role_gets_placeholder(self, lobehub_agent_empty_system_role: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_empty_system_role)
        assert "_No system prompt provided" in content

    def test_missing_meta_uses_defaults(self, lobehub_agent_no_meta: dict[str, Any]) -> None:
        filename, content = lobehub_to_markdown(lobehub_agent_no_meta)
        # Should not crash; identifier is used as fallback
        assert filename.endswith(".md")
        assert "---" in content

    def test_raises_on_non_dict_input(self) -> None:
        with pytest.raises(ValueError, match="Expected a JSON object"):
            lobehub_to_markdown(["not", "a", "dict"])  # type: ignore[arg-type]

    def test_author_in_frontmatter(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert "author: alice" in content

    def test_homepage_in_frontmatter(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert "homepage: https://example.com/agent" in content

    def test_lobehub_id_in_frontmatter(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert "lobehub_id: code-explainer" in content

    def test_content_ends_with_newline(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        assert content.endswith("\n")


# ===========================================================================
# _map_model — model tier mapping
# ===========================================================================

class TestMapModel:
    def test_gpt4_maps_to_opus(self) -> None:
        assert _map_model("gpt-4") == "opus"

    def test_gpt4_turbo_maps_to_opus(self) -> None:
        assert _map_model("gpt-4-turbo") == "opus"

    def test_gpt4o_maps_to_opus(self) -> None:
        assert _map_model("gpt-4o") == "opus"

    def test_claude_opus_maps_to_opus(self) -> None:
        assert _map_model("claude-opus") == "opus"

    def test_claude_3_opus_maps_to_opus(self) -> None:
        assert _map_model("claude-3-opus") == "opus"

    def test_o1_maps_to_opus(self) -> None:
        assert _map_model("o1") == "opus"

    def test_gpt35_turbo_maps_to_sonnet(self) -> None:
        assert _map_model("gpt-3.5-turbo") == "sonnet"

    def test_claude_sonnet_maps_to_sonnet(self) -> None:
        assert _map_model("claude-sonnet") == "sonnet"

    def test_claude_3_5_sonnet_maps_to_sonnet(self) -> None:
        assert _map_model("claude-3-5-sonnet") == "sonnet"

    def test_o1_mini_maps_to_sonnet(self) -> None:
        assert _map_model("o1-mini") == "sonnet"

    def test_claude_haiku_maps_to_haiku(self) -> None:
        assert _map_model("claude-haiku") == "haiku"

    def test_claude_3_haiku_maps_to_haiku(self) -> None:
        assert _map_model("claude-3-haiku") == "haiku"

    def test_unknown_model_defaults_to_sonnet(self) -> None:
        assert _map_model("some-unknown-model-xyz") == "sonnet"

    def test_none_defaults_to_sonnet(self) -> None:
        assert _map_model(None) == "sonnet"

    def test_empty_string_defaults_to_sonnet(self) -> None:
        assert _map_model("") == "sonnet"

    def test_case_insensitive(self) -> None:
        assert _map_model("GPT-4") == "opus"
        assert _map_model("Claude-Haiku") == "haiku"

    def test_partial_opus_match(self) -> None:
        # Any model containing 'opus' → opus
        assert _map_model("my-custom-opus-model") == "opus"

    def test_partial_haiku_match(self) -> None:
        assert _map_model("custom-haiku-lite") == "haiku"

    def test_leading_trailing_whitespace_stripped(self) -> None:
        assert _map_model("  gpt-4  ") == "opus"


# ===========================================================================
# _to_kebab — name sanitisation
# ===========================================================================

class TestToKebab:
    def test_simple_lowercase(self) -> None:
        assert _to_kebab("hello world") == "hello-world"

    def test_special_characters_removed(self) -> None:
        # "AI & ML: Data-Scientist (v2)!" → "ai-ml-data-scientist-v2"
        assert _to_kebab("AI & ML: Data-Scientist (v2)!") == "ai-ml-data-scientist-v2"

    def test_leading_trailing_hyphens_stripped(self) -> None:
        result = _to_kebab("  ---hello---  ")
        assert not result.startswith("-")
        assert not result.endswith("-")

    def test_multiple_hyphens_collapsed(self) -> None:
        # Two special chars in a row would produce double hyphens
        result = _to_kebab("hello!!world")
        assert "--" not in result

    def test_starts_with_digit_gets_prefix(self) -> None:
        result = _to_kebab("42 agent")
        assert result.startswith("agent-")

    def test_already_kebab_unchanged(self) -> None:
        assert _to_kebab("my-agent-name") == "my-agent-name"

    def test_empty_string_fallback(self) -> None:
        # Entirely non-alphanumeric → fallback
        result = _to_kebab("!!!###")
        assert result == "imported-agent"

    def test_unicode_symbols_replaced(self) -> None:
        result = _to_kebab("Résumé Assistant")
        # accented chars don't match [a-z0-9], treated as separators
        assert isinstance(result, str)
        assert len(result) > 0

    def test_title_case_lowercased(self) -> None:
        assert _to_kebab("Code Explainer") == "code-explainer"


# ===========================================================================
# _parse_lobehub — parser correctness
# ===========================================================================

class TestParseLobeHub:
    def test_parses_full_agent(self, lobehub_agent_full: dict[str, Any]) -> None:
        agent = _parse_lobehub(lobehub_agent_full)
        assert agent.meta.title == "Code Explainer"
        assert agent.config.system_role.startswith("You are an expert")
        assert agent.config.model == "gpt-4"
        assert agent.model_tier == "opus"
        assert agent.agent_name == "code-explainer"
        assert agent.meta.tags == ["code", "education", "programming"]

    def test_missing_config_gives_defaults(self) -> None:
        raw: dict[str, Any] = {
            "identifier": "bare",
            "meta": {"title": "Bare Agent"},
        }
        agent = _parse_lobehub(raw)
        assert agent.config.system_role == ""
        assert agent.model_tier == "sonnet"

    def test_missing_meta_gives_defaults(self, lobehub_agent_no_meta: dict[str, Any]) -> None:
        agent = _parse_lobehub(lobehub_agent_no_meta)
        assert agent.meta.title == "Untitled Agent"

    def test_tags_are_strings(self, lobehub_agent_full: dict[str, Any]) -> None:
        agent = _parse_lobehub(lobehub_agent_full)
        for tag in agent.meta.tags:
            assert isinstance(tag, str)

    def test_agent_name_is_kebab(self, lobehub_agent_full: dict[str, Any]) -> None:
        agent = _parse_lobehub(lobehub_agent_full)
        import re
        assert re.match(r"^[a-z][a-z0-9-]*$", agent.agent_name), (
            f"agent_name {agent.agent_name!r} is not valid kebab-case"
        )


# ===========================================================================
# Description padding (< 10 chars)
# ===========================================================================

class TestDescriptionPadding:
    def test_short_description_padded(self) -> None:
        raw: dict[str, Any] = {
            "identifier": "short-desc",
            "config": {"systemRole": "Be helpful."},
            "meta": {
                "title": "Short Desc Agent",
                "description": "Tiny",  # 4 chars < 10
            },
        }
        _, content = lobehub_to_markdown(raw)
        # The description in frontmatter should be padded
        assert "(imported from LobeHub)" in content

    def test_no_description_gets_default_and_padded(self) -> None:
        raw: dict[str, Any] = {
            "identifier": "no-desc",
            "config": {"systemRole": "Be helpful."},
            "meta": {
                "title": "No Desc Agent",
            },
        }
        _, content = lobehub_to_markdown(raw)
        # Default is "Imported LobeHub agent: No Desc Agent" which is > 10 chars
        assert "description:" in content

    def test_adequate_description_not_padded(self, lobehub_agent_full: dict[str, Any]) -> None:
        _, content = lobehub_to_markdown(lobehub_agent_full)
        # Full agent description is well over 10 chars; no padding appended
        assert "(imported from LobeHub)" not in content


# ===========================================================================
# Minimal agent edge cases
# ===========================================================================

class TestMinimalAgent:
    def test_minimal_does_not_raise(self, lobehub_agent_minimal: dict[str, Any]) -> None:
        filename, content = lobehub_to_markdown(lobehub_agent_minimal)
        assert filename
        assert content

    def test_no_config_note_when_no_extra_params(self) -> None:
        raw: dict[str, Any] = {
            "identifier": "plain",
            "config": {"systemRole": "Just a plain agent."},
            "meta": {
                "title": "Plain Agent",
                "description": "A very plain agent for testing.",
            },
        }
        _, content = lobehub_to_markdown(raw)
        # No model, params, history, displayMode → no config note section
        assert "## LobeHub Configuration" not in content
