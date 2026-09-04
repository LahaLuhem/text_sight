"""`report` and `report-device` — render committed charts + summaries from result JSON."""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

from text_sight_bench.config import (
    COMMITTED_REPORTS_DIR,
    DEVICE_SUMMARY_FILENAME,
    LIVE_SUMMARY_FILENAME,
)


def cmd_report(args: argparse.Namespace) -> int:
    """Renders the codec charts + SUMMARY.md, skipping any chart with no data behind it."""
    missing = [
        name
        for name in ("polars", "matplotlib", "seaborn", "pandas")
        if importlib.util.find_spec(name) is None
    ]
    if missing:
        print(f"missing analysis deps: {', '.join(missing)}", file=sys.stderr)
        print("  run `uv sync` from benchmark/python/", file=sys.stderr)
        return 1

    # Local imports keep the chart stack off the import path until it's needed.
    from text_sight_bench import charts, markdown
    from text_sight_bench.records import flatten, load_records

    records = load_records(args.results)
    if not records:
        print("no records found in input", file=sys.stderr)
        return 1

    out_dir = Path(args.out) if args.out else COMMITTED_REPORTS_DIR
    out_dir.mkdir(parents=True, exist_ok=True)

    df = flatten(records)
    charts.set_default_theme()
    chart_paths: list[Path] = []
    skipped: list[tuple[str, str]] = []
    for spec in charts.CODEC_CHARTS:
        agg = spec.prepare(df)
        # seaborn draws an empty frame as blank axes and savefig writes it, so stop short of that.
        if agg.is_empty():
            skipped.append((spec.filename, spec.needs))
            continue
        chart_paths.append(spec.render(agg, out_dir / spec.filename))

    summary_path = out_dir / "SUMMARY.md"
    summary_path.write_text(markdown.render_summary_markdown(df, chart_paths, records, skipped))

    print(f"wrote charts + summary to: {out_dir}")
    for path in [*chart_paths, summary_path]:
        print(f"  {path.name}")
    for filename, needs in skipped:
        print(f"  skipped {filename}: needs {needs}, none in this data")
    return 0


def cmd_report_device(args: argparse.Namespace) -> int:
    """Renders the device chart + DEVICE_SUMMARY.md from one or more scenario JSONs."""
    missing = [
        name
        for name in ("polars", "matplotlib", "seaborn", "pandas")
        if importlib.util.find_spec(name) is None
    ]
    if missing:
        print(f"missing analysis deps: {', '.join(missing)}", file=sys.stderr)
        print("  run `uv sync` from benchmark/python/", file=sys.stderr)
        return 1

    from text_sight_bench import charts, markdown
    from text_sight_bench.records import flatten_device, load_records

    # Merged across platforms so the report compares them side by side.
    records = [record for path in args.results for record in load_records(path)]
    if not records:
        print("no records found in input", file=sys.stderr)
        return 1

    out_dir = Path(args.out) if args.out else COMMITTED_REPORTS_DIR
    out_dir.mkdir(parents=True, exist_ok=True)

    df = flatten_device(records)
    charts.set_default_theme()
    chart_paths = [charts.plot_one_shot_latency(df, out_dir / "one_shot_latency.png")]

    summary_path = out_dir / DEVICE_SUMMARY_FILENAME
    summary_path.write_text(markdown.render_device_summary_markdown(df, chart_paths, records))

    print(f"wrote device charts + summary to: {out_dir}")
    for path in [*chart_paths, summary_path]:
        print(f"  {path.name}")
    return 0


def cmd_report_live(args: argparse.Namespace) -> int:
    """Renders LIVE_SUMMARY.md from one or more live-throughput JSONs."""
    if importlib.util.find_spec("polars") is None:
        print("missing analysis deps: polars", file=sys.stderr)
        print("  run `uv sync` from benchmark/python/", file=sys.stderr)
        return 1

    from text_sight_bench import markdown
    from text_sight_bench.records import flatten_live, load_records

    records = [record for path in args.results for record in load_records(path)]
    if not records:
        print("no records found in input", file=sys.stderr)
        return 1

    out_dir = Path(args.out) if args.out else COMMITTED_REPORTS_DIR
    out_dir.mkdir(parents=True, exist_ok=True)

    summary_path = out_dir / LIVE_SUMMARY_FILENAME
    summary_path.write_text(markdown.render_live_summary_markdown(flatten_live(records), records))

    print(f"wrote live summary to: {summary_path}")
    return 0
