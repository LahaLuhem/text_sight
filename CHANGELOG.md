## [Unreleased]
### Added
- \[#59\] TextSightEngine.confidenceScale reports what a confidence number means on this device: visionGraded, visionCoarse or mlKit. Branch on its isRankable flag to know whether sorting lines inside one capture tells you anything.
- \[#59\] DarwinOptions.minimumTextHeight sets the smallest text Vision will read, as a fraction of the frame height. A higher floor is faster and blind to small print, and it stays frame-relative even when roi narrows the scan box.
- example: run the live scanner on the iOS Simulator with a stand-in camera

### Changed
- \[#59\] Vision-only settings moved under TextSightOptions.darwin: recognitionLevel, usesLanguageCorrection, preferredLanguages (was languages) and minimumTextHeight. Only roi stays top-level, since it is the one setting both platforms honour.
- \[#59\] TextSightController.updateOptions replaces updateRecognitionLevel, updateLanguages and updateRegionOfInterest, and a single options getter replaces the three read-backs. It sets everything at once, so read options first when you only mean to change one thing.
- \[#59\] RecognitionLevel is now just fast or accurate, with language correction split out into DarwinOptions.usesLanguageCorrection. So fast can correct and accurate can skip it, and the live path now corrects by default where fast used to leave it off.
- \[#59\] RecognizedLine.confidence is a required non-null double. Both engines always send a value, so there is no null to guard, but a number only means something next to the scale that produced it.
- \[#45\] Surface the capture session's state as controller.sessionState, with stop() renamed pauseRecognition() and isRunning renamed isRecognizing

### Fixed
- \[#59\] Android no longer takes recognition settings it silently drops. setRecognitionLevel and setLanguages were empty no-ops that reported success, and the controller read them straight back as if they had landed. The Vision-only settings now sit behind darwin, so there is nothing left to accept and discard.
- \[#59\] Changing several settings at once no longer tears. The iOS side took its state lock once per setter, so a frame caught between two calls could be read with the new level and the old languages. updateOptions applies the whole set under one lock hold.
- \[#59\] RecognizedLine.confidence no longer documents a null that never arrives. The old docs had you threshold with (confidence ?? 1) while warning in the same breath that the scales are not comparable, and gave you no way to find out which scale you had.

## [0.2.2] - 2026-09-05
### Fixed
- \[#60\] never write a blank chart
- \[#58\] Decide Vision's text-height floor instead of inheriting it
- \[#61\] Decide the capture resolution instead of inheriting it

## [0.2.1] - 2026-09-04
### Added
- \[#52\] Capture the on-device benchmark numbers

### Fixed
- \[#47\] Release the iOS session on engine detach + scaffold device benchmarks
- \[#2\] Start the next recognition when the recognizer goes free
- \[#51\] Define the re-initialize contract

## [0.2.0] - 2026-08-31
### Changed
- Bumped Dart to ^3.13

### Fixed
- \[#40\] Crash on engine detach when no capture session ever started
- \[#6\] Live session auto-pauses in the background and restores the torch on return
- \[#39\] Migrate the Pigeon control channel to native suspend and async throws

## [0.1.1] - 2026-06-24
### Added
- \#14 Add native camera-permission handling (no third-party package needed)

### Changed
- \#5 Support iOS 13–17 via a Vision recognizer hybrid

### Fixed
- iOS portrait-recognition orientation accuracy fix

## [0.1.0] - 2026-06-22
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

[Unreleased]: https://github.com/LahaLuhem/text_sight/compare/0.2.2...HEAD
[0.2.2]: https://github.com/LahaLuhem/text_sight/compare/0.2.1...0.2.2
[0.2.1]: https://github.com/LahaLuhem/text_sight/compare/0.2.0...0.2.1
[0.2.0]: https://github.com/LahaLuhem/text_sight/compare/0.1.1...0.2.0
[0.1.1]: https://github.com/LahaLuhem/text_sight/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/LahaLuhem/text_sight/compare/0.0.1...0.1.0
[0.0.1]: https://github.com/LahaLuhem/text_sight/releases/tag/0.0.1
