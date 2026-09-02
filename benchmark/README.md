# `text_sight` benchmarks

Reproducible benchmarks used to decide perf questions with data, not vibes —
specifically: **is changing the per-frame result wire representation worth it?**

> **Layers built:** the Dart codec micro-benchmark (emits JSON), the on-device
> scenario layer (`app/`, driven by `flutter drive`), and the Python `report`
> layer (charts + summaries, under `python/`). There is **no `compare` layer**:
> no before/after transport exists to diff yet.

## Two layers, two questions

| Layer | Question | Runner | Fidelity |
|---|---|---|---|
| **Micro** (`micro/`) | is the wire representation worth changing? | `dart compile exe` + `benchmark_harness` | trustworthy absolute µs, host CPU |
| **Device** (`app/integration_test/`) | what does a call cost on a real phone? | `flutter drive --profile` + `integration_test` | real hardware, one number per call |

The micro layer bounds the upside of a transport change. The device layer answers
what a user actually waits for. Neither substitutes for the other.

## What this measures — and what it does not

The per-frame recognition results stream over a plain `EventChannel`, encoded
with Flutter's `StandardMessageCodec`. The **only** perf-relevant slice that is
(a) something we'd actually change and (b) measurable in pure Dart is the
**codec**: how long it takes to encode/decode one frame, and how big the wire
payload is.

| Measured (pure Dart, AOT, this machine) | **Not** measured (out of scope) |
|---|---|
| Decode time per frame | Native (Swift/Kotlin) encode cost |
| Encode time per frame | Real on-device frame latency / jank |
| Encoded wire byte count | GC-pause impact under live rendering |
| | ML inference (dominates end-to-end) |

So these numbers **bound the upside** of a transport change. They do **not**
predict an end-to-end speedup — on a real device the recognizer's inference and
texture handling dwarf the transport. **Decode is the headline metric**: in
production only the decode runs on the Dart UI isolate per frame (the encode
happens natively).

## Candidates (`harness/capture_codec.dart`)

| `candidate` | What it is |
|---|---|
| `map_std`     | **Baseline** — today's wire: `Map` with a string key per field. |
| `list_std`    | Positional `List`, no keys, same `StandardMessageCodec`. |
| `pigeon`      | Faithful replica of Pigeon's codec (1-byte type tag + positional fields). |
| `packed_f32`  | Tight hand-packed binary, `float32` coords (the BitArray-style packing). |
| `packed_f64`  | Same, `float64` coords — isolates "keys removed" from "narrower floats". |

Payloads (`harness/payloads.dart`) are deterministic and seeded: a line-count
sweep (`1, 5, 10, 25, 50, 100`) plus realistic profiles (`sign`, `receipt`,
`document`, `dense`).

## Layout

```
benchmark/
├── README.md                  this file
├── harness/                   bench_capture · payloads · capture_codec · result_writer · scenario_args
├── micro/codec_roundtrip.dart benchmark_harness entrypoint; emits result JSON + a stdout summary
├── app/                       minimal Flutter host for the on-device scenarios
│   ├── integration_test/      the scenarios (+ support/: page rendering, record shape)
│   └── test_driver/           perf_driver.dart, writes reportData to JSON
├── python/                    uv-managed orchestrator: build · run · report (+ tests)
├── reports/                   committed charts (PNG) + SUMMARY.md
├── build/                     AOT exes (gitignored)
└── results-local/             per-machine run outputs (gitignored)
```

The whole directory is excluded from the published pub.dev tarball via
[`.pubignore`](../.pubignore).

## Running

Requires the Dart SDK matching [`.fvmrc`](../.fvmrc) (+ `dart pub get` at the
repo root, for `benchmark_harness` + `standard_message_codec`) and
[`uv`](https://docs.astral.sh/uv/) for the Python orchestrator.

```bash
cd benchmark/python
uv sync                                   # one-time: create .venv, install + lock deps

uv run python run.py build                # AOT-compile (deterministic warmup, unlike `dart run`)
uv run python run.py run --iterations 10  # execute; writes results-local/current/codec_roundtrip.json
uv run python run.py report ../results-local/current/codec_roundtrip.json   # charts + SUMMARY.md -> reports/

uv run ruff check . && uv run pytest      # lint + test the orchestrator
```

### On a device

Plug in a phone (both, if you want the comparison) and:

```bash
uv run python run.py run-device --iterations 3
uv run python run.py report-device ../results-local/current/one_shot_latency_*.json
```

`run-device` finds every attached iOS and Android device, runs the scenario on each in profile mode,
and writes one JSON per platform. Useful flags: `--platform ios|android`, `--device <id>` to pin one,
`--scenario <name>`, and `--include-virtual` to allow a simulator or emulator. A virtual iOS target
falls back to `--debug`, since simulators cannot run profile mode, and the run says so: those timings
are for checking the plumbing, not for reporting.

`report-device` takes one or both JSONs and writes `one_shot_latency.png` plus `DEVICE_SUMMARY.md`.
Every row carries the lines the recognizer actually read, because a level that recognizes nothing
returns fast and would otherwise look like a win.

The other scenario is `--scenario codec_on_device`: the codec micro-benchmark, run on phone silicon
instead of a laptop. It imports `harness/` directly, so its payloads are byte-identical to the
micro's, and it emits the micro's record schema, which means plain `report` renders it:

```bash
uv run python run.py run-device --scenario codec_on_device
uv run python run.py report ../results-local/current/codec_on_device_ios.json --out ../results-local/device-codec/
```

Pass `--out`, or it overwrites the committed host charts. It exists to check one published claim:
the README quotes decode as a fraction of a 60 fps frame budget, but the committed numbers are
host-measured and a phone CPU is slower.

Third scenario, `--scenario live_throughput`, is the live camera one: recognized frames per second
and the gap between them, per recognition level.

```bash
uv run python run.py run-device --scenario live_throughput
uv run python run.py report-live ../results-local/current/live_throughput_*.json --out ../results-local/live/
```

It needs camera permission, which cannot be pre-granted because `flutter drive` uninstalls the app
afterwards. On Android the runner grants it over adb mid-run; on iOS tap Allow while the scenario
waits. `report-live` writes a table and no chart on purpose: with an uncontrolled scene, a chart
would imply precision these numbers do not have.

The Dart binary also runs standalone (a median table prints to stdout):

```bash
benchmark/build/codec_roundtrip --iterations 1 \
  --output benchmark/results-local/current/codec_roundtrip.json \
  --git-sha "$(git rev-parse --short HEAD)" --package-version 0.0.0
```

`report` writes to the committed `reports/` by default; pass `--out` for an
ad-hoc snapshot. **Capture N≥10 (ideally 30) on a quiet machine before
committing the canonical charts** — `reports/` is a deliberate, maintainer-only
refresh, like the sibling suite.

## Methodology

- **AOT compile**, not JIT — reproducible warmup.
- `exercise()` is overridden to one `run()`, so `measure()` reports microseconds
  per single encode/decode.
- `forceGc()` before each measurement window; `benchmark_harness` discards its
  own warmup pass.
- Report **median**, never mean — a single-threaded VM's GC outliers skew means.
- Baselines are **per-machine** (CPU/GC/scheduler differ); capture your own
  before/after on one quiet machine on AC power. Nothing under `results-local/`
  is committed.
