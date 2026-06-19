"""`run` — execute the compiled benchmark, capturing one result JSON file."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from text_sight_bench.config import (
    BENCHMARK_ROOT,
    DEFAULT_RESULTS_DIR,
    EXE_PATH,
    PACKAGE_PUBSPEC,
    RESULT_FILENAME,
)


def cmd_run(args: argparse.Namespace) -> int:
    """Runs the exe with `--iterations`, writing `<out>/codec_roundtrip.json`."""
    if not EXE_PATH.exists():
        print(f"missing exe: {EXE_PATH}\n  run `python run.py build` first", file=sys.stderr)
        return 1

    out_dir = Path(args.out) if args.out else DEFAULT_RESULTS_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / RESULT_FILENAME

    cmd = [
        str(EXE_PATH),
        "--iterations",
        str(args.iterations),
        "--output",
        str(out_file),
        "--git-sha",
        _git_sha(),
        "--package-version",
        _package_version(),
    ]
    print(f"running {args.iterations} iteration(s) -> {out_file}")
    result = subprocess.run(cmd, check=False)
    if result.returncode == 0:
        print(f"wrote: {out_file}")
    return result.returncode


def _git_sha() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=BENCHMARK_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        return out.stdout.strip() or "unknown"
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def _package_version() -> str:
    """Reads `version:` from the package pubspec (no YAML dep for one line)."""
    try:
        for line in PACKAGE_PUBSPEC.read_text().splitlines():
            if line.startswith("version:"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return "unknown"
