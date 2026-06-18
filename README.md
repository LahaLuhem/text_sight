# text_sight

[![pub package](https://img.shields.io/pub/v/text_sight.svg)](https://pub.dev/packages/text_sight)

Live, on-device text recognition — **Apple Vision on iOS, ML Kit on Android**. The text-scanning
sibling to [`mobile_scanner`](https://pub.dev/packages/mobile_scanner).

`text_sight` runs each platform's **native** recognizer, so **iOS links zero third-party ML
libraries** (Apple Vision is a system framework) — no GoogleMLKit, and none of the arm64 /
Swift Package Manager build warnings that come from running ML Kit on iOS. Android uses ML Kit,
declared only in its Gradle build. No recognition library ever enters your Dart dependencies.

## Features

- **Live camera recognition** — a `Texture`-backed preview widget with a per-frame stream of
  recognized lines.
- **Static one-shot** — recognize a still image from bytes or a file path with no camera,
  session, or permission (`TextSight.recognizeImage` / `.recognizePath`).
- **Native engines, zero bundling** — Apple Vision (iOS) / ML Kit (Android); nothing to add to
  `pubspec.yaml`.
- **Bring your own overlay** — `overlayBuilder` hands you each capture; boxes are normalized
  `[0,1]` with a **top-left** origin, unified across platforms, so your painter never branches.
- **Region of interest, torch, recognition level, languages, and per-line confidence.**

## Platform support

| Platform | Minimum | Engine |
|----------|---------|--------|
| iOS      | **18.0**| Apple Vision — Swift `RecognizeTextRequest` |
| Android  | API 24  | ML Kit Text Recognition v2 (Latin) |

> iOS targets 18.0 to use Vision's modern Swift API. Support for iOS 13–17 (via the legacy
> `VNRecognizeTextRequest`) is on the [roadmap](#roadmap).

## Install

```sh
flutter pub add text_sight
```

### iOS

Add a camera-usage description to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera to recognize text.</string>
```

### Android

The plugin's manifest already declares the `CAMERA` permission and the ML Kit model metadata —
nothing to add.

`text_sight` does **not** request camera permission for you. Request it at runtime (e.g. with
[`permission_handler`](https://pub.dev/packages/permission_handler)) and start the session once
it's granted.

## Usage

```dart
import 'package:text_sight/text_sight.dart';

final controller = TextSightController(); // defaults: RecognitionLevel.fast, en-US

// In your widget tree — the view does NOT auto-start:
TextSightView(
  controller: controller,
  onResult: (capture) {
    for (final line in capture.lines) {
      debugPrint('${line.text}  (confidence: ${line.confidence})');
    }
  },
  // line.boundingBox is normalized [0,1], top-left — scale by the preview constraints.
  overlayBuilder: (context, capture, constraints) =>
      CustomPaint(size: constraints.biggest, painter: MyBoxPainter(capture.lines)),
  placeholderBuilder: (context) => const ColoredBox(color: Color(0xFF000000)),
);

// Once camera permission is granted:
await controller.start();                        // open the camera + begin recognition
await controller.setTorchEnabled(enabled: true);
await controller.stop();                          // pause; the camera stays open
controller.dispose();                             // release the camera + texture
```

Configure the recognizer through `TextSightOptions`:

```dart
final controller = TextSightController(
  options: const TextSightOptions(
    level: RecognitionLevel.accurate,
    roi: Rect.fromLTWH(0.1, 0.4, 0.8, 0.2), // normalized [0,1] scan-box
    // languages: [Locale('en', 'US')],     // iOS only — see below
  ),
);
```

### One-shot (still image)

No camera, session, or permission — hand it encoded bytes or a file path:

```dart
final capture = await TextSight.recognizeImage(bytes); // PNG/JPEG bytes
// or: await TextSight.recognizePath('/path/to/photo.jpg');

for (final line in capture.lines) {
  debugPrint(line.text);
}
```

Defaults to `RecognitionLevel.accurate` (a still has no per-frame budget to protect); pass
`options:` to override. EXIF orientation is honoured natively, so `capture.quarterTurns` is always
`0`. Throws a `PlatformException` if the image can't be decoded (`decode-failed`) or the path is
missing (`file-not-found`).

See [`example/`](example/) for a complete app: runtime permission handling, a bounding-box
overlay, a recognized-text panel, torch control, and a one-shot recognition screen.

## How recognition maps across platforms

- **Coordinates** are normalized `[0,1]`, **top-left** origin, on both platforms — converted
  natively, so your overlay is platform-agnostic.
- **`confidence`** is `double?` in `[0,1]`. Both engines supply it, but the scales are **not
  comparable** across platforms; `null` means an engine omitted one for that line — never
  synthesized.
- **`recognitionLevel` and `languages`** apply on iOS (Vision). On Android the ML Kit Latin
  recognizer ignores them (Latin only).
- **Region of interest** is a normalized `Rect`: iOS restricts Vision to it; Android recognizes
  the full frame and filters lines whose center falls outside it.

## Limitations & known issues

- **iOS 18+ only** for now (the iOS 13–17 path is on the roadmap).
- **Latin script only on Android**; `recognitionLevel` / `languages` are no-ops there.
- **Region of interest on Android is a post-recognition filter, not a pre-crop** — correct
  results, but no speed-up yet (iOS gets the native cost reduction).
- **Performance**: live recognition is single-in-flight with frame back-pressure. The preview
  stays smooth, but under dense text or on lower-end devices the *recognition* rate drops below
  the camera frame rate (frames are dropped, not queued). Prefer `RecognitionLevel.fast` for
  live; `.accurate` is heavier.
- **Line-level results only** — word-level `RecognizedLine.elements` is reserved (`null`) for now.
- The **iOS Simulator has no camera**, so *live* recognition needs a physical device — but the
  static one-shot runs anywhere (it uses no camera).

The engineering detail behind these — and the backlog to work them out — lives in
[`APPENDIX.md#known-limitations`](APPENDIX.md#known-limitations).

## Roadmap

- Word-level `RecognizedElement`s.
- iOS 13–17 support via an availability-gated `VNRecognizeTextRequest` fallback.
- True region-of-interest pre-crop on Android.
- macOS support (Apple Vision is identical there).
- Additional Android scripts (Chinese, Devanagari, Japanese, Korean).

## License

See [LICENSE](LICENSE).
