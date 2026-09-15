# One-shot recognition on device

How long `TextSight.recognizeImage` takes on real hardware, by page profile and recognition level.

> **Scope.** One-shot API latency as an app sees it: image decode, ML inference, the native encode and the channel hop, all inside one number. Inference dominates, but this does not isolate it. Live-camera throughput is a different measurement and not covered here.

Captured (Android): SDK `3.13.3` · package `0.2.2` · git `384ea54` · N=3 · 2026-09-15T10:09:01.038441Z
Captured (iOS): SDK `3.13.3` · package `0.2.2` · git `384ea54` · N=3 · 2026-09-15T10:09:59.609336Z

Measured on iOS and Android, so your hardware will differ.

- `level` is a no-op on Android, so its two rows should land on top of each other.
- Read **lines** beside the latency. A level that recognizes nothing returns fast, which would otherwise look like a win.
- Pages are rendered on-device at a fixed size, so decode cost is constant across profiles and the differences come from text density.

## iOS (Apple Vision)

| Profile | Level | Lines | p50 (ms) | p95 (ms) |
|---|---|--:|--:|--:|
| sign | `fast` | 3 | 48.8 | 49.4 |
| sign | `fast+corrected` | 3 | 49.8 | 50.0 |
| sign | `accurate` | 3 | 206.8 | 214.3 |
| sign | `accurate+corrected` | 3 | 225.9 | 227.9 |
| receipt | `fast` | 21 | 63.9 | 65.4 |
| receipt | `fast+corrected` | 21 | 76.8 | 76.9 |
| receipt | `accurate` | 21 | 257.8 | 259.3 |
| receipt | `accurate+corrected` | 21 | 341.6 | 342.2 |
| document | `fast` | 63 | 100.6 | 101.0 |
| document | `fast+corrected` | 63 | 199.2 | 200.4 |
| document | `accurate` | 63 | 403.8 | 404.7 |
| document | `accurate+corrected` | 63 | 735.9 | 759.1 |
| dense | `fast` | 0 *(read nothing)* | 72.1 | 72.6 |
| dense | `fast+corrected` | 0 *(read nothing)* | 72.2 | 73.9 |
| dense | `accurate` | 0 *(read nothing)* | 160.2 | 162.0 |
| dense | `accurate+corrected` | 0 *(read nothing)* | 160.3 | 160.4 |

## Android (ML Kit)

| Profile | Level | Lines | p50 (ms) | p95 (ms) |
|---|---|--:|--:|--:|
| sign | `fast` | 3 | 91.3 | 92.6 |
| sign | `fast+corrected` | 3 | 87.9 | 90.0 |
| sign | `accurate` | 3 | 83.2 | 90.6 |
| sign | `accurate+corrected` | 3 | 79.7 | 88.5 |
| receipt | `fast` | 21 | 148.1 | 149.5 |
| receipt | `fast+corrected` | 21 | 152.6 | 158.5 |
| receipt | `accurate` | 21 | 144.4 | 156.2 |
| receipt | `accurate+corrected` | 21 | 135.7 | 137.0 |
| document | `fast` | 63 | 308.1 | 337.1 |
| document | `fast+corrected` | 63 | 278.5 | 291.6 |
| document | `accurate` | 63 | 272.8 | 291.2 |
| document | `accurate+corrected` | 63 | 277.6 | 297.6 |
| dense | `fast` | 126 | 318.2 | 332.3 |
| dense | `fast+corrected` | 126 | 316.5 | 327.9 |
| dense | `accurate` | 126 | 316.8 | 333.1 |
| dense | `accurate+corrected` | 126 | 316.8 | 325.5 |

![One-shot latency](one_shot_latency.png)
