[![Package checks](https://github.com/LahaLuhem/text_sight/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/text_sight/actions/workflows/package.yml)
[![Pub Version](https://img.shields.io/pub/v/text_sight.svg)](https://pub.dev/packages/text_sight)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/LahaLuhem/text_sight/pulls) [![Pub Package](https://img.shields.io/pub/v/text_sight.svg)](https://pub.dev/packages/text_sight)
[![Pub Points](https://img.shields.io/pub/points/text_sight?logo=dart)](https://pub.dev/packages/text_sight/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/LahaLuhem/text_sight.svg)](https://github.com/LahaLuhem/text_sight/issues) [![GitHub closed issues](https://img.shields.io/github/issues-closed/LahaLuhem/text_sight.svg)](https://github.com/LahaLuhem/text_sight/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/LahaLuhem/text_sight.svg)](https://github.com/LahaLuhem/text_sight/pulls) [![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed/LahaLuhem/text_sight.svg)](https://github.com/LahaLuhem/text_sight/pulls?q=is%3Apr+is%3Aclosed)

**Live, on-device text recognition for Flutter** — Apple Vision on iOS, ML Kit on Android. Like
[`mobile_scanner`](https://pub.dev/packages/mobile_scanner), but for text instead of barcodes.

<p align="center">
  <img src="https://raw.githubusercontent.com/LahaLuhem/text_sight/main/doc/screenshots/1-live-ocr.webp" width="260" alt="Live text recognition — confidence-coloured boxes over the camera feed">
</p>

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Why text_sight?](#why-text_sight)
- [A quick taste](#a-quick-taste)
- [Platform support](#platform-support)
- [Install](#install)
- [The recognition model](#the-recognition-model)
- [Performance](#performance)
- [Going deeper](#going-deeper)

<!-- TOC end -->

## Why text_sight?

Most cross-platform OCR plugins run Google ML Kit on *both* platforms. That quietly pulls
`GoogleMLKit` into your iOS build — and with it the arm64 and Swift Package Manager warnings
that have been nagging Flutter iOS builds for a while.

text_sight takes the other road. On iOS it uses **Apple Vision**, a system framework, so your app
links **zero third-party ML libraries** there — no GoogleMLKit, no warnings. Android keeps ML Kit,
declared only in its own Gradle file. Nothing recognition-related ever reaches your `pubspec.yaml`,
so the two platforms can't bleed into each other. Clean, native text scanning on both. That's the
whole idea.

## A quick taste

Point the camera at some text:

```dart
final controller = TextSightController();

TextSightView(
controller: controller,
onResult: (capture) => capture.lines.forEach((line) => print(line.text)),
overlayBuilder: (context, capture, constraints) => /* paint line.boundingBox */,
);

await controller.start(); // after the camera permission is granted
```

Or read a single still — no camera, no permission:

```dart
final capture = await TextSight.recognizeImage(bytes); // or .recognizePath('/photo.jpg')
```

Either way, boxes come back normalized `[0, 1]` from the top-left, identical on both platforms, so
your overlay never has to know which engine drew them.

Want a scan-box? Hand the controller a **region of interest** —
`TextSightController(options: TextSightOptions(roi: Rect.fromLTWH(0.1, 0.4, 0.8, 0.2)))` — or change
it, the recognition level, or the torch while the session runs. It applies to the live preview and
the one-shot alike.

One Android thing worth knowing up front: the model downloads on first use, so
[give it a head start](#the-recognition-model) when the user opens your scanner — otherwise that first
scan comes back empty.

The [`example/`](example/) app is where to look next — a live overlay, torch, region-of-interest,
permission handling, and the one-shot screen, all wired up and ready to crib from.

<table>
  <tr>
    <td align="center"><img src="https://raw.githubusercontent.com/LahaLuhem/text_sight/main/doc/screenshots/2-one-shot-android.png" width="240" alt="One-shot recognition on Android"><br><sub><b>Android</b> · ML Kit</sub></td>
    <td align="center"><img src="https://raw.githubusercontent.com/LahaLuhem/text_sight/main/doc/screenshots/3-one-shot-ios.png" width="240" alt="One-shot recognition on iOS"><br><sub><b>iOS</b> · Apple Vision</sub></td>
  </tr>
</table>

## Platform support

| Platform | Minimum | Engine                                  |
|----------|---------|-----------------------------------------|
| iOS      | 18.0    | Apple Vision — `RecognizeTextRequest`   |
| Android  | API 24  | ML Kit Text Recognition v2 (Latin)      |

A few things worth knowing before you start: iOS needs **18.0+** (older versions are on the
roadmap), Android recognizes **Latin script only** for now, and *live* scanning needs a real
device — the iOS Simulator has no camera. The one-shot runs anywhere.

## Install

```sh
flutter pub add text_sight
```

On iOS, add a camera-usage string to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to recognize text from the camera.</string>
```

text_sight won't request camera permission for you — ask for it (e.g. with
[`permission_handler`](https://pub.dev/packages/permission_handler)), then call
`controller.start()`. Android's manifest already has what it needs.

## The recognition model

On iOS there's nothing to see here — recognition is Apple Vision, a system framework that's always
on hand. No download, no waiting.

Android is the interesting one. The ML Kit model ships **unbundled** by default: it's a tiny ~260 KB
and gets pulled from Google Play Services the first time you actually use it. We don't grab it at
install time on purpose — most apps don't need OCR the second they launch, so there's no point making
everyone pay for it up front. The one catch: a scan you kick off before the model has landed comes
back empty.

So give it a nudge when the user wanders into your scanner:

```dart
final state = await TextSightModel.ensureReady();
if (state is ModelUnavailable) {
  // No Play Services, or the download didn't make it. Tell the user, maybe offer a retry.
}
```

Call it as often as you like — it returns right away once the model's around (which is always, on
iOS). Want a progress bar in front of the user while it downloads? Listen to the readiness stream and
switch over it. It's a sealed type, so the compiler makes sure you've handled every case:

```dart
TextSightModel.readiness.listen((state) {
  final label = switch (state) {
    ModelReady() => 'Ready to scan',
    ModelDownloading(:final progress) => 'Downloading… ${((progress ?? 0) * 100).round()}%',
    ModelUnavailable(:final reason) => 'Model unavailable ($reason)',
  };
  // ...show `label`, or feed `progress` straight into a progress indicator
});
```

The [`example/`](example/) live scanner does exactly this — `ensureReady()` to gate, the stream for a
real download bar.

### Or just bundle it

Don't fancy any of that? Ship the model inside your APK — instant, offline, Play Services out of the
picture. One line in your app's `android/gradle.properties`:

```properties
com.lahaluhem.text_sight.useBundled=true
```

Now `ensureReady()` returns immediately and `ModelUnavailable` never shows up. You're trading size
for it, mind:

| Mode                  | App size          | First use           | Offline              | Needs Play Services |
|-----------------------|-------------------|---------------------|----------------------|---------------------|
| Unbundled *(default)* | ~260 KB           | downloads on demand | after first download | yes                 |
| Bundled               | ~4 MB/script/arch | instant             | yes                  | no                  |

## Performance

Recognition results cross from native to Dart as a small per-frame map over an `EventChannel`.
Decoding it on the UI isolate costs **microseconds** — even a dense ~127-line frame is ~55 µs, well
under 1% of a 60 fps budget. The native engine's inference, not the transport, sets the pace.

![Per-frame decode cost vs frame size](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/decode_vs_lines.png)
![Encoded payload size vs frame size](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/wire_bytes_vs_lines.png)
![Decode cost per realistic OCR profile](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/profile_decode_bars.png)

These measure the pure-Dart codec only — not native inference or end-to-end latency, which dominate.
Leaner transports (`list`, Pigeon, packed-binary) win big in *percent* but stay tiny in absolute µs,
so the self-describing `Map` stays. Full methodology and numbers: [`benchmark/`](benchmark/README.md).

## Going deeper

How it all fits together — coordinate handling, the per-line confidence contract, how
region-of-interest differs across platforms, and what's next — lives in [APPENDIX.md](APPENDIX.md).
