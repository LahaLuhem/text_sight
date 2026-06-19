"""Pure aggregation helpers — the highest-value unit-test target."""

from __future__ import annotations

import polars as pl


def median(values: list[float]) -> float:
    """Median of `values`; returns 0.0 for an empty list (caller's choice)."""
    count = len(values)
    if count == 0:
        return 0.0
    ordered = sorted(values)
    mid = count // 2
    if count % 2 == 1:
        return float(ordered[mid])
    return (ordered[mid - 1] + ordered[mid]) / 2.0


def grouped_median(df: pl.DataFrame, group_cols: list[str], metric: str) -> pl.DataFrame:
    """Median of `metric` per group, sorted by the grouping columns."""
    return df.group_by(group_cols).agg(pl.col(metric).median().alias(metric)).sort(group_cols)


def pct_delta(value: float, baseline: float) -> float | None:
    """Percent change of `value` from `baseline`; `None` if baseline is 0."""
    if baseline == 0:
        return None
    return (value - baseline) / baseline * 100.0
