"""Chart renderers for the committed README report (3 PNGs).

Module-level matplotlib / seaborn imports are intentional — this module only
makes sense with the analysis stack installed; `cmd_report` gates the call
site with a `find_spec` check pointing users at `uv sync`. Each plot fn returns
the `Path` it wrote, so the caller can thread it into the markdown image list.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import polars as pl
import seaborn as sns

from text_sight_bench.config import (
    CANDIDATE_COLORS,
    CANDIDATE_ORDER,
    CHART_DPI,
    PROFILE_ORDER,
)
from text_sight_bench.stats import grouped_median


def set_default_theme() -> None:
    """Pins a headless backend + the shared seaborn theme. Idempotent."""
    # Force Agg so rendering never touches a display (CI, or a dev machine
    # mid-task). `force=True` switches even though pyplot is already imported;
    # safe here because no figure exists yet.
    matplotlib.use("Agg", force=True)
    sns.set_theme(style="whitegrid", context="paper")


def plot_decode_vs_lines(df: pl.DataFrame, out_path: Path) -> Path:
    """Median decode µs vs lines-per-frame, one line per candidate (sweep)."""
    agg = grouped_median(
        df.filter(pl.col("payload") == "sweep"),
        ["candidate", "line_count"],
        "decode_microseconds",
    ).to_pandas()

    fig, ax = plt.subplots(figsize=(8, 5))
    sns.lineplot(
        data=agg,
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


def plot_wire_bytes_vs_lines(df: pl.DataFrame, out_path: Path) -> Path:
    """Wire size (KB) vs lines-per-frame, one line per candidate (sweep)."""
    agg = (
        grouped_median(
            df.filter(pl.col("payload") == "sweep"),
            ["candidate", "line_count"],
            "wire_bytes",
        )
        .with_columns((pl.col("wire_bytes") / 1024.0).alias("wire_kb"))
        .to_pandas()
    )

    fig, ax = plt.subplots(figsize=(8, 5))
    sns.lineplot(
        data=agg,
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


def plot_profile_decode_bars(df: pl.DataFrame, out_path: Path) -> Path:
    """Median decode µs per realistic profile, grouped bars per candidate."""
    agg = grouped_median(
        df.filter(pl.col("payload").is_in(PROFILE_ORDER)),
        ["payload", "candidate"],
        "decode_microseconds",
    ).to_pandas()

    fig, ax = plt.subplots(figsize=(9, 5))
    sns.barplot(
        data=agg,
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
