# Live recognition throughput

How many frames per second the live path actually recognizes, per recognition level.

> **Scope.** Recognized frames per second over a fixed window, and the gap between them. Under the single-in-flight backpressure that gap is roughly one recognition. Directional only: the numbers depend entirely on what the camera was pointed at, so keep the scene fixed when comparing runs.

Captured: SDK `3.13.2` · package `0.2.0` · git `21c6760` · N=3 · 2026-09-03T11:03:47.306637Z. Per device, so your hardware will differ.

- Only *recognized* frames are visible from Dart, so the drop ratio (camera frames delivered versus recognized) is not here. That needs native counters.
- A gap at the camera's frame interval (about 33 ms at 30 fps) means recognition is keeping up and the camera is the limit, not the recognizer.
- `level` is a no-op on Android, so its rows should match.
- **lines** is the median per capture. Zero means nothing readable was in frame, which makes the throughput number meaningless as a recognition measure.

| Platform | Level | Captures/s | Gap p50 (ms) | Gap p95 (ms) | Lines | Window (s) |
|---|---|--:|--:|--:|--:|--:|
| iOS (Apple Vision) | `fast` | 30.0 | 33.3 | 34.4 | 8 | 8 |
| iOS (Apple Vision) | `accurate` | 4.0 | 249.9 | 258.0 | 21 | 8 |
| Android (ML Kit) | `fast` | 5.9 | 166.9 | 198.1 | 11 | 8 |
| Android (ML Kit) | `accurate` | 6.6 | 150.5 | 178.8 | 11 | 8 |

Frames delivered by the capture session, as the preview receives them:

- iOS (Apple Vision): 1080x1920
- Android (ML Kit): 480x640
