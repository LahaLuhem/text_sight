# One-shot recognition on device

How long `TextSight.recognizeImage` takes on real hardware, by page profile and recognition level.

> **Scope.** One-shot API latency as an app sees it: image decode, ML inference, the native encode and the channel hop, all inside one number. Inference dominates, but this does not isolate it. Live-camera throughput is a different measurement and not covered here.

Captured (Android): SDK `3.13.2` · package `0.2.2` · git `bf2d478` · N=3 · 2026-09-06T13:33:54.999847Z
Captured (iOS): SDK `3.13.2` · package `0.2.0` · git `bef2acd` · N=3 · 2026-09-03T08:31:25.632612Z

Measured on iOS and Android, so your hardware will differ.

- `level` is a no-op on Android, so its two rows should land on top of each other.
- Read **lines** beside the latency. A level that recognizes nothing returns fast, which would otherwise look like a win.
- Pages are rendered on-device at a fixed size, so decode cost is constant across profiles and the differences come from text density.

## iOS (Apple Vision)

| Profile | Level | Lines | p50 (ms) | p95 (ms) |
|---|---|--:|--:|--:|
| sign | `fast` | 3 | 49.0 | 52.3 |
| sign | `accurate` | 3 | 197.1 | 200.7 |
| receipt | `fast` | 15 | 63.4 | 63.5 |
| receipt | `accurate` | 21 | 310.3 | 311.7 |
| document | `fast` | 0 *(read nothing)* | 87.7 | 88.3 |
| document | `accurate` | 62 | 719.8 | 726.0 |
| dense | `fast` | 0 *(read nothing)* | 72.1 | 73.5 |
| dense | `accurate` | 0 *(read nothing)* | 157.6 | 160.0 |

## Android (ML Kit)

| Profile | Level | Lines | p50 (ms) | p95 (ms) |
|---|---|--:|--:|--:|
| sign | `fast` | 3 | 146.9 | 147.1 |
| sign | `fast+corrected` | 3 | 130.0 | 137.5 |
| sign | `accurate` | 3 | 129.2 | 132.4 |
| sign | `accurate+corrected` | 3 | 127.0 | 141.5 |
| receipt | `fast` | 21 | 203.5 | 209.0 |
| receipt | `fast+corrected` | 21 | 183.9 | 188.0 |
| receipt | `accurate` | 21 | 181.7 | 191.9 |
| receipt | `accurate+corrected` | 21 | 193.1 | 206.2 |
| document | `fast` | 63 | 409.5 | 418.6 |
| document | `fast+corrected` | 63 | 392.9 | 411.8 |
| document | `accurate` | 63 | 397.9 | 416.6 |
| document | `accurate+corrected` | 63 | 421.3 | 426.8 |
| dense | `fast` | 128 | 725.1 | 809.5 |
| dense | `fast+corrected` | 128 | 551.3 | 605.0 |
| dense | `accurate` | 128 | 628.7 | 671.2 |
| dense | `accurate+corrected` | 128 | 480.1 | 498.6 |

![One-shot latency](one_shot_latency.png)
