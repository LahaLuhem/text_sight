"""`build` — AOT-compile the codec_roundtrip micro-benchmark."""

from __future__ import annotations

import argparse
import subprocess
import sys

from text_sight_bench.config import BUILD_DIR, DART_ENTRYPOINT, EXE_PATH


def cmd_build(_args: argparse.Namespace) -> int:
    """Compiles the Dart entrypoint to a native exe (deterministic warmup)."""
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    cmd = ["dart", "compile", "exe", str(DART_ENTRYPOINT), "-o", str(EXE_PATH)]
    print(f"building: {' '.join(cmd)}")
    result = subprocess.run(cmd, check=False)
    if result.returncode == 0:
        print(f"built: {EXE_PATH}")
    else:
        print("build failed", file=sys.stderr)
    return result.returncode
