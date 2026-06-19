"""Unit tests for SUMMARY.md rendering."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from text_sight_bench.markdown import render_summary_markdown
from text_sight_bench.records import flatten


def test_render_contains_header_scope_and_capture(sample_records: list[dict[str, Any]]) -> None:
    out = render_summary_markdown(flatten(sample_records), [], sample_records)
    assert "# Codec round-trip — state of performance" in out
    assert "**Scope.**" in out
    assert "git `abc1234`" in out
    assert "N=1" in out


def test_render_profile_table_has_baseline_and_delta(sample_records: list[dict[str, Any]]) -> None:
    out = render_summary_markdown(flatten(sample_records), [], sample_records)
    # map_std is the baseline -> its delta cells are 0%; packed_f32 improves.
    assert "| document | `map_std` | 30.00 | 9384 | 0% | 0% |" in out
    assert "`packed_f32`" in out
    assert "-85%" in out  # 4.4 vs 30.0 decode


def test_render_embeds_charts(sample_records: list[dict[str, Any]]) -> None:
    paths = [Path("decode_vs_lines.png"), Path("wire_bytes_vs_lines.png")]
    out = render_summary_markdown(flatten(sample_records), paths, sample_records)
    assert "![decode_vs_lines](decode_vs_lines.png)" in out
    assert "![wire_bytes_vs_lines](wire_bytes_vs_lines.png)" in out
