# Codec round-trip: state of performance

Per-frame **decode** CPU and **wire size** of the recognition-results transport, by candidate encoding. Decode is what runs on the Dart UI isolate per delivered frame. `map_std` is today's wire and the baseline.

> **Scope.** Pure-Dart codec cost only, *not* native encode, real-device frame latency, or ML inference (which dominates end-to-end). These numbers bound the upside of a transport change. They are not an end-to-end speedup.

Captured: SDK `3.13.2` · package `0.2.2` · git `bf2d478` · N=30 · 2026-09-06T13:51:40.421779Z · per-machine, so your numbers will differ.

## Realistic profiles

| Profile | Candidate | Decode (µs) | Wire (bytes) | Δ decode | Δ bytes |
|---|---|--:|--:|--:|--:|
| sign | `map_std` | 1.59 | 416 | 0% | 0% |
| sign | `list_std` | 0.44 | 296 | -73% | -29% |
| sign | `pigeon` | 0.49 | 304 | -69% | -27% |
| sign | `packed_f32` | 0.13 | 104 | -92% | -75% |
| sign | `packed_f64` | 0.13 | 172 | -92% | -59% |
| receipt | `map_std` | 9.08 | 2640 | 0% | 0% |
| receipt | `list_std` | 2.24 | 2056 | -75% | -22% |
| receipt | `pigeon` | 2.48 | 2072 | -73% | -22% |
| receipt | `packed_f32` | 0.89 | 847 | -90% | -68% |
| receipt | `packed_f64` | 0.90 | 1275 | -90% | -52% |
| document | `map_std` | 27.19 | 9256 | 0% | 0% |
| document | `list_std` | 6.81 | 7592 | -75% | -18% |
| document | `pigeon` | 7.51 | 7632 | -72% | -18% |
| document | `packed_f32` | 3.28 | 4003 | -88% | -57% |
| document | `packed_f64` | 3.28 | 5271 | -88% | -43% |
| dense | `map_std` | 54.22 | 16496 | 0% | 0% |
| dense | `list_std` | 12.55 | 13144 | -77% | -20% |
| dense | `pigeon` | 14.09 | 13296 | -74% | -19% |
| dense | `packed_f32` | 5.91 | 5963 | -89% | -64% |
| dense | `packed_f64` | 5.83 | 8511 | -89% | -48% |

## Charts

![decode_vs_lines](decode_vs_lines.png)

![wire_bytes_vs_lines](wire_bytes_vs_lines.png)

![profile_decode_bars](profile_decode_bars.png)

