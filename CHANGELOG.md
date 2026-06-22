## [Unreleased]
### Added
- \[#7\] TextSightModel.ensureReady() and TextSightModel.readiness — app-controlled, non-blocking on-device model loading, with a sealed TextSightReadinessState (ModelReady / ModelDownloading / ModelUnavailable)
- \[#7\] com.lahaluhem.text\_sight.useBundled Gradle flag — bundle the ML Kit model into the APK (instant, offline) instead of the default unbundled Play Services download

### Changed
- \[#7\] Android no longer prefetches the OCR model at install time; the unbundled model now downloads on first use (or when TextSightModel.ensureReady() is called)

## [0.0.1] - 2026-06-20
### Added
- Live, on-device camera text recognition via `TextSightController` and `TextSightView` — Apple Vision on iOS, ML Kit on Android — with a per-frame results stream and a confidence-coloured overlay hook.
- Native-only recognition, no bundling: iOS links zero third-party ML libraries (Apple Vision is a system framework — no GoogleMLKit, no arm64 / Swift Package Manager warnings); ML Kit stays in the Android Gradle build, never in your pubspec.
- One-shot still-image recognition via `TextSight.recognizeImage` (bytes) and `TextSight.recognizePath` (file) — no camera, session, or permission.
- Recognizer configuration on the controller: region of interest (a normalized `Rect`), recognition level, language preferences, and torch.
- A unified result model — per-line confidence and normalized `[0,1]` top-left bounding boxes, identical across platforms, with a rotation-aware preview.

[Unreleased]: https://github.com/LahaLuhem/text_sight/compare/0.0.1...HEAD
[0.0.1]: https://github.com/LahaLuhem/text_sight/releases/tag/0.0.1
