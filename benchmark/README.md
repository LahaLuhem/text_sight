# `text_sight` benchmarks

Reproducible benchmarks used to decide perf questions with data, not vibes —
specifically: **is changing the per-frame result wire representation worth it?**

> **Status: Phase 0 — measurement core.** The Dart codec micro-benchmark below
> runs and emits JSON. The Python orchestration + chart/report layer (mirroring
> the sibling `better_internet_connectivity_checker/benchmark`) is **not built
> yet** — it lands in Phase 1 only if the numbers justify the machinery.

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
├── build/                     AOT exes (gitignored)
└── results-local/             per-machine run outputs (gitignored)
```

The whole directory is excluded from the published pub.dev tarball via
[`.pubignore`](../.pubignore).

## Running

Requires the Dart SDK matching [`.fvmrc`](../.fvmrc) and `dart pub get` at the
repo root (pulls `benchmark_harness` + `standard_message_codec` from
`dev_dependencies`).

```bash
# AOT compile — deterministic warmup, unlike `dart run`.
dart compile exe benchmark/micro/codec_roundtrip.dart -o benchmark/build/codec_roundtrip

# Run. N=1 for a quick look; bump for a stable distribution.
benchmark/build/codec_roundtrip \
  --iterations 10 \
  --output benchmark/results-local/current/codec_roundtrip.json \
  --git-sha "$(git rev-parse --short HEAD)" \
  --package-version 0.0.0
```

A median table prints to stdout; the full per-iteration records land in the
`--output` JSON for the (future) Python analysis layer.

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
