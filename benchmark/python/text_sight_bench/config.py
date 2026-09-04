"""Shared constants: paths, chart styling, candidate / profile ordering."""

from __future__ import annotations

from pathlib import Path

# parents[2] == benchmark/
BENCHMARK_ROOT = Path(__file__).resolve().parents[2]
DART_ENTRYPOINT = BENCHMARK_ROOT / "micro" / "codec_roundtrip.dart"
BUILD_DIR = BENCHMARK_ROOT / "build"
EXE_PATH = BUILD_DIR / "codec_roundtrip"
DEFAULT_RESULTS_DIR = BENCHMARK_ROOT / "results-local" / "current"
COMMITTED_REPORTS_DIR = BENCHMARK_ROOT / "reports"
PACKAGE_PUBSPEC = BENCHMARK_ROOT.parent / "pubspec.yaml"

RESULT_FILENAME = "codec_roundtrip.json"

CHART_DPI = 140

# Baseline first, and a stable colour per candidate across charts.
CANDIDATE_ORDER = ["map_std", "list_std", "pigeon", "packed_f32", "packed_f64"]
CANDIDATE_COLORS = {
    "map_std": "#c44e52",  # baseline
    "list_std": "#4c72b0",
    "pigeon": "#55a868",
    "packed_f32": "#8172b3",
    "packed_f64": "#ccb974",
}

# Ordered small -> large frame.
PROFILE_ORDER = ["sign", "receipt", "document", "dense"]

# What every delta is measured against.
BASELINE_CANDIDATE = "map_std"

# What "does the decode fit in one frame" gets measured against.
FRAME_BUDGET_FPS = 60

# --- Device scenarios, driven by `flutter drive` ---

APP_DIR = BENCHMARK_ROOT / "app"
PERF_DRIVER = "test_driver/perf_driver.dart"
DEVICE_SCENARIOS = {
    "one_shot_latency": "integration_test/one_shot_latency_test.dart",
    "codec_on_device": "integration_test/codec_on_device_test.dart",
    "live_throughput": "integration_test/live_throughput_test.dart",
}
DEVICE_SUMMARY_FILENAME = "DEVICE_SUMMARY.md"

# Cheapest first, so charts read left to right as more work.
LEVEL_ORDER = ["fast", "accurate"]
LEVEL_COLORS = {"fast": "#4c72b0", "accurate": "#c44e52"}
PLATFORM_ORDER = ["ios", "android"]
PLATFORM_LABELS = {"ios": "iOS (Apple Vision)", "android": "Android (ML Kit)"}
# For prose, where naming the recognizer would be noise.
PLATFORM_NAMES = {"ios": "iOS", "android": "Android"}

# For the adb camera grant the live scenario needs.
BENCH_APP_ANDROID_ID = "com.lahaluhem.benchmark.text_sight_bench_host"

# Need camera permission granted mid-run.
CAMERA_SCENARIOS = frozenset({"live_throughput"})

LIVE_SUMMARY_FILENAME = "LIVE_SUMMARY.md"
