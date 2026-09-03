"""Result-record loading + flattening to a polars DataFrame."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import polars as pl


def load_records(path: str | Path) -> list[dict[str, Any]]:
    """Loads the JSON array of records the Dart benchmark emits."""
    with Path(path).open() as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise ValueError(f"expected a JSON array of records, got {type(data).__name__}")
    return data


def flatten(records: list[dict[str, Any]]) -> pl.DataFrame:
    """One row per record, summary scalars hoisted to columns.

    `wire_bytes` is deterministic per cell; timings vary per iteration, so callers take a median.
    """
    rows = [
        {
            "candidate": record["candidate"],
            "payload": record["payload"],
            "line_count": record["line_count"],
            "iteration": record["iteration"],
            "decode_microseconds": record["summary"]["decode_microseconds"],
            "encode_microseconds": record["summary"]["encode_microseconds"],
            "wire_bytes": record["summary"]["wire_bytes"],
        }
        for record in records
    ]
    return pl.DataFrame(rows)


def flatten_device(records: list[dict[str, Any]]) -> pl.DataFrame:
    """One row per device record. `candidate` is the level, `payload` the profile.

    `lines_recognized` rides along: a level that reads nothing returns fast, and latency alone
    would flatter it.
    """
    rows = [
        {
            "platform": record["platform"],
            "candidate": record["candidate"],
            "payload": record["payload"],
            "line_count": record["line_count"],
            "iteration": record["iteration"],
            "latency_microseconds": record["summary"]["latency_microseconds"],
            "p95_latency_microseconds": record["summary"]["p95_latency_microseconds"],
            "lines_recognized": record["summary"]["lines_recognized"],
        }
        for record in records
    ]
    return pl.DataFrame(rows)


def flatten_live(records: list[dict[str, Any]]) -> pl.DataFrame:
    """Flattens live-throughput records to one row each."""
    rows = [
        {
            "platform": record["platform"],
            "candidate": record["candidate"],
            "iteration": record["iteration"],
            "frame_width": record["summary"].get("frame_width", 0),
            "frame_height": record["summary"].get("frame_height", 0),
            "capture_count": record["summary"]["capture_count"],
            "captures_per_second": record["summary"]["captures_per_second"],
            "inter_arrival_microseconds": record["summary"]["inter_arrival_microseconds"],
            "p95_inter_arrival_microseconds": record["summary"]["p95_inter_arrival_microseconds"],
            "lines_median": record["summary"]["lines_median"],
            "window_milliseconds": record["summary"]["window_milliseconds"],
        }
        for record in records
    ]
    return pl.DataFrame(rows)
