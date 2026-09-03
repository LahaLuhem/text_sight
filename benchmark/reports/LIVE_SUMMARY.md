# Live recognition throughput

How many frames per second the live path actually recognizes, per recognition level.

> **Scope.** Recognized frames per second over a fixed window, and the gap between them. Under the single-in-flight backpressure that gap is roughly one recognition. Directional only: the numbers depend entirely on what the camera was pointed at, so keep the scene fixed when comparing runs.

Captured: SDK `3.13.2` · package `0.2.0` · git `bef2acd` · N=3 · 2026-09-03T08:39:22.348013Z. Per device, so your hardware will differ.

- Only *recognized* frames are visible from Dart, so the drop ratio (camera frames delivered versus recognized) is not here. That needs native counters.
- A gap at the camera's frame interval (about 33 ms at 30 fps) means recognition is keeping up and the camera is the limit, not the recognizer.
- `level` is a no-op on Android, so its rows should match.
- **lines** is the median per capture. Zero means nothing readable was in frame, which makes the throughput number meaningless as a recognition measure.

| Platform | Level | Captures/s | Gap p50 (ms) | Gap p95 (ms) | Lines | Window (s) |
|---|---|--:|--:|--:|--:|--:|
| iOS (Apple Vision) | `fast` | 30.0 | 33.3 | 35.5 | 7 | 8 |
| iOS (Apple Vision) | `accurate` | 3.6 | 276.7 | 286.8 | 33 | 8 |
| Android (ML Kit) | `fast` | 5.0 | 205.4 | 232.1 | 21 | 8 |
| Android (ML Kit) | `accurate` | 5.2 | 186.2 | 226.3 | 22 | 8 |
