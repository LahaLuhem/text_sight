"""Unit tests for record loading + flattening."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from text_sight_bench.records import flatten, load_records


def test_flatten_columns_and_rows(sample_records: list[dict[str, Any]]) -> None:
    df = flatten(sample_records)
    assert df.height == 4
    assert set(df.columns) == {
        "candidate",
        "payload",
        "line_count",
        "iteration",
        "decode_microseconds",
        "encode_microseconds",
        "wire_bytes",
    }
    packed = df.filter((df["candidate"] == "packed_f32") & (df["payload"] == "document"))
    assert packed["wire_bytes"][0] == 4149


def test_load_records_roundtrip(tmp_path: Path, sample_records: list[dict[str, Any]]) -> None:
    path = tmp_path / "codec_roundtrip.json"
    path.write_text(json.dumps(sample_records))
    assert load_records(path) == sample_records


def test_load_records_rejects_non_array(tmp_path: Path) -> None:
    path = tmp_path / "bad.json"
    path.write_text(json.dumps({"not": "an array"}))
    with pytest.raises(ValueError, match="JSON array"):
        load_records(path)
