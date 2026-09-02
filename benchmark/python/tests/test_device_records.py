"""Unit tests for flattening device scenario records."""

from __future__ import annotations

from typing import Any

from text_sight_bench.records import flatten_device


def test_flatten_device_columns_and_rows(sample_device_records: list[dict[str, Any]]) -> None:
    df = flatten_device(sample_device_records)
    assert df.height == 4
    assert set(df.columns) == {
        "platform",
        "candidate",
        "payload",
        "line_count",
        "iteration",
        "latency_microseconds",
        "p95_latency_microseconds",
        "lines_recognized",
    }


def test_flatten_device_keeps_lines_recognized(
    sample_device_records: list[dict[str, Any]],
) -> None:
    """A level that reads nothing must stay visible, since it also returns fast."""
    df = flatten_device(sample_device_records)
    empty = df.filter((df["platform"] == "ios") & (df["candidate"] == "fast"))
    assert empty["lines_recognized"][0] == 0
    assert empty["latency_microseconds"][0] < 100_000
