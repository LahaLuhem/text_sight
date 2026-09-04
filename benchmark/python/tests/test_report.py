"""Tests for what `report` writes, and what it refuses to write."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from text_sight_bench.subcommands.report import cmd_report

CHART_NAMES = ("decode_vs_lines.png", "wire_bytes_vs_lines.png", "profile_decode_bars.png")


def _report(tmp_path: Path, records: list[dict[str, Any]]) -> Path:
    results = tmp_path / "results.json"
    results.write_text(json.dumps(records))
    out_dir = tmp_path / "out"
    assert cmd_report(argparse.Namespace(results=str(results), out=str(out_dir))) == 0

    return out_dir


def test_host_data_draws_every_chart(tmp_path: Path, sample_records: list[dict[str, Any]]) -> None:
    out_dir = _report(tmp_path, sample_records)
    assert all((out_dir / name).exists() for name in CHART_NAMES)
    assert "Not drawn" not in (out_dir / "SUMMARY.md").read_text()


def test_device_data_skips_the_sweep_charts(
    tmp_path: Path, sample_records: list[dict[str, Any]]
) -> None:
    """An on-device run has no sweep, so those two files must not appear at all."""
    out_dir = _report(tmp_path, [r for r in sample_records if r["payload"] != "sweep"])
    assert not (out_dir / "decode_vs_lines.png").exists()
    assert not (out_dir / "wire_bytes_vs_lines.png").exists()
    assert (out_dir / "profile_decode_bars.png").exists()


def test_a_skipped_chart_says_so_in_the_summary(
    tmp_path: Path, sample_records: list[dict[str, Any]]
) -> None:
    """The blank-chart bug was invisible in the artifact, not just in the terminal."""
    out_dir = _report(tmp_path, [r for r in sample_records if r["payload"] != "sweep"])
    summary = (out_dir / "SUMMARY.md").read_text()
    assert "- `decode_vs_lines.png` needs the sweep payload" in summary
    assert "- `wire_bytes_vs_lines.png` needs the sweep payload" in summary
    assert "![profile_decode_bars]" in summary
