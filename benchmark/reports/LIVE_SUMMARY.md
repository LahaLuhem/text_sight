# Live recognition throughput

What the live path *sustains*, per recognition level. Windows where the phone was boosting or stalling are left out, so this is the rate an app actually holds.

> **Scope.** Recognized frames per second over a fixed window, and the gap between them. Under the single-in-flight backpressure that gap is roughly one recognition. Directional only: the numbers depend entirely on what the camera was pointed at, so keep the scene fixed when comparing runs.

Captured (Android): SDK `3.13.3` · package `0.2.2` · git `384ea54` · N=3 · 2026-09-15T10:18:45.400559Z
Captured (iOS): SDK `3.13.3` · package `0.2.2` · git `384ea54` · N=3 · 2026-09-15T10:19:16.174310Z

Measured on iOS and Android, so your hardware will differ.

- Only *recognized* frames are visible from Dart, so the drop ratio (camera frames delivered versus recognized) is not here. That needs native counters.
- A gap at the camera's frame interval (about 33 ms at 30 fps) means recognition is keeping up and the camera is the limit, not the recognizer.
- `level` is a no-op on Android, so its rows should match.
- **Your users will see better than this at first.** A cold phone boosts hard, so a short scan runs faster than a long one. The run burns the device in before measuring and keeps only the windows near the run's median rate, so this is the sustained floor, not the opening peak.
- **lines** is the median per capture. Zero means nothing readable was in frame, which makes the throughput number meaningless as a recognition measure.

| Platform | Level | Sustained cap/s | Gap p50 (ms) | Gap p95 (ms) | Lines | Window (s) |
|---|---|--:|--:|--:|--:|--:|
| iOS (Apple Vision) | `fast` | 19.0 | 52.8 | 56.4 | 9 | 8 |
| iOS (Apple Vision) | `fast+corrected` | 16.9 | 59.5 | 62.8 | 9 | 8 |
| iOS (Apple Vision) | `accurate` | 5.0 | 199.1 | 205.3 | 15 | 8 |
| iOS (Apple Vision) | `accurate+corrected` | 3.9 | 257.8 | 273.1 | 13 | 8 |
| Android (ML Kit) | `fast` | 5.5 | 182.9 | 221.1 | 17 | 8 |
| Android (ML Kit) | `fast+corrected` | 5.5 | 188.8 | 217.9 | 16 | 8 |
| Android (ML Kit) | `accurate` | 5.4 | 189.5 | 207.3 | 17 | 8 |
| Android (ML Kit) | `accurate+corrected` | 5.1 | 200.9 | 227.0 | 15 | 8 |

Frames delivered by the capture session, as the preview receives them:

- iOS (Apple Vision): 1080x1920
- Android (ML Kit): 1440x1920
