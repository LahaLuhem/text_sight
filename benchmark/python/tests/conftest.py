"""Shared fixtures: a minimal, self-consistent set of result records."""

from __future__ import annotations

from typing import Any

import pytest


def _record(candidate: str, payload: str, lines: int, decode: float, bytes_: int) -> dict[str, Any]:
    return {
        "benchmark": "codec_roundtrip",
        "candidate": candidate,
        "payload": payload,
        "line_count": lines,
        "iteration": 0,
        "sdk_version": "3.12.0",
        "package_version": "0.0.0",
        "git_sha": "abc1234",
        "started_at": "2026-06-19T00:00:00.000Z",
        "samples": {"decode_microseconds": [decode], "encode_microseconds": [decode]},
        "summary": {
            "decode_microseconds": decode,
            "encode_microseconds": decode,
            "wire_bytes": bytes_,
        },
    }


@pytest.fixture
def sample_records() -> list[dict[str, Any]]:
    """Two candidates across one sweep point and one profile."""
    return [
        _record("map_std", "sweep", 10, 4.5, 1296),
        _record("packed_f32", "sweep", 10, 0.5, 420),
        _record("map_std", "document", 63, 30.0, 9384),
        _record("packed_f32", "document", 63, 4.4, 4149),
    ]
