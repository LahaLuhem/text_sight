"""Unit tests for flattening live-throughput records."""

from __future__ import annotations

from typing import Any

from text_sight_bench.markdown import render_live_summary_markdown
from text_sight_bench.records import flatten_live


def test_flatten_live_columns(sample_live_records: list[dict[str, Any]]) -> None:
    df = flatten_live(sample_live_records)
    assert df.height == 2
    assert {"platform", "candidate", "captures_per_second", "lines_median"} <= set(df.columns)


def test_live_summary_flags_an_unreadable_scene(
    sample_live_records: list[dict[str, Any]],
) -> None:
    """Throughput with nothing in frame must not read as a recognition result."""
    body = render_live_summary_markdown(flatten_live(sample_live_records), sample_live_records)
    assert "nothing readable" in body
    assert "30.0" in body


def test_live_summary_reports_the_delivered_frame_size(
    sample_live_records: list[dict[str, Any]],
) -> None:
    """`.high` is device-dependent, so the summary states what actually arrived."""
    for record in sample_live_records:
        record["summary"] |= {"frame_width": 1080, "frame_height": 1920}

    body = render_live_summary_markdown(flatten_live(sample_live_records), sample_live_records)

    assert "1080x1920" in body


def test_live_summary_omits_the_frame_size_for_older_runs(
    sample_live_records: list[dict[str, Any]],
) -> None:
    """Runs captured before the size was recorded still render, without an empty 0x0 line."""
    body = render_live_summary_markdown(flatten_live(sample_live_records), sample_live_records)

    assert "0x0" not in body
    assert "Frames delivered" not in body
