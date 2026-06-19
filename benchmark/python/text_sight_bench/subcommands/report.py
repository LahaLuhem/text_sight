"""`report` — render committed README charts + SUMMARY.md from result JSON."""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

from text_sight_bench.config import COMMITTED_REPORTS_DIR


def cmd_report(args: argparse.Namespace) -> int:
    """Renders 3 PNGs + SUMMARY.md from one codec_roundtrip.json."""
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
    chart_paths = [
        charts.plot_decode_vs_lines(df, out_dir / "decode_vs_lines.png"),
        charts.plot_wire_bytes_vs_lines(df, out_dir / "wire_bytes_vs_lines.png"),
        charts.plot_profile_decode_bars(df, out_dir / "profile_decode_bars.png"),
    ]

    summary_path = out_dir / "SUMMARY.md"
    summary_path.write_text(markdown.render_summary_markdown(df, chart_paths, records))

    print(f"wrote charts + summary to: {out_dir}")
    for path in [*chart_paths, summary_path]:
        print(f"  {path.name}")
    return 0
