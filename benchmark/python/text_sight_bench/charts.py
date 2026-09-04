"""Charts in two halves: `prepare_*` crunches the numbers, `render_*` draws them, so you can
check what came back before drawing it.

Module-level matplotlib imports are deliberate: `cmd_report` gates the call site with a
`find_spec` check that points at `uv sync`.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import NamedTuple

import matplotlib
import matplotlib.pyplot as plt
import polars as pl
import seaborn as sns

from text_sight_bench.config import (
    CANDIDATE_COLORS,
    CANDIDATE_ORDER,
    CHART_DPI,
    LEVEL_COLORS,
    LEVEL_ORDER,
    PLATFORM_LABELS,
    PLATFORM_ORDER,
    PROFILE_ORDER,
)
from text_sight_bench.stats import grouped_median


def set_default_theme() -> None:
    """Pins a headless backend and the shared theme. Idempotent."""
    # Agg so rendering never touches a display. `force=True` is safe: no figure exists yet.
    matplotlib.use("Agg", force=True)
    sns.set_theme(style="whitegrid", context="paper")


def prepare_decode_vs_lines(df: pl.DataFrame) -> pl.DataFrame:
    """Median decode µs per candidate, at each swept line count."""
    # Only the sweep holds text length steady, so line count is the one thing moving here.
    return grouped_median(
        df.filter(pl.col("payload") == "sweep"),
        ["candidate", "line_count"],
        "decode_microseconds",
    )


def render_decode_vs_lines(agg: pl.DataFrame, out_path: Path) -> Path:
    """Decode µs against lines-per-frame, one line per candidate."""
    fig, ax = plt.subplots(figsize=(8, 5))
    sns.lineplot(
        data=agg.to_pandas(),
        x="line_count",
        y="decode_microseconds",
        hue="candidate",
        hue_order=CANDIDATE_ORDER,
        palette=CANDIDATE_COLORS,
        marker="o",
        ax=ax,
    )
    ax.set_xlabel("Lines per frame")
    ax.set_ylabel("Median decode (µs)")
    ax.set_title("Per-frame decode cost vs frame size")
    ax.legend(title="")
    fig.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def prepare_wire_bytes_vs_lines(df: pl.DataFrame) -> pl.DataFrame:
    """Median wire size per candidate at each swept line count, in KB."""
    return grouped_median(
        df.filter(pl.col("payload") == "sweep"),
        ["candidate", "line_count"],
        "wire_bytes",
    ).with_columns((pl.col("wire_bytes") / 1024.0).alias("wire_kb"))


def render_wire_bytes_vs_lines(agg: pl.DataFrame, out_path: Path) -> Path:
    """Wire size in KB against lines-per-frame, one line per candidate."""
    fig, ax = plt.subplots(figsize=(8, 5))
    sns.lineplot(
        data=agg.to_pandas(),
        x="line_count",
        y="wire_kb",
        hue="candidate",
        hue_order=CANDIDATE_ORDER,
        palette=CANDIDATE_COLORS,
        marker="o",
        ax=ax,
    )
    ax.set_xlabel("Lines per frame")
    ax.set_ylabel("Wire size (KB)")
    ax.set_title("Encoded payload size vs frame size")
    ax.legend(title="")
    fig.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


def prepare_profile_decode_bars(df: pl.DataFrame) -> pl.DataFrame:
    """Median decode µs per realistic profile and candidate."""
    return grouped_median(
        df.filter(pl.col("payload").is_in(PROFILE_ORDER)),
        ["payload", "candidate"],
        "decode_microseconds",
    )


def render_profile_decode_bars(agg: pl.DataFrame, out_path: Path) -> Path:
    """Decode µs per profile, grouped bars per candidate."""
    fig, ax = plt.subplots(figsize=(9, 5))
    sns.barplot(
        data=agg.to_pandas(),
        x="payload",
        y="decode_microseconds",
        order=PROFILE_ORDER,
        hue="candidate",
        hue_order=CANDIDATE_ORDER,
        palette=CANDIDATE_COLORS,
        ax=ax,
    )
    ax.set_xlabel("")
    ax.set_ylabel("Median decode (µs)")
    ax.set_title("Decode cost per realistic OCR profile")
    ax.legend(title="")
    fig.tight_layout()
    fig.savefig(out_path, dpi=CHART_DPI)
    plt.close(fig)
    return out_path


class ChartSpec(NamedTuple):
    """A chart's filename, what its data has to contain, and its two halves."""

    filename: str
    needs: str
    prepare: Callable[[pl.DataFrame], pl.DataFrame]
    render: Callable[[pl.DataFrame, Path], Path]


CODEC_CHARTS = (
    ChartSpec(
        "decode_vs_lines.png",
        "the sweep payload",
        prepare_decode_vs_lines,
        render_decode_vs_lines,
    ),
    ChartSpec(
        "wire_bytes_vs_lines.png",
        "the sweep payload",
        prepare_wire_bytes_vs_lines,
        render_wire_bytes_vs_lines,
    ),
    ChartSpec(
        "profile_decode_bars.png",
        "one of the named profiles",
        prepare_profile_decode_bars,
        render_profile_decode_bars,
    ),
)


def plot_one_shot_latency(df: pl.DataFrame, out_path: Path) -> Path:
    """Median one-shot latency (ms) per profile, one panel per platform.

    Bars are labelled with lines read, so a fast-but-empty result cannot pass for a fast one.
    """
    platforms = [p for p in PLATFORM_ORDER if p in set(df["platform"].to_list())]
    figure, axes = plt.subplots(
        1, len(platforms), figsize=(6.4 * len(platforms), 4.2), squeeze=False, sharey=True
    )

    for column, platform in enumerate(platforms):
        axis = axes[0][column]
        panel = df.filter(pl.col("platform") == platform)
        agg = grouped_median(panel, ["candidate", "payload"], "latency_microseconds")
        lines_read = grouped_median(panel, ["candidate", "payload"], "lines_recognized")

        profiles = [p for p in PROFILE_ORDER if p in set(agg["payload"].to_list())]
        levels = [name for name in LEVEL_ORDER if name in set(agg["candidate"].to_list())]
        width = 0.8 / max(len(levels), 1)

        for index, level in enumerate(levels):
            xs, ys, labels = [], [], []
            for slot, profile in enumerate(profiles):
                row = agg.filter((pl.col("candidate") == level) & (pl.col("payload") == profile))
                if row.height == 0:
                    continue
                xs.append(slot + index * width - 0.4 + width / 2)
                ys.append(row["latency_microseconds"][0] / 1000.0)
                read = lines_read.filter(
                    (pl.col("candidate") == level) & (pl.col("payload") == profile)
                )
                labels.append(int(read["lines_recognized"][0]) if read.height else 0)
            bars = axis.bar(xs, ys, width=width, label=level, color=LEVEL_COLORS.get(level))
            for bar, read in zip(bars, labels, strict=True):
                axis.annotate(
                    f"{read} lines",
                    (bar.get_x() + bar.get_width() / 2, bar.get_height()),
                    ha="center",
                    va="bottom",
                    fontsize=7,
                )

        axis.set_xticks(range(len(profiles)))
        axis.set_xticklabels(profiles)
        axis.set_title(PLATFORM_LABELS.get(platform, platform))
        axis.set_xlabel("")
        if column == 0:
            axis.set_ylabel("Median one-shot latency (ms)")
        axis.legend(title="level")

    figure.suptitle("One-shot recognition latency, by page profile")
    figure.tight_layout()
    figure.savefig(out_path, dpi=CHART_DPI)
    plt.close(figure)
    return out_path
