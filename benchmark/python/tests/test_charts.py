"""Unit tests for the chart aggregations. No drawing happens here."""

from __future__ import annotations

from typing import Any

import polars as pl

from text_sight_bench import charts, config
from text_sight_bench.records import flatten


def test_prepare_decode_vs_lines_keeps_only_the_sweep(
    sample_records: list[dict[str, Any]],
) -> None:
    agg = charts.prepare_decode_vs_lines(flatten(sample_records))
    assert agg.to_dicts() == [
        {"candidate": "map_std", "line_count": 10, "decode_microseconds": 4.5},
        {"candidate": "packed_f32", "line_count": 10, "decode_microseconds": 0.5},
    ]


def test_prepare_wire_bytes_adds_kilobytes(sample_records: list[dict[str, Any]]) -> None:
    agg = charts.prepare_wire_bytes_vs_lines(flatten(sample_records))
    assert agg["wire_kb"].to_list() == [1296 / 1024, 420 / 1024]


def test_prepare_profile_bars_keeps_only_profiles(sample_records: list[dict[str, Any]]) -> None:
    agg = charts.prepare_profile_decode_bars(flatten(sample_records))
    assert agg["payload"].unique().to_list() == ["document"]
    assert agg.height == 2


def test_sweep_charts_come_back_empty_without_a_sweep(
    sample_records: list[dict[str, Any]],
) -> None:
    """An on-device run only does the profiles, so both sweep charts have nothing to draw."""
    profiles_only = flatten(sample_records).filter(pl.col("payload") != "sweep")
    assert charts.prepare_decode_vs_lines(profiles_only).is_empty()
    assert charts.prepare_wire_bytes_vs_lines(profiles_only).is_empty()


def test_every_swept_candidate_has_an_order_and_a_colour() -> None:
    """A candidate missing from LEVEL_ORDER is dropped from charts and tables with no error, so
    the scenario's sweep and the config have to stay in step."""
    swept = {
        f"{level}{suffix}"
        for level in ("fast", "accurate")
        for suffix in ("", "+corrected")
    }

    assert swept <= set(config.LEVEL_ORDER)
    assert swept <= set(config.LEVEL_COLORS)
    assert set(config.LEVEL_ORDER) == set(config.LEVEL_COLORS)
