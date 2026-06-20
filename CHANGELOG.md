## [0.0.1] - 2026-06-20
### Added
- Live, on-device camera text recognition via `TextSightController` and `TextSightView` — Apple Vision on iOS, ML Kit on Android — with a per-frame results stream and a confidence-coloured overlay hook.
- Native-only recognition, no bundling: iOS links zero third-party ML libraries (Apple Vision is a system framework — no GoogleMLKit, no arm64 / Swift Package Manager warnings); ML Kit stays in the Android Gradle build, never in your pubspec.
- One-shot still-image recognition via `TextSight.recognizeImage` (bytes) and `TextSight.recognizePath` (file) — no camera, session, or permission.
- Recognizer configuration on the controller: region of interest (a normalized `Rect`), recognition level, language preferences, and torch.
- A unified result model — per-line confidence and normalized `[0,1]` top-left bounding boxes, identical across platforms, with a rotation-aware preview.

[0.0.1]: https://github.com/LahaLuhem/text_sight/releases/tag/0.0.1
