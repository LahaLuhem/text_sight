"""CLI entry for the text_sight benchmark orchestrator.

Subcommands:
  build           AOT-compile the codec_roundtrip micro-benchmark.
  run             Execute it, capturing one result JSON file.
  report <json>   Render committed README charts + SUMMARY.md from result JSON.
  run-device      Drive a device scenario (benchmark/app) on attached phones.
  report-device   Render the device chart + DEVICE_SUMMARY.md.
  report-live     Render LIVE_SUMMARY.md from live-throughput runs.

There is no `compare` — there is no before/after transport to diff yet.
"""

from __future__ import annotations

import argparse
import sys

from text_sight_bench.subcommands import build, report, runner


def main() -> int:
    parser = argparse.ArgumentParser(prog="run.py", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    build_parser = sub.add_parser("build", help="AOT-compile the benchmark")
    build_parser.set_defaults(func=build.cmd_build)

    run_parser = sub.add_parser("run", help="execute the benchmark, capture JSON")
    run_parser.add_argument("--iterations", type=int, default=10)
    run_parser.add_argument("--out", default=None, help="output dir")
    run_parser.set_defaults(func=runner.cmd_run)

    device_parser = sub.add_parser("run-device", help="drive a scenario on attached devices")
    device_parser.add_argument("--scenario", default="one_shot_latency")
    device_parser.add_argument("--iterations", type=int, default=3)
    device_parser.add_argument("--device", default=None, help="pin one device id")
    device_parser.add_argument("--platform", choices=("ios", "android"), default=None)
    device_parser.add_argument(
        "--include-virtual", action="store_true", help="allow simulators and emulators"
    )
    device_parser.add_argument("--out", default=None, help="output dir")
    device_parser.set_defaults(func=runner.cmd_run_device)

    report_parser = sub.add_parser("report", help="render charts + SUMMARY.md")
    report_parser.add_argument("results", help="path to a codec_roundtrip.json")
    report_parser.add_argument("--out", default=None, help="output dir")
    report_parser.set_defaults(func=report.cmd_report)

    device_report_parser = sub.add_parser(
        "report-device", help="render the device chart + DEVICE_SUMMARY.md"
    )
    device_report_parser.add_argument("results", nargs="+", help="one JSON per platform")
    device_report_parser.add_argument("--out", default=None, help="output dir")
    device_report_parser.set_defaults(func=report.cmd_report_device)

    live_report_parser = sub.add_parser("report-live", help="render LIVE_SUMMARY.md")
    live_report_parser.add_argument("results", nargs="+", help="one JSON per platform")
    live_report_parser.add_argument("--out", default=None, help="output dir")
    live_report_parser.set_defaults(func=report.cmd_report_live)

    args = parser.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
