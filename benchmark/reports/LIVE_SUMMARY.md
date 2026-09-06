# Live recognition throughput

What the live path *sustains*, per recognition level. Windows where the phone was boosting or stalling are left out, so this is the rate an app actually holds.

> **Scope.** Recognized frames per second over a fixed window, and the gap between them. Under the single-in-flight backpressure that gap is roughly one recognition. Directional only: the numbers depend entirely on what the camera was pointed at, so keep the scene fixed when comparing runs.

Captured (Android): SDK `3.13.2` · package `0.2.2` · git `bf2d478` · N=3 · 2026-09-06T18:36:21.446658Z
Captured (iOS): SDK `3.13.2` · package `0.2.0` · git `21c6760` · N=3 · 2026-09-03T11:05:05.889411Z

Measured on iOS and Android, so your hardware will differ.

- Only *recognized* frames are visible from Dart, so the drop ratio (camera frames delivered versus recognized) is not here. That needs native counters.
- A gap at the camera's frame interval (about 33 ms at 30 fps) means recognition is keeping up and the camera is the limit, not the recognizer.
- `level` is a no-op on Android, so its rows should match.
- **Your users will see better than this for a while.** A cold phone boosts hard: this Sony held about 8 captures/s for the first minute of continuous scanning before settling to the sustained figure below, so a short scan feels roughly twice as fast as a long one. The run burns the device in first, so the table reports the floor rather than the peak.
- **lines** is the median per capture. Zero means nothing readable was in frame, which makes the throughput number meaningless as a recognition measure.

| Platform | Level | Sustained cap/s | Gap p50 (ms) | Gap p95 (ms) | Lines | Window (s) |
|---|---|--:|--:|--:|--:|--:|
| iOS (Apple Vision) | `fast` | 30.0 | 33.3 | 34.4 | 8 | 8 |
| iOS (Apple Vision) | `accurate` | 4.0 | 249.9 | 258.0 | 21 | 8 |
| Android (ML Kit) | `fast` | 4.5 | 219.5 | 242.6 | 9 | 8 |
| Android (ML Kit) | `fast+corrected` | 4.5 | 218.5 | 233.5 | 8 | 8 |
| Android (ML Kit) | `accurate` | 4.5 | 219.2 | 235.9 | 8 | 8 |
| Android (ML Kit) | `accurate+corrected` | 4.5 | 217.8 | 256.2 | 10 | 8 |

Frames delivered by the capture session, as the preview receives them:

- iOS (Apple Vision): 1080x1920
- Android (ML Kit): 1440x1920
