# Codec round-trip — state of performance

Per-frame **decode** CPU and **wire size** of the recognition-results transport, by candidate encoding. Decode is what runs on the Dart UI isolate per delivered frame; `map_std` is today's wire and the baseline.

> **Scope.** Pure-Dart codec cost only — *not* native encode, real-device frame latency, or ML inference (which dominates end-to-end). These numbers bound the upside of a transport change; they are not an end-to-end speedup.

Captured: SDK `3.12.2` · package `0.0.0` · git `4eeb778` · N=30 · 2026-06-19T16:26:30.354491Z · per-machine — your numbers will differ.

## Realistic profiles

| Profile | Candidate | Decode (µs) | Wire (bytes) | Δ decode | Δ bytes |
|---|---|--:|--:|--:|--:|
| sign | `map_std` | 1.64 | 432 | 0% | 0% |
| sign | `list_std` | 0.42 | 312 | -74% | -28% |
| sign | `pigeon` | 0.49 | 312 | -70% | -28% |
| sign | `packed_f32` | 0.14 | 116 | -92% | -73% |
| sign | `packed_f64` | 0.14 | 184 | -91% | -57% |
| receipt | `map_std` | 9.57 | 2608 | 0% | 0% |
| receipt | `list_std` | 2.21 | 2016 | -77% | -23% |
| receipt | `pigeon` | 2.44 | 2024 | -75% | -22% |
| receipt | `packed_f32` | 0.91 | 852 | -91% | -67% |
| receipt | `packed_f64` | 0.90 | 1280 | -91% | -51% |
| document | `map_std` | 28.39 | 9384 | 0% | 0% |
| document | `list_std` | 6.70 | 7648 | -76% | -18% |
| document | `pigeon` | 7.46 | 7704 | -74% | -18% |
| document | `packed_f32` | 3.36 | 4149 | -88% | -56% |
| document | `packed_f64` | 3.36 | 5417 | -88% | -42% |
| dense | `map_std` | 56.83 | 16496 | 0% | 0% |
| dense | `list_std` | 12.68 | 13136 | -78% | -20% |
| dense | `pigeon` | 14.02 | 13240 | -75% | -20% |
| dense | `packed_f32` | 6.00 | 6099 | -89% | -63% |
| dense | `packed_f64` | 6.03 | 8647 | -89% | -48% |

## Charts

![decode_vs_lines](decode_vs_lines.png)

![wire_bytes_vs_lines](wire_bytes_vs_lines.png)

![profile_decode_bars](profile_decode_bars.png)

