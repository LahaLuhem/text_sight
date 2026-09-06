"""Unit tests for SUMMARY.md rendering."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import polars as pl

from text_sight_bench import markdown
from text_sight_bench.markdown import render_device_summary_markdown, render_summary_markdown
from text_sight_bench.records import flatten, flatten_device


def test_render_contains_header_scope_and_capture(sample_records: list[dict[str, Any]]) -> None:
    out = render_summary_markdown(flatten(sample_records), [], sample_records, [])
    assert "# Codec round-trip: state of performance" in out
    assert "**Scope.**" in out
    assert "git `abc1234`" in out
    assert "N=1" in out


def test_render_profile_table_has_baseline_and_delta(sample_records: list[dict[str, Any]]) -> None:
    out = render_summary_markdown(flatten(sample_records), [], sample_records, [])
    # map_std is the baseline -> its delta cells are 0%, and packed_f32 improves on it.
    assert "| document | `map_std` | 30.00 | 9384 | 0% | 0% |" in out
    assert "`packed_f32`" in out
    assert "-85%" in out  # 4.4 vs 30.0 decode


def test_render_embeds_charts(sample_records: list[dict[str, Any]]) -> None:
    paths = [Path("decode_vs_lines.png"), Path("wire_bytes_vs_lines.png")]
    out = render_summary_markdown(flatten(sample_records), paths, sample_records, [])
    assert "![decode_vs_lines](decode_vs_lines.png)" in out
    assert "![wire_bytes_vs_lines](wire_bytes_vs_lines.png)" in out


def test_host_capture_line_says_per_machine(sample_records: list[dict[str, Any]]) -> None:
    out = render_summary_markdown(flatten(sample_records), [], sample_records, [])
    assert "per-machine" in out


def test_device_capture_line_names_the_platform(sample_records: list[dict[str, Any]]) -> None:
    """A phone run must not call itself per-machine."""
    on_phone = [{**record, "platform": "ios"} for record in sample_records]
    out = render_summary_markdown(flatten(on_phone), [], on_phone, [])
    assert "Measured on iOS, so your hardware will differ." in out
    assert "per-machine" not in out


def test_capture_line_names_every_platform_in_the_run(
    sample_device_records: list[dict[str, Any]],
) -> None:
    out = render_device_summary_markdown(
        flatten_device(sample_device_records), [], sample_device_records
    )
    assert "Measured on iOS and Android" in out


def test_device_summary_reports_the_frame_budget_share(
    sample_records: list[dict[str, Any]],
) -> None:
    """The slowest profile wins, so a second, quicker one must not displace it."""
    on_phone = [{**record, "platform": "ios"} for record in sample_records]
    slowest = next(
        record
        for record in on_phone
        if record["candidate"] == "map_std" and record["payload"] == "document"
    )
    on_phone.append(
        {
            **slowest,
            "payload": "sign",
            "line_count": 3,
            "summary": {**slowest["summary"], "decode_microseconds": 2.0},
        }
    )

    out = render_summary_markdown(flatten(on_phone), [], on_phone, [])
    # document at 30 µs, not sign at 2 µs, out of a 16667 µs frame.
    assert "a `document` 63-line frame on `map_std` decodes in 30.0 µs" in out
    assert "0.18% of a 60 fps frame" in out


def test_host_summary_leaves_the_frame_budget_alone(
    sample_records: list[dict[str, Any]],
) -> None:
    """A laptop number cannot back a claim about what fits in a phone's frame."""
    out = render_summary_markdown(flatten(sample_records), [], sample_records, [])
    assert "fps frame" not in out


def test_a_boosting_or_stalling_window_is_left_out_of_the_sustained_rate() -> None:
    """A cool phone boosts and a hot one stalls. Both are the device, and with few windows each
    they drag a per-candidate median in opposite directions."""
    panel = pl.DataFrame(
        {
            "candidate": ["fast"] * 3 + ["accurate"] * 3,
            "captures_per_second": [7.9, 7.6, 4.5, 3.0, 4.4, 4.6],
            "inter_arrival_microseconds": [126000, 131000, 222000, 333000, 227000, 217000],
            "p95_inter_arrival_microseconds": [130000, 135000, 240000, 545000, 240000, 230000],
        }
    )

    boosted = markdown._steady_windows(panel.filter(pl.col("candidate") == "fast"), panel)
    stalled = markdown._steady_windows(panel.filter(pl.col("candidate") == "accurate"), panel)

    assert boosted["captures_per_second"].median() == 4.5
    assert stalled["captures_per_second"].median() == 4.5


def test_a_run_with_no_steady_window_keeps_them_all() -> None:
    """Better a noisy number than an empty table."""
    panel = pl.DataFrame({"candidate": ["fast"], "captures_per_second": [0.0]})

    assert markdown._steady_windows(panel, panel).height == 1
