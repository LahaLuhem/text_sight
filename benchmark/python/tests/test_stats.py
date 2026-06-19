"""Unit tests for the pure aggregation helpers."""

from __future__ import annotations

import polars as pl

from text_sight_bench.stats import grouped_median, median, pct_delta


def test_median_empty() -> None:
    assert median([]) == 0.0


def test_median_odd() -> None:
    assert median([3.0, 1.0, 2.0]) == 2.0


def test_median_even() -> None:
    assert median([1.0, 2.0, 3.0, 4.0]) == 2.5


def test_pct_delta_zero_baseline() -> None:
    assert pct_delta(5.0, 0.0) is None


def test_pct_delta_improvement() -> None:
    assert pct_delta(0.5, 4.0) == -87.5


def test_grouped_median_collapses_iterations() -> None:
    df = pl.DataFrame(
        {
            "candidate": ["map_std", "map_std", "list_std"],
            "decode_microseconds": [4.0, 6.0, 1.0],
        }
    )
    out = grouped_median(df, ["candidate"], "decode_microseconds").sort("candidate")
    assert out.to_dicts() == [
        {"candidate": "list_std", "decode_microseconds": 1.0},
        {"candidate": "map_std", "decode_microseconds": 5.0},
    ]
