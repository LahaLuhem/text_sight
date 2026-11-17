# Live recognition throughput

What the live path *sustains*, per recognition level, on the whole frame and through the README's strip. Windows where the phone was boosting or stalling are left out, so this is the rate an app actually holds.

> **Scope.** Recognized frames per second over a fixed window, and the gap between them. Under the single-in-flight backpressure that gap is roughly one recognition. Directional only: the numbers depend entirely on what the camera was pointed at, so keep the scene fixed when comparing runs.

Captured (Android): SDK `3.14.0` · package `1.0.0` · git `a0df75d` · N=3 · 2026-11-17T14:21:06.066677Z
Captured (iOS): SDK `3.14.0` · package `1.0.0` · git `a0df75d` · N=3 · 2026-11-17T14:21:26.373803Z

Measured on iOS and Android, so your hardware will differ.

- Only *recognized* frames are visible from Dart, so the drop ratio (camera frames delivered versus recognized) is not here. That needs native counters.
- A gap at the camera's frame interval (about 33 ms at 30 fps) means recognition is keeping up and the camera is the limit, not the recognizer.
- `level` is a no-op on Android, so its rows should match, the strip ones among themselves.
- **Your users will see better than this at first.** A cold phone boosts hard, so a short scan runs faster than a long one. The run burns the device in before measuring and keeps only the windows near the run's median rate, so this is the sustained floor, not the opening peak.
- **lines** is the median per capture. Zero means nothing readable was in frame, which makes the throughput number meaningless as a recognition measure.

| Platform | Level | Sustained cap/s | Gap p50 (ms) | Gap p95 (ms) | Lines | Window (s) |
|---|---|--:|--:|--:|--:|--:|
| iOS (Apple Vision) | `fast` | 19.7 | 51.7 | 65.1 | 12 | 8 |
| iOS (Apple Vision) | `fast+strip` | 30.0 | 33.5 | 40.1 | 4 | 8 |
| iOS (Apple Vision) | `fast+corrected` | 23.7 | 41.3 | 62.0 | 12 | 8 |
| iOS (Apple Vision) | `fast+corrected+strip` | 30.0 | 33.5 | 37.2 | 3 | 8 |
| iOS (Apple Vision) | `accurate` | 7.4 | 134.4 | 144.1 | 10 | 8 |
| iOS (Apple Vision) | `accurate+strip` | 8.2 | 121.4 | 127.2 | 3 | 8 |
| iOS (Apple Vision) | `accurate+corrected` | 6.9 | 145.2 | 149.9 | 10 | 8 |
| iOS (Apple Vision) | `accurate+corrected+strip` | 7.4 | 135.2 | 140.7 | 3 | 8 |
| Android (ML Kit) | `fast` | 8.0 | 125.3 | 139.8 | 22 | 8 |
| Android (ML Kit) | `fast+strip` | 15.7 | 61.1 | 72.2 | 5 | 8 |
| Android (ML Kit) | `fast+corrected` | 10.1 | 99.2 | 112.2 | 12 | 8 |
| Android (ML Kit) | `fast+corrected+strip` | 13.4 | 62.3 | 132.2 | 4 | 8 |
| Android (ML Kit) | `accurate` | 11.2 | 87.5 | 106.0 | 9 | 8 |
| Android (ML Kit) | `accurate+strip` | 16.9 | 58.6 | 70.8 | 5 | 8 |
| Android (ML Kit) | `accurate+corrected` | 10.4 | 94.3 | 128.6 | 9 | 8 |
| Android (ML Kit) | `accurate+corrected+strip` | 8.0 | 123.6 | 153.3 | 3 | 8 |

Frames delivered by the capture session, as the preview receives them:

- iOS (Apple Vision): 1080x1920
- Android (ML Kit): 1440x1920
