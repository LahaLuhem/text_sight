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
    """Flattens records to one row each, hoisting the summary scalars to columns.

    `wire_bytes` is deterministic per (candidate, payload, line_count); the
    timing metrics vary per iteration, so callers take their median.
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
    """Flattens device scenario records to one row each.

    `candidate` is the recognition level and `payload` the page profile, matching the micro
    schema. `lines_recognized` rides along because a level that reads nothing returns fast, so
    latency on its own would flatter it.
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
