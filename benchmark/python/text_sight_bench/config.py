"""Shared constants — paths, chart styling, candidate / profile ordering."""

from __future__ import annotations

from pathlib import Path

# This file: benchmark/python/text_sight_bench/config.py -> parents[2] == benchmark/
BENCHMARK_ROOT = Path(__file__).resolve().parents[2]
DART_ENTRYPOINT = BENCHMARK_ROOT / "micro" / "codec_roundtrip.dart"
BUILD_DIR = BENCHMARK_ROOT / "build"
EXE_PATH = BUILD_DIR / "codec_roundtrip"
DEFAULT_RESULTS_DIR = BENCHMARK_ROOT / "results-local" / "current"
COMMITTED_REPORTS_DIR = BENCHMARK_ROOT / "reports"
PACKAGE_PUBSPEC = BENCHMARK_ROOT.parent / "pubspec.yaml"

RESULT_FILENAME = "codec_roundtrip.json"

CHART_DPI = 140

# Baseline first; a stable colour per candidate across every chart.
CANDIDATE_ORDER = ["map_std", "list_std", "pigeon", "packed_f32", "packed_f64"]
CANDIDATE_COLORS = {
    "map_std": "#c44e52",  # baseline — red
    "list_std": "#4c72b0",
    "pigeon": "#55a868",
    "packed_f32": "#8172b3",
    "packed_f64": "#ccb974",
}

# Realistic profiles, ordered small -> large frame.
PROFILE_ORDER = ["sign", "receipt", "document", "dense"]

# The baseline candidate every delta is measured against.
BASELINE_CANDIDATE = "map_std"
