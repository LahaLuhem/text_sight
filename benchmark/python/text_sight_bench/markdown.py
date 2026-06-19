"""Renders SUMMARY.md from the flattened result frame."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import polars as pl

from text_sight_bench.config import BASELINE_CANDIDATE, CANDIDATE_ORDER, PROFILE_ORDER
from text_sight_bench.stats import grouped_median, pct_delta

_SCOPE_NOTE = (
    "> **Scope.** Pure-Dart codec cost only — *not* native encode, real-device "
    "frame latency, or ML inference (which dominates end-to-end). These numbers "
    "bound the upside of a transport change; they are not an end-to-end speedup."
)


def render_summary_markdown(
    df: pl.DataFrame,
    chart_paths: list[Path],
    records: list[dict[str, Any]],
) -> str:
    """Builds the SUMMARY.md body: header, per-profile table, embedded charts."""
    head = records[0] if records else {}
    iterations = max((record["iteration"] for record in records), default=-1) + 1

    lines: list[str] = [
        "# Codec round-trip — state of performance",
        "",
        "Per-frame **decode** CPU and **wire size** of the recognition-results "
        "transport, by candidate encoding. Decode is what runs on the Dart UI "
        "isolate per delivered frame; `map_std` is today's wire and the baseline.",
        "",
        _SCOPE_NOTE,
        "",
        _capture_line(head, iterations),
        "",
        "## Realistic profiles",
        "",
        "| Profile | Candidate | Decode (µs) | Wire (bytes) | Δ decode | Δ bytes |",
        "|---|---|--:|--:|--:|--:|",
        *_profile_rows(df),
        "",
        "## Charts",
        "",
        *_chart_embeds(chart_paths),
    ]
    return "\n".join(lines) + "\n"


def _capture_line(head: dict[str, Any], iterations: int) -> str:
    return (
        f"Captured: SDK `{head.get('sdk_version', '?')}` · "
        f"package `{head.get('package_version', '?')}` · "
        f"git `{head.get('git_sha', '?')}` · N={iterations} · "
        f"{head.get('started_at', '?')} · per-machine — your numbers will differ."
    )


def _profile_rows(df: pl.DataFrame) -> list[str]:
    decode = grouped_median(df, ["payload", "candidate"], "decode_microseconds")
    wire = grouped_median(df, ["payload", "candidate"], "wire_bytes")
    merged = decode.join(wire, on=["payload", "candidate"])

    rows: list[str] = []
    for profile in PROFILE_ORDER:
        in_profile = merged.filter(pl.col("payload") == profile)
        if in_profile.is_empty():
            continue
        base = in_profile.filter(pl.col("candidate") == BASELINE_CANDIDATE)
        base_decode = float(base["decode_microseconds"][0]) if not base.is_empty() else 0.0
        base_wire = float(base["wire_bytes"][0]) if not base.is_empty() else 0.0
        for candidate in CANDIDATE_ORDER:
            cell = in_profile.filter(pl.col("candidate") == candidate)
            if cell.is_empty():
                continue
            decode_us = float(cell["decode_microseconds"][0])
            wire_bytes = int(cell["wire_bytes"][0])
            rows.append(
                f"| {profile} | `{candidate}` | {decode_us:.2f} | {wire_bytes} | "
                f"{_fmt_delta(pct_delta(decode_us, base_decode))} | "
                f"{_fmt_delta(pct_delta(wire_bytes, base_wire))} |"
            )
    return rows


def _chart_embeds(chart_paths: list[Path]) -> list[str]:
    embeds: list[str] = []
    for path in chart_paths:
        embeds.append(f"![{path.stem}]({path.name})")
        embeds.append("")
    return embeds


def _fmt_delta(delta: float | None) -> str:
    if delta is None:
        return "—"
    if abs(delta) < 0.5:
        return "0%"
    return f"{delta:+.0f}%"
