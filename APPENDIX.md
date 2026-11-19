<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#agentsmd-and-claudemd-are-symlinks-into-ai)
- [Dependabot's PRs auto-merge through dartender, behind the required checks](#dependabot-automerge)
- [`use_primary_constructors` is on, with four narrow opt-outs](#primary-constructors)
- [No-bundling: native dependencies never touch the Dart `pubspec.yaml`](#no-bundling-native-dependencies-never-touch-the-dart-pubspecyaml)
- [Channel topology: Pigeon control API + `EventChannel` results + `Texture` preview](#channel-topology-pigeon-control-api--eventchannel-results--texture-preview)
- [Session state: a value on the controller, pushed by native](#session-state)
- [Coordinate normalization: top-left `[0,1]` in native code](#coordinate-normalization-top-left-01-in-native-code)
- [iOS capture & recognition strategy: roll-your-own AVCapture + Swift Vision](#ios-capture-strategy)
- [Model readiness and the bundled / unbundled axis (Android)](#model-readiness)
- [Federation deferred: one plugin package for v1](#federation-deferred-one-plugin-package-for-v1)
- [Known limitations, performance, and deferred work](#known-limitations)
- [`@TaskQueue` on the control channel: measured, rejected for now](#taskqueue-rejected)
- [Public API funnelled through `lib/text_sight.dart`](#public-api-funnelled-through-libtext_sightdart)
- [Developing the Android module standalone in Android Studio](#android-standalone-dev)

<!-- TOC end -->

Why things are the way they are: design decisions, rejected paths and trade-offs. READMEs,
[`CODESTYLE.md`](./CODESTYLE.md) and [`.ai/AGENTS.md`](./.ai/AGENTS.md) link here by anchor, and the
anchors stay put. `#no-bundling` and `#federation-deferred` are still stubs.

---

<a id="ai-files-symlinked"></a>

## `AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`

- **Decision:** both files live in `.ai/`, and the root holds symlinks to them
  (`AGENTS.md → .ai/AGENTS.md`). A guide for a sub-scope like `example/` would do the same.
- **Why:** agents look for these files at the root, and two more loose Markdown files there clutter
  the tree. The symlinks keep discovery working.
- **The symlinks are gitignored**, so nothing in the build leans on them. Make them locally:

  ```bash
  ln -s .ai/AGENTS.md AGENTS.md
  ln -s .ai/CLAUDE.md CLAUDE.md
  ```

  A real file at the root wins, so that works too.
- **On Windows** without symlink support, a link can turn up as a text file holding its target. Real
  files at the root, synced by hand, are the fallback.
- **`CODESTYLE.md` is a plain root file**, since style serves people as much as agents.

---

<a id="dependabot-automerge"></a>

## Dependabot's PRs auto-merge through dartender, behind the required checks

dartender's `ci.yml` turns on auto-merge (rebase) for every Dependabot PR, majors included, and the
merge waits only on the checks the rulesets require. So:

- **`plugin-ok` has to stay required.** The `dartender` ruleset requires only `ci / ok` and
  `conventions / ok`. Without the repo's own `Protected` ruleset requiring `plugin-ok`, a bump would
  merge without the native, codegen and `benchmark/app` checks.
- **`/android` Gradle bumps reach consumers** through the AAR's POM (ML Kit, Play Services, CameraX)
  but get no changelog line, so check them before a release.
- **Keep `required_signatures` off every ruleset.** GitHub's rebase merges are unsigned, so it would
  block them all.

---

<a id="primary-constructors"></a>

## `use_primary_constructors` is on, with four narrow opt-outs

Dart 3.13 lets a class declare its fields in the constructor header, and the lint pushes every class
that way. It suits the data models, which shed a lot of boilerplate. Two places it bites, and each
carries an `ignore` with its reason.

**The Pigeon schema can't use them.** Pigeon reads message fields out of the class body, and a
primary constructor leaves the body empty:

| In the schema | What Pigeon does with it |
|---|---|
| `enum Foo() { ... }` | refuses it, "Pigeon doesn't support enhanced enums" |
| `class Foo({required var double left});` | emits `class Foo { Foo(); }`, no fields, no error |

The second row is the dangerous one: codegen passes, and every message then crosses the channel
empty. So `pigeons/text_sight.dart` opts out for the whole file. CI's freshness job
([#channel-topology](#channel-topology)) catches a schema committed without its output, but not an
empty class committed with it.

**Namespaces have nothing to construct.** `TextSight`, `TextSightEngine` and `TextSightModel` are
static-only. The lint still offers them a primary constructor, and an empty `()` declares a public
undocumented one, which fails `public_member_api_docs` under CI's `--fatal-infos`. One-line ignore
on each.

`unnecessary_ignore` is on too, so analyze says so the day a Pigeon or SDK release makes any of the
four pointless.

---

<a id="no-bundling"></a>

## No-bundling: native dependencies never touch the Dart `pubspec.yaml`

> _Stub. This is why the package exists._
>
> Will cover: the engines are declared only in platform build files (ML Kit and CameraX in
> `android/build.gradle.kts`, and only system frameworks, `Vision` and `AVFoundation`, on Apple), so
> the Dart `pubspec.yaml` names no recognition library and iOS links **zero** third-party ML. That
> rules out the GoogleMLKit arm64 and SPM warnings that started this package. Also the rejected path
> (`flutter_scalable_ocr` pulling `google_mlkit_text_recognition` in as a Dart dependency, which drags
> GoogleMLKit into the iOS build), why there's no `camera` dependency either, and the check:
> `grep -rEiI 'mlkit|googlemlkit|mlimage' example/ios` finds nothing (grep, since rg skips the
> gitignored SPM manifest, and the SPM example has no `Podfile.lock`). See
> [`CODESTYLE.md#swift-ios`](./CODESTYLE.md#swift-ios),
> [`CODESTYLE.md#kotlin-android`](./CODESTYLE.md#kotlin-android) and the hard rules in
> [`.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules).

---

<a id="camera-permission"></a>

## Camera permission: requested natively, no permission package

**Decision (2026-06-22).** text_sight asks for camera permission itself, through the OS APIs, and
bundles no permission package. `TextSightController` has `checkCameraPermission()` (no prompt) and
`requestCameraPermission()` (the system prompt), both returning
`CameraPermissionStatus { granted, denied, permanentlyDenied }`. `start()` never asks, so the app
picks when the prompt shows.

**Why not bundle `permission_handler`.** The request is free on both platforms
(`AVCaptureDevice.requestAccess`, and `ActivityCompat.requestPermissions` with a
`RequestPermissionsResultListener`), and that's all `permission_handler` wraps. A plugin can call it
directly, as `mobile_scanner` does. Bundling would cost:

- a package in every consumer's dependency tree for what's nearly a yes/no question.
- on iOS, Podfile macros: `permission_handler_apple` gates each permission behind
  `GCC_PREPROCESSOR_DEFINITIONS`, since Apple scans the binary for permission code at submission.
  That's a CocoaPods step forced on every consumer, and a hit on
  [no-bundling](#no-bundling-native-dependencies-never-touch-the-dart-pubspecyaml).

Apps already using `permission_handler` keep working. This adds an option and takes none away.

**What stays the app's job.** The iOS `NSCameraUsageDescription` string, which only the app can
write. Android's `CAMERA` permission ships in the plugin's own manifest and merges in.

**Android needs `ActivityAware`.** A runtime request needs a foreground `Activity`, and a plain
`FlutterPlugin` only gets the application `Context`. So `TextSightPlugin` takes the
`ActivityPluginBinding`, registers the result listener and hands the flow to
`CameraPermissionRequester`. Every approach needs this, `permission_handler` just hides it. Capture
binds to a headless `LifecycleOwner`, so Activity attach and detach never touch a running session.
The permission checks in `initialize()` stay as a second net.

**One status, two platform behaviours underneath.** `denied` means a request may still show the
prompt, `permanentlyDenied` means only system settings can grant it.

- **iOS prompts once.** After that, `requestAccess` returns the stored answer, so a refusal and
  `.restricted` (parental controls, MDM) map to `permanentlyDenied`, and `.notDetermined` to `denied`.
- **Android** tells a re-askable refusal from "don't ask again" with
  `shouldShowRequestPermissionRationale` after the result. A prompt-free check can't, so it reports
  `denied`.

That's the split callers act on: `denied`, ask again, `permanentlyDenied`, send them to settings. The
example does exactly this, and with no `permission_handler` of its own it also proves the
no-bundling claim for permissions.

---

<a id="channel-topology"></a>

## Channel topology: Pigeon control API + `EventChannel` results + `Texture` preview

**Decision.** Each kind of traffic gets the transport that fits its shape:

- **Control and the one-shot → a typed Pigeon `@HostApi`.** `initialize`, `start`,
  `pauseRecognition`, `setOptions`, `setTorchEnabled`, the permission calls and `dispose` are
  request and response, and a generated boundary type-checks both ends. `recognizeImage` and
  `recognizePath` are too, so they ride the same API as `@async` methods returning the same
  self-describing map the live stream sends, which is why the result models need no Pigeon twin.
  Natively they touch no session, texture or sink.
- **Live results → a plain `EventChannel`.** About 30 captures a second fight the
  request-and-response grain of a `@FlutterApi`. An `EventChannel` is Flutter's push stream, and the controller exposes it
  as `Stream<TextSightCapture>`.
- **The preview → a `Texture`.** Native renders into a `FlutterTexture` and hands Dart only its id.
- **Session state and preview geometry → a Pigeon `@FlutterApi`.** Rare and typed. State is one
  sealed message mirroring the public type ([#session-state](#session-state)), and geometry changes
  with the session and device, not with recognition, so neither belongs on the captures.

Squeezing them into one transport means fighting the wrong tool on the hot path. The split also
shows the two drivers: both share the `@HostApi` and the result models, only live needs the stream
and the texture ([#public-api-via-single-export-file](#public-api-via-single-export-file)).

**Pigeon, not the Golubets fork** (chosen 2026-06-17). Pigeon covers everything this schema needs,
and as the Flutter team's tool it's the durable pick for a published package. Golubets' extras
(generics, richer sealed classes, defaults, real async codegen) go unused by a design whose public
types are hand-written. Model readiness confirmed it: its `TextSightReadinessState` is sealed but
hand-written, decoded from a map, so the sealed-class codegen would still sit idle. Golubets' own
page also discourages generated code in a published API and wants both ends on one version
([#model-readiness](#model-readiness)). Reversible, since codegen is dev-time and the output is
committed. Pigeon's `@EventChannelApi` could type the results stream one day, but `Rect` and `Size`
can't cross Pigeon, so the plain channel stays simpler.

**The per-frame wire format is a hand-written, self-describing map.** Each event on
`com.lahaluhem.text_sight/captures` carries `imageWidth` and `imageHeight` (doubles, pixels after
turning), `quarterTurns` (int, deprecated in Dart), and `lines`, each with `text` (String),
`confidence` (double), `left`, `top`, `width` and `height` (normalized, top-left, see
[#coordinate-normalization](#coordinate-normalization)) and `elements` (null for now, reserved so
filling it in is additive). `PigeonTextSightPlatform` decodes it, and **both native sides must emit
exactly this shape.** Keys, not positions, so a new key breaks nothing and frames read in logs.

**Generated code is committed and never hand-edited.** `messages.g.dart` is checked in, so
consumers and CI need no codegen, and it's regenerated, never patched
([hard rule 7](./.ai/AGENTS.md#hard-rules)). Regenerating is `dart run tool/pigeon.dart`, then
`dart format lib/src/platform/messages.g.dart`, since Pigeon emits narrower Dart than the 100-column
format gate wants. Plain `dart run pigeon` stamps its version into the headers and fails the
codegen check.

**`copyWith` is generated too, for one runtime dependency.** A hand-written `copyWith` compiles
while missing a field added later, and no test catches a field nobody wrote down.
`copy_with_extension_gen` derives it from the fields, so that drift can't happen. The generator and
`build_runner` are dev-only, but the `copy_with_extension` annotation ships with the source, so it's
a runtime dependency. It only needs `meta`, which was already here, so consumers gain one package.
The pure-Dart route was tried first: an all-required private constructor makes the drift a compile
error, but `const DarwinOptions._(...)` fails `unnecessary_type_name_in_constructor` (fatal in CI),
and the `._(...)` form the lint wants doesn't parse on Dart 3.13. It would have meant a permanent
suppression.

**CI regenerates and diffs.** The `codegen` job runs both generators, then
`git add --intent-to-add .` and `git diff --exit-code`, so a brand-new generated file counts as
stale too. The format pass is mechanical, not a hand-edit, so the freshness check runs it before
comparing.

---

<a id="session-state"></a>

## Session state: a value on the controller, pushed by native

**Decision.** The session's state is a sealed `TextSightSessionState` on the controller, pushed by
native over a Pigeon `@FlutterApi` and deduped once in Dart. The plugin pauses and resumes the
session on its own, and the OS interrupts, revokes and fails cameras, and nothing used to carry
that back.

**A value, not events.** A broadcast `EventChannel` replays nothing, so a late listener would learn
nothing until the next change. The controller folds the pushes into `sessionState`, subscribing on
its first `start()` before `initialize`, so it misses nothing of its own session. Construction stays
platform-free, so consumer tests that only construct one keep working.

**A `@FlutterApi`, not the captures channel.** Tagging every frame for a signal that fires a few
times a session taxed the hot path and meant re-contracting the wire on three ends. The FlutterApi
leaves the frame wire as it was and types the state through codegen. The message is sealed rather
than flat, which costs some generated lines per end, nothing hand-written, and makes invalid
combinations unrepresentable.

**Ordering.** Frames and states reach main in emission order, and the engine keeps that order on the
way to Dart (engine behaviour, not a contract). Android emits on main. iOS starts each push on
swift-async-queue's `MainActor.queue`, which keeps the order without waiting for Dart's reply.
Causal order isn't promised: a recognition in flight can land after a pause.

| State                     | iOS                                                 | Android                                                                                                 |
|---------------------------|-----------------------------------------------------|---------------------------------------------------------------------------------------------------------|
| active                    | `startRunning` succeeded                            | `CameraState.OPEN`                                                                                      |
| paused, `appBackgrounded` | the sync stopped the session for the background     | the owner reached `CREATED`, where CameraX closes the camera. `onPause` without `onStop` is not a pause |
| paused, `interrupted`     | `wasInterrupted`, any reason but the background one | a recoverable `CameraState` error, or `PENDING_OPEN`                                                    |
| failed                    | `runtimeError`                                      | a critical `CameraState` error                                                                          |
| idle                      | a real session released                             | a bound camera released                                                                                 |

**Failure parks the session, and `start()` unparks it.** iOS keeps `hasFailed` in its policy
(`shouldRun = wanted && foreground && !failed`), and Android parks the lifecycle owner. Neither
retries on its own.

**The recognition gate stays.** Both sides skip recognition while nothing listens to `captures`.
`pauseRecognition()` is the explicit verb for a listener that wants no work.

**Android's camera state goes blind while capped.** `LiveData` observed through the owner delivers
nothing at `CREATED` and only the latest value on return (unit-tested), so the cap reports the pause
and the camera's own `OPEN` reports the return.

**Deferred.** A native pull for the current state, a typed reason on `SessionFailed`, a `stop()` that
releases the camera, bounded self-healing after `mediaServicesWereReset`, state handling in
`TextSightView`, native dedupe, and diagnostics as more `@FlutterApi` methods.

---

<a id="coordinate-normalization"></a>

## Coordinate normalization: top-left `[0,1]` in native code

**Decision.** Native code turns every box into `[0,1]` from the top-left before it crosses the
channel, so the Dart painter never branches on platform. The three sides disagree:

- **Vision** reports `[0,1]` from the bottom-left, so Swift flips Y.
- **ML Kit** reports pixels in the turned image, so Kotlin divides by its upright size.
- **Flutter** wants `[0,1]` from the top-left, so the painter only scales by the overlay's size.

**`TextSightCapture.imageSize`** is the analyzed image's pixel size, in the boxes' orientation. Only
a consumer drawing over its own image needs it. `TextSightView`'s overlay already is the frame.

**The preview texture is the one thing not turned natively.** That would cost a pass per frame,
where Flutter turns and fits it in the draw it makes anyway. So native reports only the upright
size and the quarter turns, through `onPreviewChanged` ([#channel-topology](#channel-topology)),
which keeps the preview right before the first capture and while recognition is paused.

| Surface | Turns |
|---|---|
| iOS, Android's ImageReader `SurfaceProducer` (API 29+) | `sensor - display`. iOS reads it off `AVCaptureDevice.RotationCoordinator` |
| Android's SurfaceTexture one (below API 29, Huawei at 29) | `0 - display`. It applies the sensor's turn itself (`handlesCropAndRotation()`) |

`TextSightView` turns the texture, fits it (`contain` by default, centred) and gives the overlay the
same rectangle, so boxes line up with no platform branch in Dart.

Recognition turns on its own. Android keeps `ImageAnalysis.targetRotation` on the display through a
`DisplayManager.DisplayListener`, since a headless session gets no orientation updates, and iOS
hands Vision the `RotationCoordinator`'s orientation. Stills are read in their EXIF orientation, so
the one-shot reports no turn.

**The ROI lives in the same space**, as a normalized `Rect`, not pixels. `TextSightOptions` is
`const` and can't check its own range, so a debug `assert` at the controller does.

Every path reads the box plus half its height above and below. One `FrameRegion` per platform
decides what the engine reads, which lines count and how each box gets back onto the frame, so the
paths can't drift apart:

| Path                   | What limits the read                                                    | Why boxes need moving back                        |
|------------------------|-------------------------------------------------------------------------|---------------------------------------------------|
| iOS, live and one-shot | The request's `regionOfInterest`, flipped to Vision's bottom-left space | Vision measures each box from the region's corner |
| Android one-shot       | A crop of the bitmap as stored, with its EXIF turn handed to ML Kit     | ML Kit measures from the crop's corner            |
| Android live           | libyuv cuts the read out of the YUV planes into an NV21 buffer          | Same                                              |

**Why the read reaches past the box.** Cut a line along its length and the engines return fragments
or nothing, depending on the depth, so edge lines flicker as the hand drifts, and no rule on box
position tells those fragments from good lines. Read past the edge and a line centred inside comes
back whole. The sides still cut, since lines run on past them anyway. Live, a line already on screen
holds a little past the edge, since boxes shift a few pixels between reads. On an iPhone the taller
read costs `accurate` a little small text at 1080p and helps it at 4K
([#3](https://github.com/LahaLuhem/text_sight/issues/3) has the numbers). Vision measures its
text-height floor against the region it reads, so the floor is divided by that height on the way in.

**Why the Android live crop goes through libyuv.** ML Kit takes no region and ignores
`Image.cropRect`, so the only way to read less is a smaller buffer. libyuv-android copies the read
out of planar, NV21 and NV12 memory with no loops of ours, faster than a hand-written copy, at the
cost of a native library in every install
([#3](https://github.com/LahaLuhem/text_sight/issues/3) has sizes and timings).

**Keep the crop in libyuv-android's native `Nv21Buffer`.** ML Kit's NV21 `fromByteBuffer` reads a
buffer's backing array from index 0 and ignores `arrayOffset()`. On Android,
`ByteBuffer.allocateDirect` is array-backed with a non-zero offset, so swapping it in makes ML Kit
read a shifted image and quietly return fewer lines.

**Orientation is an input.** Get it wrong and recognition quietly gets worse, so iOS passes the
right `CGImagePropertyOrientation` and Android the `ImageProxy`'s `rotationDegrees`.

---

<a id="ios-capture-strategy"></a>

## iOS capture & recognition strategy: roll-your-own AVCapture + Swift Vision

**Decision.** iOS live runs its own `AVCaptureSession` and Vision into a `FlutterTexture`, mirroring
Android's `TextSightCamera`. The recognizer is Vision's Swift `RecognizeTextRequest` (WWDC 2024),
with the legacy `VNRecognizeTextRequest` for iOS 15 to 17. The floor is iOS 15 (`Package.swift`),
and a macOS target would sit at 15 for the same API.

**Why not `DataScannerViewController`.** VisionKit's scanner is turnkey, but it owns its own preview
and overlay and can't render into a `FlutterTexture`. iOS would need a platform view while Android
draws to a `Texture`, and the shared contract (the captures channel, `overlayBuilder`, the normalized
ROI, per-line confidence) wouldn't survive. Android has no turnkey live-text scanner to pair it with
either: Google's are the Code Scanner (barcodes) and the Document Scanner (a capture flow returning an
image or PDF). So a turnkey route would fit worse and split the platforms. Our own keeps one
architecture, and a future macOS target shares it, since Vision is the same there.

**Why the Swift request.** It's where Apple points new code (async, `Sendable`, value types), the
same vendor-forward posture as CameraX and ML Kit v2 on Android. It runs the same text engine as the
legacy request, so it's an ergonomics pick, not an accuracy one. The defaults differ, though: the
modern request ships a text-height floor and the legacy one doesn't, so one photo read on iOS 17 and
came back empty on 18. Both now set every knob instead of inheriting any.

**The hybrid for iOS 15 to 17 (issue #5).** The floor went from 13 to 15 once Flutter 3.47 made 15
its own minimum. A `TextRecognizer` protocol has two backends, `ModernTextRecognizer`
(`@available(iOS 18, *)`) and `LegacyTextRecognizer` (not deprecated), and
`TextRecognizerFactory.make()` is the one `#available` check, made once at `TextSightCamera` init,
off the per-frame path. Both emit the same neutral `RecognizedLineData` through one `FrameRegion`
([#coordinate-normalization](#coordinate-normalization)), so only building the request differs.
iOS 18 pays nothing for it. The legacy `perform` is synchronous, so it runs on its own serial queue
behind a continuation and never blocks the cooperative pool.

**Rotation below iOS 17 isn't tracked (option C).** Going below 18 also exposed
`AVCaptureDevice.RotationCoordinator` (iOS 17+) in capture, not only in the recognizer. A second,
pre-17 rotation pipeline for a vanishing slice of devices wasn't worth it, so the coordinator is
gated to iOS 17 and on 15 and 16 the live preview doesn't follow rotation (`currentRotationAngle`
stays 0). Recognition still works, and the one-shot reads EXIF anyway. The full pre-17 path
(option A) waits for real reports from 15 and 16 users, and the [README](./README.md) says so.

---

<a id="model-readiness"></a>

## Model readiness and the bundled / unbundled axis (Android)

**Decision (2026-06-22).** The model loads lazily under the app's control, never at startup, and
bundling it is a build-time choice. Two separate axes:

- **Runtime: `TextSightModel.ensureReady()` and `TextSightModel.readiness`.** Both drivers use the
  same model, so the API sits on its own namespace. `ensureReady()` resolves to `ModelReady` or
  `ModelUnavailable`, and `readiness` streams `ModelDownloading(progress)` in between. The app calls
  it when entering an OCR feature, so loading never blocks launch.
- **Build time: the `com.lahaluhem.text_sight.useBundled` Gradle flag.** Unbundled by default (a few
  hundred KB per script, fetched through Play Services), or bundled into the APK (megabytes per
  script and architecture, instant and offline). ML Kit's Kotlin API is the same for both, so the
  flag only swaps a dependency in `android/build.gradle.kts`.

**Why two axes.** Bundling is a packaging call the app makes once, at build time, the only place an
Android dependency swap can live, so it's a `gradle.properties` flag (`mobile_scanner`'s mechanism,
inverted since our default is unbundled, and only the mechanism: the Dart API is our own).
Readiness is a runtime thing per session. They touch: bundled, `ensureReady()` resolves at once,
unbundled, it may download. Kotlin reads which from `BuildConfig.USE_BUNDLED`.

**Why lazy, with no install-time prefetch.** The unbundled model can arrive through a
`com.google.mlkit.vision.DEPENDENCIES` manifest entry at install, an explicit `ModuleInstallClient`
download, or on first use. The plugin's manifest leaves the entry out, since it merges into every
consumer and would download the model at install for apps that never use OCR. So it's
first-use, with `ensureReady()` (`areModulesAvailable`, then `installModules` with an
`InstallStatusListener` for progress) as the app's trigger. An app wanting prefetch adds the entry to
its own manifest.

**Failure is a state, not a throw.** The unbundled model needs Play Services, missing on GMS-less
devices, and a download can fail. Both arrive as `ModelUnavailable` with a typed `reason`
(`playServicesUnavailable`, `downloadFailed`) for the app to render
([hard rule 11](.ai/AGENTS.md#hard-rules)). On iOS, Vision ships with the OS, so readiness is always
`ModelReady` and `ensureReady()` returns at once.

**Transport reuses the split** ([#channel-topology](#channel-topology)). `ensureModelReady()` is one
`@async` Pigeon method returning the final state, and `readiness` is a plain `EventChannel`
(`com.lahaluhem.text_sight/readiness`) of maps, decoded by hand into the sealed type the way captures
are. The sealed type is hand-written, which is why it didn't push the package onto Golubets.

**No-bundling holds.** That rule ([#no-bundling](#no-bundling)) is about the Apple build. Bundled or
not, ML Kit is declared only in `android/build.gradle.kts` and never reaches the Dart `pubspec.yaml`.

---

<a id="federation-deferred"></a>

## Federation deferred: one plugin package for v1

> *Stub, written if federation comes back up.*
>
> Will cover why v1 is one package for all platforms, not a federated set
> (`text_sight_platform_interface` plus per-platform packages). Federation pays off only when third
> parties add platforms or each platform needs its own versions, and neither applies.
> `plugin_platform_interface` is already a dependency, so the boundary can be drawn later without a
> restructure.

---

<a id="known-limitations"></a>

## Known limitations, performance, and deferred work

The backlog lives in [GitHub issues](https://github.com/LahaLuhem/text_sight/issues). This keeps
the lasting rationale that isn't a backlog item.

**The platforms differ, and that's not a bug.** Everything under `TextSightOptions.darwin` is Vision
only: ML Kit's Latin recognizer has no accuracy dial, language correction, language choice or
text-height floor. The group says so in the API rather than in a dartdoc nobody reads. Both report
per-line confidence, on scales that don't compare.

**The platforms capture different shapes.** Android runs 4:3, the sensor's own shape. iOS has no 4:3
HD preset, so it runs 16:9. Matching them would crop page away for nothing. `CaptureResolution` picks
the size, and the shape stays the platform's.

**Both engines shrink a big frame before reading it**, so past a point more pixels buy no finer
print. Measured in November 2026 with rows of known font sizes drawn into frames of many shapes
([#3](https://github.com/LahaLuhem/text_sight/issues/3) has the method and the rest of the numbers):

| Engine, where measured | Shrinks the frame to | Smallest font size read in a frame that fits |
|---|---|---|
| ML Kit unbundled 19.0.2 and bundled 16.0.1, Galaxy S24 and an API 37 emulator | A long side of about 2,400 px, whatever the pixel count | 8.5 px |
| Vision `fast`, iPhone 16 on iOS 27.2 and the iOS 26.2 Simulator | A short side of about 1,900 px | 12.5 to 16 px |
| Vision `accurate`, iPhone 16 on iOS 27.2 | About 1080p, for camera-shaped frames | 11 px |

- **A box is read at its own size.** Android crops, and Vision's `regionOfInterest` reads exactly
  like a crop, so a box keeps the detail a big frame loses. That makes small print the box's job
  live, and puts Android's `high` just past ML Kit's size.
- **The simulator's `accurate` isn't the iPhone's:** it reads finer, jumps with a few px of shift and
  runs several times slower. Judge `accurate` on a phone.
- **Both engines can return nothing at all** for a frame whose text sits near their floor.
- **Reading big images in pieces** is [#137](https://github.com/LahaLuhem/text_sight/issues/137).

**The live session pauses itself in the background** and restarts on return with the torch put
back, and `sessionState` reports it ([#session-state](#session-state)). Both OSes cut a backgrounded
app's camera anyway, so leaning on that meant OS-owned recovery timing and a torch silently left off.
Android derives the headless owner's state from `ProcessLifecycleOwner`, capped by the session's
intent, and iOS stops and starts the `AVCaptureSession` on its queue from the background and
foreground notifications.

**Federation is deferred, and likely never needed** ([#federation-deferred](#federation-deferred)).
It isn't an issue, so it comes back only if third parties start adding platforms.

---

<a id="taskqueue-rejected"></a>

## `@TaskQueue` on the control channel: measured, rejected for now

`@TaskQueue(type: TaskQueueType.serialBackgroundThread)` moves a host method's decode off the
platform thread, which tempts for `recognizeImage`, the one control method with a real payload. It
was measured on both platforms and **not kept**: it helps Android, clearly hurts iOS, and the
annotation is per method with no per-platform form.

`benchmark/app/integration_test/platform_thread_bench_test.dart` pings the synchronous
`checkCameraPermission` while 40 undecodable 8 MiB payloads cross the channel, so it times the hop,
not inference. Read `p50` only, since `max` swings 2.4x run to run.

Criterion, set before the after-run: loaded `p50` at or under 300 us in two of three runs.

| Platform         | baseline loaded `p50`                | with `@TaskQueue`                          |
|------------------|--------------------------------------|--------------------------------------------|
| Android emulator | 524 / 669 / 459 us                   | **216 / 233 / 319 us**                     |
| iOS simulator    | 110 / 104 / 113 / 124 / 116 / 115 us | **33 / 95 / 2295 / 2483 / 2553 / 2632 us** |

Android's ranges don't overlap. iOS goes from tight to bimodal, four of six runs about 20x worse, and
six runs a side because the first iOS run (33 us) looked like a win and wasn't. Why iOS degrades is
unconfirmed, possibly contention on the queue `makeBackgroundTaskQueue` returns.

**What would change the answer.** Per-platform annotations, a different payload profile (the effect
is payload-driven, so `recognizePath` and `ensureModelReady` were never candidates), real hardware,
or an upstream fix on iOS. `initialize` and `dispose` stay out regardless, since the texture registry
and CameraX `LiveData` reject non-main threads.

---

<a id="public-api-via-single-export-file"></a>

## Public API funnelled through `lib/text_sight.dart`

**Decision.** Consumers import only `lib/text_sight.dart`, which holds `export 'src/…';` lines and
nothing else. Dart has no hard private boundary below `lib/`, so this is how a package says "the
rest is private", and it leaves one file to audit before a release. Moving code inside `lib/src/` is
free. Adding to the exports is a minor, removing or changing one a major. Prefer `show` over `hide`
for a partial export.

**Layering.** Both drivers go through one federation seam:

```text
PUBLIC   the barrel: both drivers, the view, the result models and options
   │
SEAM     TextSightPlatform extends PlatformInterface   (the federation boundary, one impl for now)
   │
IMPL     codegen @HostApi + @FlutterApi  +  EventChannel  +  TextureRegistry
```

The seam is there before federation is ([#federation-deferred](#federation-deferred)), so splitting
out a `text_sight_platform_interface` later is mechanical rather than a rewrite.

**Module layout.** One recognizer, two drivers, and the folders say so: `recognition/` holds the
capture-agnostic models and config, `capture/` both drivers (live `TextSightController`, one-shot
`TextSight`) and their session types, `view/` the widget, and `platform/` the seam with its
Pigeon implementation. Each public type gets its own file
([`CODESTYLE.md#naming`](./CODESTYLE.md#naming)).

**Result-model contracts.**

- **`RecognizedLine.confidence` is a `double` in `[0,1]`, never null**, since both engines give a
  per-line value (ML Kit v2 through `Text.Line.getConfidence()`). The scales don't compare, across
  platforms or iOS versions. The modern `RecognizeTextRequest` (18+) is **coarse**, often `1.0`, and
  the legacy `VNRecognizeTextRequest` (15-17) is **graded**: the same image scored about `0.5` on
  iOS 15 for lines the 18+ path scored `1.0` (on a device). On the modern path the value follows
  `recognitionLevel`, not the text: the bundled sample read `0.5` throughout at `fast` and `1.0` at
  `accurate` (iOS 26.2 Simulator). So `accurate` buys a different constant, not gradation.
  `TextSightEngine.confidenceScale` says which scale you have, and `isRankable` answers the question
  most consumers have.

  Unbundled ML Kit below Google Play services 22.30 reports `0` for every line. There's no runtime
  gate for it: those devices are years stale and shrinking, and a nullable field to model them would
  tax every consumer. If it ever matters, it becomes a `ConfidenceScale` value, not a per-line null.
- **`RecognizedLine.elements` is a reserved `List<RecognizedElement>?`**, `null` until word-level
  elements ship, so filling them in later is a minor. `RecognizedElement` is `text`, `boundingBox`
  and a nullable `confidence`, since whether both engines give per-word values is still open.
- **Both result types are immutable and `const`-constructible.** They hold their lists without a
  defensive copy, since a `const` instance gets a `const` list
  ([`CODESTYLE.md`](./CODESTYLE.md#listunmodifiable-over-unmodifiablelistview)).

**Configuration.**

- **`TextSightOptions` is the one recognizer config for both drivers**: `roi` plus a `darwin` group.
  The live driver takes it on the controller, the one-shot per call, where it raises the level to
  `accurate`.
- **`DarwinOptions` holds what only Vision can do**, so the platform is named once and a new Vision
  knob doesn't touch `TextSightOptions`. `preferredLanguages` is an `Iterable<Locale>`, since what's
  supported depends on platform and OS version, so a closed enum would misstate it. It maps to tags
  through `Locale.toLanguageTag()` at the seam. `minimumTextHeight` is a fraction of the **frame**,
  divided on the way in by the height of the region Vision reads, so it stays the same text size
  whatever the box.
- **The torch isn't in `TextSightOptions`.** It's a live-session thing and a still has none, so the
  type keeps recognizer config (shared) apart from session config (live only).
- **`roi` is a `Rect`**, the same type as the output boxes rather than a twin
  ([#coordinate-normalization](#coordinate-normalization)).

**The one-shot is its own driver, not a session mode.** `TextSight.recognizeImage` and
`.recognizePath` return a `Future<TextSightCapture>` with no controller, permission, texture or
session. They share only the recognizer and result models with the live path, over the `@HostApi`
([#channel-topology](#channel-topology)).

---

<a id="android-standalone-dev"></a>

## Developing the Android module standalone in Android Studio

**Decision.** `android/` carries a little scaffolding so it opens on its own in Android Studio
(`File > Open > android/`) with everything resolving, `io.flutter.*` included. Flutter's plugin
template doesn't do this: its `android/` only resolves inside an app build. The additions:

- **`android/settings.gradle.kts`**: a `pluginManagement {}` block pinning AGP, so
  `id("com.android.library")` resolves with `android/` as the Gradle root. No Kotlin plugin, since
  standalone uses AGP 9's built-in Kotlin.
- **`android/gradle.properties`**: `useAndroidX` and JVM args, with no `newDsl` or `builtInKotlin`
  opt-outs.
- **`android/build.gradle.kts`**: an `if (project == rootProject)` block adding the Flutter engine
  embedding (`io.flutter:flutter_embedding_debug:1.0.0-<engine.version>`) as `compileOnly` and
  `testImplementation`, versioned from the pinned SDK so it follows the channel. `compileOnly` only
  covers main sources, so without the second the unit tests can't resolve `io.flutter.*`.
- the **Gradle wrapper** (`gradlew`, `gradle/wrapper/`).

**Why Flutter doesn't.** Flutter only builds a plugin's `android/` as a subproject of an app, which
supplies AGP and Kotlin, and only apps apply `dev.flutter.flutter-gradle-plugin`, which injects the
engine. So the supported way to work on plugin native code is `example/android`. Standalone, nothing
provides `io.flutter`, and making it resolve ties the build to an engine version, which Flutter
won't bake into every generated plugin.

**Why consumers never see it.** Each addition only applies with `android/` as the root: an app build
ignores a subproject's `settings.gradle.kts` and root `gradle.properties`, and the engine block is
guarded by `project == rootProject`. It's all [`.pubignore`](./.pubignore)d too. Both paths compile
`lib` and the unit tests: in-app through `example/android`, and standalone.

**The wrapper is committed** (it pins Gradle, see the `!/gradle/wrapper/gradle-wrapper.jar`
un-ignore in `android/.gitignore`) but `.pubignore`d, so standalone builds need no setup and the
tarball stays lean. `android/local.properties` (gitignored) has to set `flutter.sdk` for the engine
to resolve standalone, and the build logs a hint when it's missing.

**AGP 9's built-in Kotlin, standalone only.** No `org.jetbrains.kotlin.android` plugin, no opt-out
flags and no `sourceSets` block (AGP 9 includes `src/main/kotlin` and `src/test/kotlin` itself), which
clears AGP 9's deprecation warnings in the standalone window. The example can't follow: Flutter's
`flutter build` migrator re-adds `android.builtInKotlin=false` and `android.newDsl=false` to
`example/android/gradle.properties` on every build, so the in-app build stays on legacy AGP until
Flutter migrates. The shared `build.gradle.kts` works both ways. One catch of the new DSL:
`junit-platform-launcher` has to be declared on the test runtime classpath for
`useJUnitPlatform()`, which the legacy DSL supplied.

**`compileSdk` is the latest stable, never a preview.** AGP records a library's `compileSdk` as the
AAR's `minCompileSdk`, so every consumer must compile against at least that, and since pub.dev ships
the plugin as source, a higher level also needs that SDK installed, breaking stock Flutter apps. AGP
9.2 and up enforces it (9.0 didn't, which is how the example once built). The vendor-forward
instinct governs the plugin's own floor (`minSdk`), not what it forces on apps. CameraX and ML Kit
need nothing past stable.

**No configuration cache yet.** Two upstream issues seen on AGP 9.2.1 and Gradle 9.6.0: AGP's own
`VariantDependenciesBuilder` raises the *"Project object as a dependency notation"* Gradle 10
deprecation (harmless until Gradle 10), and its `JdkImageInput` isn't configuration-cache-safe, so a
strict cached build fails storing the entry. Both are AGP's to fix, so check again on the next AGP
bump.

**Cost and fallback.** The scaffolding tracks the engine version (automatically) and adds a few
`.pubignore`d files, for a lean plugin-only IDE window. If it ever drags, delete it and open
`example/android`.
