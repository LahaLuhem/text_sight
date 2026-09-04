[![Package checks](https://github.com/LahaLuhem/text_sight/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/text_sight/actions/workflows/package.yml)
[![Pub Version](https://img.shields.io/pub/v/text_sight.svg)](https://pub.dev/packages/text_sight)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/LahaLuhem/text_sight/pulls) [![Pub Package](https://img.shields.io/pub/v/text_sight.svg)](https://pub.dev/packages/text_sight)
[![Pub Points](https://img.shields.io/pub/points/text_sight?logo=dart)](https://pub.dev/packages/text_sight/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/LahaLuhem/text_sight.svg)](https://github.com/LahaLuhem/text_sight/issues) [![GitHub closed issues](https://img.shields.io/github/issues-closed/LahaLuhem/text_sight.svg)](https://github.com/LahaLuhem/text_sight/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/LahaLuhem/text_sight.svg)](https://github.com/LahaLuhem/text_sight/pulls) [![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed/LahaLuhem/text_sight.svg)](https://github.com/LahaLuhem/text_sight/pulls?q=is%3Apr+is%3Aclosed)

**Live, on-device text recognition for Flutter.** Apple Vision on iOS, ML Kit on Android. Like
[`mobile_scanner`](https://pub.dev/packages/mobile_scanner), but for text instead of barcodes.

<p align="center">
  <img src="https://raw.githubusercontent.com/LahaLuhem/text_sight/main/doc/screenshots/1-live-ocr.webp" width="260" alt="Live text recognition with confidence-coloured boxes over the camera feed">
</p>

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Why text_sight?](#why-text_sight)
- [A quick taste](#a-quick-taste)
    * [Live camera](#live-camera)
    * [A single image](#a-single-image)
    * [Tweak it mid-session](#tweak-it-mid-session)
    * [The example app](#the-example-app)
- [API at a glance](#api-at-a-glance)
- [Platform support](#platform-support)
    * [Gotchas](#gotchas)
- [Install](#install)
    * [iOS](#ios)
    * [Android](#android)
- [The recognition model](#the-recognition-model)
    * [Give it a nudge](#give-it-a-nudge)
    * [Show the download](#show-the-download)
    * [Or just bundle it](#or-just-bundle-it)
- [Performance](#performance)
- [Going deeper](#going-deeper)

<!-- TOC end -->

## Why text_sight?

Most cross-platform OCR plugins run Google ML Kit on *both* platforms, which quietly drags
`GoogleMLKit` into your iOS build. text_sight doesn't.

|                                         |                                                                                                                                                                                    |
|-----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **No ML framework in your iOS app**     | iOS recognition is Apple Vision, which is already part of the OS. No GoogleMLKit, nothing third-party to ship, so your iOS build stays smaller. CI fails the moment one sneaks in. |
| **Android fetches its model on demand** | The ML Kit model stays unbundled by default, so your APK carries a ~260 KB stub instead of the whole thing. Want it baked in? One line of Gradle.                                  |
| **`fast` or `accurate`, per call**      | Pick low latency or better reading, and switch mid-session. iOS only, since ML Kit's Latin recognizer has no such knob.                                                            |
| **No permission package**               | `requestCameraPermission()` goes straight to AVFoundation and the Android permission flow. Already using `permission_handler`? That still works.                                   |
| **The same boxes everywhere**           | Every box is normalized `[0, 1]` from the top-left on both platforms, so your overlay never branches on `Platform`.                                                                |
| **Camera optional**                     | One-shot recognition reads bytes or a file path. No camera, no permission, runs anywhere.                                                                                          |

Nothing recognition-related ever reaches your `pubspec.yaml`, so the two platforms can't bleed into
each other.

## A quick taste

### Live camera

Point the camera at some text:

```dart
final controller = TextSightController();

TextSightView(
  controller: controller,
  onResult: (capture) => capture.lines.forEach((line) => print(line.text)),
  overlayBuilder: (context, capture, constraints) => /* paint line.boundingBox */,
);

await controller.requestCameraPermission(); // prompts via the OS
await controller.start();
```

### A single image

No camera, no permission, works on a simulator:

```dart
final capture = await TextSight.recognizeImage(bytes); // or .recognizePath('/photo.jpg')
```

### Tweak it mid-session

Hand the controller a **region of interest** to scan just a scan-box, or change the recognition
level, languages, or torch while the session runs.

```dart
TextSightController(options: TextSightOptions(roi: Rect.fromLTWH(0.1, 0.4, 0.8, 0.2)));
```

Backgrounding the app pauses the session on its own and picks it back up when you return.

One Android thing worth knowing up front: the model downloads on first use, so [give it a head
start](#the-recognition-model) when the user opens your scanner, or that first scan comes back
empty.

### The example app

The [`example/`](example/) app is the place to look next. Live overlay, torch, region-of-interest,
permissions, and the one-shot screen, all wired up and ready to crib from.

<table>
  <tr>
    <td align="center"><img src="https://raw.githubusercontent.com/LahaLuhem/text_sight/main/doc/screenshots/2-one-shot-android.png" width="240" alt="One-shot recognition on Android"><br><sub><b>Android</b> · ML Kit</sub></td>
    <td align="center"><img src="https://raw.githubusercontent.com/LahaLuhem/text_sight/main/doc/screenshots/3-one-shot-ios.png" width="240" alt="One-shot recognition on iOS"><br><sub><b>iOS</b> · Apple Vision</sub></td>
  </tr>
</table>

## API at a glance

One import gets you everything: `package:text_sight/text_sight.dart`.

| Type                                    | What it's for                                                |
|-----------------------------------------|--------------------------------------------------------------|
| `TextSightView` + `TextSightController` | the live camera path                                         |
| `TextSight`                             | the static one-shot, on bytes or a file path                 |
| `TextSightOptions`                      | level, languages, region of interest                         |
| `TextSightCapture` and `RecognizedLine` | results: text, normalized box, confidence                    |
| `TextSightModel`                        | Android model readiness, `ensureReady()` plus a stream       |
| `RecognitionLevel`                      | `fast` or `accurate` (iOS)                                   |
| `CameraPermissionStatus`                | granted, denied, permanently denied                          |
| `RecognizedElement`                     | reserved. Always `null` in v1, word-level results come later |

## Platform support

| Platform | Minimum | Engine                                                                            |
|----------|---------|-----------------------------------------------------------------------------------|
| iOS      | 15.0    | Apple Vision. `RecognizeTextRequest` on 18+, `VNRecognizeTextRequest` on 15 to 17 |
| Android  | API 24  | ML Kit Text Recognition v2 (Latin)                                                |

The right Vision API is picked for you. Android reads **Latin script only** for now. *Live* scanning
needs a real device, since the iOS Simulator has no camera, but the one-shot runs anywhere.

### Gotchas

> **⚠️ iOS 15 and 16: the preview and recognition don't follow device rotation.** Those versions
> predate `AVCaptureDevice.RotationCoordinator`, so live capture isn't rotated to match how the
> phone is held. iOS 17+ is fine, and one-shot recognition is fine everywhere (it reads the image's
> own orientation). It's a deliberate trade-off for a device population we don't expect to see. If
> it affects you, [open an issue](https://github.com/LahaLuhem/text_sight/issues) and a proper
> fallback will follow.

<details>
<summary><b>Hosting Flutter inside a native iOS app?</b></summary>

Call `controller.dispose()` a step ahead of releasing the `FlutterEngine` or dismissing its
`FlutterViewController`, not in the same breath. `dispose()` hands the native side a teardown
request and returns before it finishes, so it isn't a barrier. The plugin also releases the camera
on engine detach, which covers the usual routes, but a host that keeps the engine alive forever gets
neither, and a live session that outlives its `FlutterViewController` can crash the app.

Plain Flutter apps need none of this.

</details>

## Install

```sh
flutter pub add text_sight
```

### iOS

Add a camera-usage string to `ios/Runner/Info.plist`. This is **required**, because iOS kills the
app the moment the camera is requested without it.

```xml
<key>NSCameraUsageDescription</key>
<string>Used to recognize text from the camera.</string>
```

Then call `controller.requestCameraPermission()` before `controller.start()`, or
`checkCameraPermission()` if you want a priming screen first.

### Android

Nothing to do. The manifest already has what it needs.

## The recognition model

On iOS there's nothing to do. Vision ships with the OS, so there's no download and no waiting.

Android is the interesting one. The ML Kit model is **unbundled** by default: about 260 KB in your
APK, with the real model pulled from Google Play Services the first time you use it. That's on
purpose, since most apps don't need OCR the second they launch. The catch is that a scan started
before the model lands comes back empty.

### Give it a nudge

Call this when the user opens your scanner:

```dart
final state = await TextSightModel.ensureReady();
if (state is ModelUnavailable) {
  // No Play Services, or the download didn't make it. Tell the user, maybe offer a retry.
}
```

Call it as often as you like. On iOS it returns right away, and on Android it does too once the
model is around.

### Show the download

Want a progress bar? Listen to the readiness stream. It's a sealed type, so the compiler makes sure
you've handled every case:

```dart
TextSightModel.readiness.listen((state) {
  final label = switch (state) {
    ModelReady() => 'Ready to scan',
    ModelDownloading(:final progress) => 'Downloading… ${((progress ?? 0) * 100).round()}%',
    ModelUnavailable(:final reason) => 'Model unavailable ($reason)',
  };
});
```

The [`example/`](example/) scanner does exactly this: `ensureReady()` to gate, the stream for a real
download bar.

### Or just bundle it

Ship the model inside your APK instead. Instant, offline, no Play Services. One line in your app's
`android/gradle.properties`:

```properties
com.lahaluhem.text_sight.useBundled=true
```

Now `ensureReady()` returns immediately and `ModelUnavailable` never shows up. You trade size for
it:

| Mode                  | App size                   | First use           | Offline              | Needs Play Services |
|-----------------------|----------------------------|---------------------|----------------------|---------------------|
| Unbundled *(default)* | ~260 KB                    | downloads on demand | after first download | yes                 |
| Bundled               | ~4 MB per script, per arch | instant             | yes                  | no                  |

## Performance

Captured on a physical Galaxy S24 and iPhone 16 in profile mode. Your hardware will differ, and full
method and numbers are in [`benchmark/`](benchmark/README.md).

### One image

What `TextSight.recognizeImage` costs, by page density. Read the line count beside each bar: a level
that recognizes nothing returns fast, which would otherwise look like a win.

![One-shot recognition latency on device](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/one_shot_latency.png)

On Android the level is a no-op, since ML Kit's Latin recognizer has no accuracy dial, so its two
bars land on top of each other. On iOS `fast` is roughly 4x quicker than `accurate` but skips text
below 1/32 of the image height, so it reads less, then nothing, as pages get denser
([#58](https://github.com/LahaLuhem/text_sight/issues/58)).

### Live camera

Recognized frames per second over a fixed window, both phones pointed at the same page.

| Platform | Level      | Frame     | Captures/s | Paced by       |
|----------|------------|-----------|-----------:|----------------|
| iOS      | `fast`     | 1080x1920 |       30.0 | the camera     |
| iOS      | `accurate` | 1080x1920 |        4.0 | the recognizer |
| Android  | `fast`     | 480x640   |        5.9 | the recognizer |
| Android  | `accurate` | 480x640   |        6.6 | the recognizer |

Hitting the camera's own frame rate means recognition is keeping up and the camera is the limit.
That is where iOS `fast` sits, at 30/s on a 30 fps camera. Everything else is paced by the
recognizer.

**Don't read this as iOS versus Android.** The two sides recognize at different resolutions, so they
are not doing the same work per frame. iOS asks for `.high` and gets 1080p, while Android's analysis falls
through to CameraX's 640x480 default, 6.7x fewer pixels
([#61](https://github.com/LahaLuhem/text_sight/issues/61)). On the same scene Android resolved 11
lines per capture against iOS's 21. These also depend entirely on what the camera sees, so treat
them as directional either way.

### The transport is not the bottleneck

Results cross from native to Dart as a small per-frame map. Decoding one on the UI isolate costs
**microseconds**: worst case on the slower of the two phones, a dense 127-line frame, is 87 µs, or
**0.5% of a 60 fps frame budget**. So the recognizer's own work sets the pace.

![Per-frame decode cost vs frame size](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/decode_vs_lines.png)
![Encoded payload size vs frame size](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/wire_bytes_vs_lines.png)
![Decode cost per realistic OCR profile](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/profile_decode_bars.png)

Those three are host-measured, for the finer sweep a phone run does not produce. Leaner wire formats
win big in *percent* and stay tiny in absolute microseconds, which is why the self-describing map
stays.

## Going deeper

Coordinate handling, the per-line confidence contract, how region-of-interest differs across
platforms, and what's next: all in [APPENDIX.md](APPENDIX.md).
