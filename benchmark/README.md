# `text_sight` benchmarks

Reproducible benchmarks used to decide perf questions with data, not vibes —
specifically: **is changing the per-frame result wire representation worth it?**

> **Layers built:** the Dart codec micro-benchmark (emits JSON) and the Python
> `report` layer (charts + `SUMMARY.md`, under `python/`). There is **no
> `compare` layer** — no before/after transport exists to diff yet; it lands if
> a transport change is ever pursued.

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
