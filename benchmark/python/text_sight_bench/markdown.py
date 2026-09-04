"""Renders SUMMARY.md from the flattened result frame."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import polars as pl

from text_sight_bench.config import (
    BASELINE_CANDIDATE,
    CANDIDATE_ORDER,
    LEVEL_ORDER,
    PLATFORM_LABELS,
    PLATFORM_NAMES,
    PLATFORM_ORDER,
    PROFILE_ORDER,
)
from text_sight_bench.stats import grouped_median, pct_delta

_SCOPE_NOTE = (
    "> **Scope.** Pure-Dart codec cost only, *not* native encode, real-device "
    "frame latency, or ML inference (which dominates end-to-end). These numbers "
    "bound the upside of a transport change. They are not an end-to-end speedup."
)


def render_summary_markdown(
    df: pl.DataFrame,
    chart_paths: list[Path],
    records: list[dict[str, Any]],
    skipped: list[tuple[str, str]],
) -> str:
    """Builds the SUMMARY.md body: header, per-profile table, embedded charts."""
    lines: list[str] = [
        "# Codec round-trip: state of performance",
        "",
        "Per-frame **decode** CPU and **wire size** of the recognition-results "
        "transport, by candidate encoding. Decode is what runs on the Dart UI "
        "isolate per delivered frame. `map_std` is today's wire and the baseline.",
        "",
        _SCOPE_NOTE,
        "",
        _capture_line(records),
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
        *_skipped_note(skipped),
    ]
    return "\n".join(lines) + "\n"


def _capture_line(records: list[dict[str, Any]]) -> str:
    """The provenance line. A record off a phone carries a `platform`, a host one doesn't."""
    head = records[0] if records else {}
    iterations = max((record["iteration"] for record in records), default=-1) + 1
    seen = {record.get("platform") for record in records}
    platforms = [PLATFORM_NAMES[name] for name in PLATFORM_ORDER if name in seen]

    if platforms:
        where = f". Measured on {' and '.join(platforms)}, so your hardware will differ."
    else:
        where = " · per-machine, so your numbers will differ."

    return (
        f"Captured: SDK `{head.get('sdk_version', '?')}` · "
        f"package `{head.get('package_version', '?')}` · "
        f"git `{head.get('git_sha', '?')}` · N={iterations} · "
        f"{head.get('started_at', '?')}{where}"
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


def _skipped_note(skipped: list[tuple[str, str]]) -> list[str]:
    if not skipped:
        return []

    return [
        "Not drawn, no data behind them:",
        "",
        *[f"- `{filename}` needs {needs}" for filename, needs in skipped],
        "",
    ]


def _fmt_delta(delta: float | None) -> str:
    if delta is None:
        return "n/a"
    if abs(delta) < 0.5:
        return "0%"
    return f"{delta:+.0f}%"


_DEVICE_SCOPE_NOTE = (
    "> **Scope.** One-shot API latency as an app sees it: image decode, ML inference, the native "
    "encode and the channel hop, all inside one number. Inference dominates, but this does not "
    "isolate it. Live-camera throughput is a different measurement and not covered here."
)

_DEVICE_CAVEATS = (
    "- `level` is a no-op on Android, so its two rows should land on top of each other.\n"
    "- Read **lines** beside the latency. A level that recognizes nothing returns fast, which "
    "would otherwise look like a win.\n"
    "- Pages are rendered on-device at a fixed size, so decode cost is constant across profiles "
    "and the differences come from text density."
)


def render_device_summary_markdown(
    df: pl.DataFrame,
    chart_paths: list[Path],
    records: list[dict[str, Any]],
) -> str:
    """Builds DEVICE_SUMMARY.md: header, per-platform tables, embedded chart."""
    lines: list[str] = [
        "# One-shot recognition on device",
        "",
        "How long `TextSight.recognizeImage` takes on real hardware, by page profile and "
        "recognition level.",
        "",
        _DEVICE_SCOPE_NOTE,
        "",
        _capture_line(records),
        "",
        _DEVICE_CAVEATS,
        "",
    ]

    for platform in [p for p in PLATFORM_ORDER if p in set(df["platform"].to_list())]:
        panel = df.filter(pl.col("platform") == platform)
        lines += [
            f"## {PLATFORM_LABELS.get(platform, platform)}",
            "",
            "| Profile | Level | Lines | p50 (ms) | p95 (ms) |",
            "|---|---|--:|--:|--:|",
        ]
        medians = grouped_median(panel, ["payload", "candidate"], "latency_microseconds")
        p95s = grouped_median(panel, ["payload", "candidate"], "p95_latency_microseconds")
        reads = grouped_median(panel, ["payload", "candidate"], "lines_recognized")

        for profile in [p for p in PROFILE_ORDER if p in set(panel["payload"].to_list())]:
            levels = [name for name in LEVEL_ORDER if name in set(panel["candidate"].to_list())]
            for level in levels:
                key = (pl.col("payload") == profile) & (pl.col("candidate") == level)
                row = medians.filter(key)
                if row.height == 0:
                    continue
                p50 = row["latency_microseconds"][0] / 1000.0
                p95 = p95s.filter(key)["p95_latency_microseconds"][0] / 1000.0
                read = int(reads.filter(key)["lines_recognized"][0])
                flag = "" if read else " *(read nothing)*"
                lines.append(f"| {profile} | `{level}` | {read}{flag} | {p50:.1f} | {p95:.1f} |")
        lines.append("")

    for path in chart_paths:
        lines += [f"![One-shot latency]({path.name})", ""]

    return "\n".join(lines)


_LIVE_SCOPE_NOTE = (
    "> **Scope.** Recognized frames per second over a fixed window, and the gap between them. "
    "Under the single-in-flight backpressure that gap is roughly one recognition. Directional "
    "only: the numbers depend entirely on what the camera was pointed at, so keep the scene fixed "
    "when comparing runs."
)

_LIVE_CAVEATS = (
    "- Only *recognized* frames are visible from Dart, so the drop ratio (camera frames delivered "
    "versus recognized) is not here. That needs native counters.\n"
    "- A gap at the camera's frame interval (about 33 ms at 30 fps) means recognition is keeping "
    "up and the camera is the limit, not the recognizer.\n"
    "- `level` is a no-op on Android, so its rows should match.\n"
    "- **lines** is the median per capture. Zero means nothing readable was in frame, which makes "
    "the throughput number meaningless as a recognition measure."
)


def render_live_summary_markdown(
    df: pl.DataFrame,
    records: list[dict[str, Any]],
) -> str:
    """Builds LIVE_SUMMARY.md. A table, not a chart: four numbers with an uncontrolled scene do not
    deserve the precision a chart implies."""
    lines: list[str] = [
        "# Live recognition throughput",
        "",
        "How many frames per second the live path actually recognizes, per recognition level.",
        "",
        _LIVE_SCOPE_NOTE,
        "",
        _capture_line(records),
        "",
        _LIVE_CAVEATS,
        "",
        "| Platform | Level | Captures/s | Gap p50 (ms) | Gap p95 (ms) | Lines | Window (s) |",
        "|---|---|--:|--:|--:|--:|--:|",
    ]

    for platform in [p for p in PLATFORM_ORDER if p in set(df["platform"].to_list())]:
        panel = df.filter(pl.col("platform") == platform)
        levels = [name for name in LEVEL_ORDER if name in set(panel["candidate"].to_list())]
        for level in levels:
            rows = panel.filter(pl.col("candidate") == level)
            if rows.height == 0:
                continue
            per_second = rows["captures_per_second"].median()
            gap = rows["inter_arrival_microseconds"].median() / 1000.0
            gap95 = rows["p95_inter_arrival_microseconds"].median() / 1000.0
            read = int(rows["lines_median"].median())
            window = rows["window_milliseconds"].median() / 1000.0
            flag = "" if read else " *(nothing readable)*"
            lines.append(
                f"| {PLATFORM_LABELS.get(platform, platform)} | `{level}` | {per_second:.1f} | "
                f"{gap:.1f} | {gap95:.1f} | {read}{flag} | {window:.0f} |"
            )

    lines.append("")
    frames = _delivered_frames(df)
    if frames:
        lines += ["Frames delivered by the capture session, as the preview receives them:", ""]
        lines += [f"- {label}: {size}" for label, size in frames]
        lines.append("")

    return "\n".join(lines)


def _delivered_frames(df: pl.DataFrame) -> list[tuple[str, str]]:
    """One `WxH` per platform, skipping runs captured before the size was recorded."""
    if "frame_width" not in df.columns:
        return []

    out: list[tuple[str, str]] = []
    for platform in [p for p in PLATFORM_ORDER if p in set(df["platform"].to_list())]:
        panel = df.filter(pl.col("platform") == platform)
        width, height = int(panel["frame_width"].max()), int(panel["frame_height"].max())
        if width and height:
            out.append((PLATFORM_LABELS.get(platform, platform), f"{width}x{height}"))

    return out
