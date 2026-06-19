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
