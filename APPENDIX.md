<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#agentsmd-and-claudemd-are-symlinks-into-ai)
- [No-bundling: native dependencies never touch the Dart `pubspec.yaml`](#no-bundling-native-dependencies-never-touch-the-dart-pubspecyaml)
- [Channel topology: Pigeon control API + `EventChannel` results + `Texture` preview](#channel-topology-pigeon-control-api--eventchannel-results--texture-preview)
- [Coordinate normalization: top-left `[0,1]` in native code](#coordinate-normalization-top-left-01-in-native-code)
- [iOS capture & recognition strategy: roll-your-own AVCapture + Swift Vision](#ios-capture-strategy)
- [Federation deferred: one plugin package for v1](#federation-deferred-one-plugin-package-for-v1)
- [Known limitations, performance, and deferred work](#known-limitations)
- [Public API funnelled through `lib/text_sight.dart`](#public-api-funnelled-through-libtext_sightdart)

<!-- TOC end -->

Consolidated source of truth for design decisions, rejected paths, and non-obvious
technical trade-offs.

READMEs, [`CODESTYLE.md`](./CODESTYLE.md), and [`.ai/AGENTS.md`](./.ai/AGENTS.md)
reference sections here by anchor (e.g. `APPENDIX.md#no-bundling`).

> **Status:** the symlink, channel-topology, coordinate-normalization, iOS-capture-strategy,
> known-limitations, and public-API sections are written. `#no-bundling` and `#federation-deferred`
> stay stubs — locked decisions whose rationale is filled in when the corresponding code lands.
> Anchors are stable; only stub bodies grow.

---

<a id="ai-files-symlinked"></a>
## `AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`

- **Decision:** the canonical text for both files lives under `.ai/`. The repo root holds
  symlinks (`AGENTS.md → .ai/AGENTS.md`, `CLAUDE.md → .ai/CLAUDE.md`). A sub-scope guide
  (e.g. `example/`) would follow the same pattern (`example/AGENTS.md →
  example/.ai/AGENTS.md`) if one is ever added.
- **Why:** Claude Code (and most other coding agents) auto-discover `CLAUDE.md` /
  `AGENTS.md` at the project root, but two more loose Markdown files at the root add
  visual noise to the file tree. Scoping the agent-guidance files under `.ai/` keeps them
  together; the root symlinks preserve auto-discovery.
- **Committed vs. local:** the `.ai/` canonical files are committed; the root symlinks are
  **gitignored** (`/AGENTS.md`, `/CLAUDE.md` in [`.gitignore`](./.gitignore)), so nothing
  in the build/lint/test pipeline depends on them. Each contributor (or their agent)
  recreates the symlinks locally:

  ```bash
  ln -s .ai/AGENTS.md AGENTS.md
  ln -s .ai/CLAUDE.md CLAUDE.md
  ```

  A **real file** at the repo root beats the symlink — if a contributor prefers a
  committed root `AGENTS.md`/`CLAUDE.md`, that works too; the `.ai/` copies stay the
  project default.
- **Cross-platform note:** symlinks survive `git clone` on macOS/Linux. On Windows hosts
  without symlink support enabled, the file may show up as a small text file containing
  the link target. If that ever bites a contributor, the fallback is to drop the symlinks
  and keep real files at root, hand-syncing the content.
- **`CODESTYLE.md` is not symlinked** — it sits directly at the repo root, since style
  serves humans and agents alike and is not AI-specific.

---

<a id="no-bundling"></a>
## No-bundling: native dependencies never touch the Dart `pubspec.yaml`

> _Stub — to be written as the native sides land. This is the package's defining
> principle and the reason it exists._
>
> Will document: why the recognition engines are declared **only** in platform build
> files (ML Kit + CameraX in `android/build.gradle.kts`; nothing but system frameworks —
> `Vision`, `AVFoundation` — on the Apple side via the podspec / `Package.swift`), so the
> Dart `pubspec.yaml` declares **no** recognition library. The payoff: iOS links
> **zero** third-party ML libraries, so the GoogleMLKit arm64 / Swift-Package-Manager
> warnings that motivated this package cannot arise. Includes the rejected path
> (`flutter_scalable_ocr` → `google_mlkit_text_recognition` as a *Dart* dep, which drags
> GoogleMLKit into the iOS build), the "no `camera` Dart dep either — native capture per
> platform" corollary, and the verification recipe (`rg -i 'mlkit' example/ios` → no
> matches; the example is SPM-based, so there is no `Podfile.lock`). Cross-refs: [`CODESTYLE.md#swift-ios-macos`](./CODESTYLE.md#swift-ios-macos),
> [`CODESTYLE.md#kotlin-android`](./CODESTYLE.md#kotlin-android), and the hard rules in
> [`.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules).

---

<a id="channel-topology"></a>
## Channel topology: Pigeon control API + `EventChannel` results + `Texture` preview

**Decision.** Three concerns ride three different transports, deliberately, rather than being
funnelled through one channel:

- **Control + the one-shot recognize → typed codegen `@HostApi`.** The control surface
  (`initialize` / `start` / `stop` / `setRegionOfInterest` / `setRecognitionLevel` /
  `setLanguages` / `setTorchEnabled` / `dispose`) is request/response and benefits from a
  generated, type-checked Dart↔native boundary. The static one-shot (`recognizeImage` /
  `recognizePath`, when that driver lands) is *also* request/response, so it rides the **same**
  `@HostApi` as an `@async` method returning a `TextSightCapture` — not the results stream
  below. Natively it allocates a transient image handler and touches no camera session,
  texture, or event sink. _(The codegen tool is **Pigeon** — see below.)_
- **Live per-frame results → a plain `EventChannel` stream.** A camera delivers ~30 captures a
  second; modelling that as a Pigeon `@FlutterApi` callback fights the codegen's
  request/response grain. An `EventChannel` is Flutter's idiomatic transport for a
  high-frequency native→Dart push; the controller re-exposes it as a
  `Stream<TextSightCapture>`.
- **Camera preview → a `Texture`** via the texture registry. Pixels are not a codegen concern
  at all: the native side renders frames into a `FlutterTexture` and hands Dart only the
  integer texture id, which `TextSightView` mounts in a `Texture` widget.

**Why split at all.** Each transport matches the *shape* of its traffic — typed
request/response for control, an unbounded push-stream for results, a raw pixel surface for
preview. Collapsing them (frames as `@HostApi` return values, or pixels over a method channel)
means fighting the wrong tool on the hot path. The split also keeps the two drivers honest:
live and static **share** the `@HostApi` recognizer surface and the result models, but only the
*live* driver needs the `EventChannel` and the `Texture` — see
[#public-api-via-single-export-file](#public-api-via-single-export-file).

**Pigeon, not the Golubets fork** (`pigeon: ^27.1.0`, chosen 2026-06-17). Pigeon v27 covers the
whole control surface this schema needs — a typed `@HostApi`, `@async` methods, and the message
classes — and as the official Flutter-team tool it is the durable choice for a package others
depend on. Golubets' genuine additions (user-defined generics, advanced sealed classes, default
parameter values, true Swift-concurrency / Kotlin-coroutine codegen) go unused by this
flat-model, hand-written-public-types design. Low-risk and reversible: codegen is dev-time only
and `messages.g.dart` is committed, so the fallback is simply to freeze it. (Pigeon's own
`@EventChannelApi` could later type the results stream, but with `Rect`/`Size` models that can't
cross Pigeon, the hand-written plain `EventChannel` above stays more direct.)

**The per-frame wire format is a hand-written, self-describing map.** Each event on the captures
`EventChannel` (`com.LahaLuhem.text_sight/captures`) is a `Map`: top-level `imageWidth` /
`imageHeight` (doubles, pixels post-rotation), `quarterTurns` (int — clockwise quarter-turns to
rotate the raw preview texture to display-upright, per [#coordinate-normalization](#coordinate-normalization)),
plus `lines`, a `List` of per-line maps —
`text` (String), `confidence` (double or null), `left` / `top` / `width` / `height` (the box,
normalized `[0,1]` top-left per [#coordinate-normalization](#coordinate-normalization)), and
`elements` (null in v1, reserved). `confidence` is null when the platform supplies none (ML Kit);
`elements` rides the wire as a reserved slot so populating it later is additive. The Dart side
decodes this in `PigeonTextSightPlatform`; **each native side must emit exactly this shape.**
Map-based, not positional — adding a key is non-breaking and frames stay legible in logs.

**Generated code is committed and never hand-edited.** `messages.g.dart` is checked in (so
consumers and CI need no codegen step) and regenerated from the schema, never patched — see
[hard rule 7 in `.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules). Regeneration is **two steps** —
`dart run pigeon --input pigeons/text_sight.dart` then
`dart format lib/src/platform/messages.g.dart` — because Pigeon emits ~80-column Dart while the
project's formatter gate (`page_width: 100`, applied tree-wide) would otherwise flag the output.
The `dart format` pass is deterministic and mechanical, not a hand-edit, so it does not breach the
never-patch rule; a freshness check (regenerate-and-diff) must run the same format step before
comparing. The bounding-box geometry these channels carry is specified in
[#coordinate-normalization](#coordinate-normalization).

---

<a id="coordinate-normalization"></a>
## Coordinate normalization: top-left `[0,1]` in native code

**Decision.** Every bounding box that crosses the channel is **normalized to `[0,1]` with a
top-left origin, converted on the native side** — so the Dart overlay painter is
platform-agnostic and never branches on platform.

The three coordinate systems that meet here disagree:

- **Apple Vision** returns boxes normalized to `[0,1]` but with a **bottom-left** origin
  (`VNRecognizedTextObservation.boundingBox`). The Swift side flips Y
  (`top = 1 - (origin.y + height)`) before sending.
- **ML Kit** returns **pixel** rects in the *rotated* image space. The Kotlin side divides by
  the rotated image width/height to normalize.
- **Flutter** wants top-left normalized, so the painter maps a box onto the preview with one
  `BoxFit`-style transform.

Doing the conversion natively — each side owns a small named helper (see
[`CODESTYLE.md#swift-ios-macos`](./CODESTYLE.md#swift-ios-macos) and
[`CODESTYLE.md#kotlin-android`](./CODESTYLE.md#kotlin-android)) — establishes the unified
contract *before* the channel, so the Dart layer carries no platform conditionals.

**`TextSightCapture.imageSize`** is the pixel size of the analyzed frame/image **in the same
orientation as the normalized boxes** (post-rotation). A consumer maps a normalized box into
widget space with `imageSize` plus the fit used to display the preview; it never needs the raw
sensor orientation.

**The preview texture is the one thing not pre-rotated.** Boxes and `imageSize` are reported in
display orientation, but the live preview is handed to the texture in the camera's *raw* (sensor)
orientation — rotating frames natively is either costly or unreliable across the two capture stacks
(CameraX `Preview` → `SurfaceProducer` doesn't transform a raw surface, and an
`AVCaptureVideoDataOutput` connection rotation is fiddly). Each frame therefore carries
`quarterTurns`: the clockwise quarter-turns `TextSightView` applies via a `RotatedBox` to bring the
texture into the same display orientation the boxes already use — so the overlay aligns **without a
per-platform branch in Dart**. On Android `quarterTurns` is the `ImageProxy` rotation ÷ 90; on iOS it
comes from `AVCaptureDevice.RotationCoordinator`, which also selects the `CGImagePropertyOrientation`
handed to Vision so recognition stays upright. A still image is already upright, so the static
one-shot reports `0`.

**Region-of-interest uses the same contract.** The ROI is a `Rect` in the same normalized
`[0,1]` top-left space as the output boxes (not pixels) — a debug `assert` at the consuming
controller enforces the range, since the `const` `TextSightOptions` can't validate in its own
constructor. Because ROI is part of the source-agnostic recognizer config it applies uniformly: the
live driver sets it via the controller; the static driver takes it as an optional parameter
(full-frame when omitted). On Apple the value goes to `VNImageRequestHandler.regionOfInterest`
after the same Y-flip (Vision's ROI is also bottom-left). On Android v1 the recognizer runs on
the full frame and lines whose box center falls outside the ROI are filtered out; a true
pre-crop of the frame is a future optimization.

**Orientation is an input, not an afterthought.** Recognition silently degrades if it is
wrong: the Apple side must pass the correct `CGImagePropertyOrientation`, the Android side the
`ImageProxy`'s `rotationDegrees`. The normalization above assumes the image has already been
interpreted in its display orientation. Cross-refs:
[#channel-topology](#channel-topology) (the transport that carries these boxes) and
[#public-api-via-single-export-file](#public-api-via-single-export-file) (the `RecognizedLine`
model and the `Rect` ROI).

---

<a id="ios-capture-strategy"></a>
## iOS capture & recognition strategy: roll-your-own AVCapture + Swift Vision

**Decision.** The iOS live path is **roll-your-own** `AVCaptureSession` + Vision →
`FlutterTexture`, mirroring the Android `TextSightCamera`. The recognizer is Vision's **Swift
`RecognizeTextRequest`** — the WWDC 2024 API — **not** the legacy `VNRecognizeTextRequest`. This
sets the **iOS deployment floor at 18.0** (`text_sight.podspec` + `Package.swift`); a future macOS
target would floor at 15.0 (the same API's macOS availability).

**Why roll-your-own, not `DataScannerViewController`.** VisionKit's `DataScannerViewController`
(iOS 16+, A12+) is turnkey, but it is a UIKit view controller that **owns its own camera preview
and result overlay**. It cannot render into a `FlutterTexture`, so adopting it would force iOS onto
a `UiKitView` platform-view path while Android renders to a `Texture` — the two platforms would
diverge structurally, and the unified contract already built and verified on Android (the captures
`EventChannel`, the consumer-supplied `overlayBuilder`, the normalized-`Rect` ROI, per-line
confidence) would not survive. There is also **no turnkey live-text equivalent on Android** to pair
it with: Google's turnkey, Play-services-delivered scanner UIs are the **Code Scanner** (barcodes
only) and the **Document Scanner** (a capture-crop-enhance flow returning an image/PDF, not a live
per-frame OCR stream) — live text on Android is always CameraX + ML Kit wired by hand. A turnkey
route would therefore be both a worse fit *and* asymmetric. Roll-your-own keeps one architecture
across platforms and shares a future macOS `darwin/` (Vision is identical there).

**Why the Swift `RecognizeTextRequest`, not `VNRecognizeTextRequest`.** It is the API Apple steers
new code toward (Swift concurrency / `async`–`await`, `Sendable`, value-typed
`RecognizedTextObservation`s), and it keeps this package on the vendor-forward stack — the same
posture that puts Android on CameraX + ML Kit v2 and that the whole no-bundling effort embodies
(off GoogleMLKit-on-iOS). It runs the **same** Vision text engine as the legacy request, so this is
a modernity / ergonomics choice, **not** an accuracy or capability gain; `topCandidates(1)`
confidence and a normalized `regionOfInterest` both carry over. The cost is the iOS 18 floor —
accepted because supporting iOS 13–17 devices is deliberately deprioritized in favour of the
current stack.

**Deferred — backwards-compatible hybrid (iOS 13–17).** A future feature can lower the floor back to
iOS 13 without losing the modern path: gate on `if #available(iOS 18, *)` to use
`RecognizeTextRequest`, falling back to `VNRecognizeTextRequest` on iOS 13–17. The legacy request is
**not deprecated**, so the fallback stays valid; both feed the identical per-frame map over the
captures `EventChannel`, so only the recognizer-construction site branches. It is deferred because
it roughly doubles the Vision code paths to serve devices this release does not target — additive
and non-breaking when it lands. Cross-refs: [#channel-topology](#channel-topology) (the wire format
both paths emit) and [#coordinate-normalization](#coordinate-normalization) (the Y-flip both apply —
the new Swift API keeps Vision's lower-left origin, so the flip stays; `NormalizedRect.toImageCoordinates(_:origin:.upperLeft)`
performs it, and a unit image size yields the top-left-normalized box directly).

---

<a id="federation-deferred"></a>
## Federation deferred: one plugin package for v1

> _Stub — to be written if/when federation is reconsidered._
>
> Will document why v1 is a **single plugin package** declaring all platforms, rather than
> a federated set (`text_sight_platform_interface` + `text_sight_ios` +
> `text_sight_android`). Federation earns its complexity only when third parties add
> platforms or independent per-platform versioning is needed — neither applies yet. The
> `plugin_platform_interface` dependency is already in place so the boundary can be drawn
> later without a disruptive restructure.

---

<a id="known-limitations"></a>
## Known limitations, performance, and deferred work

A running list of what v1 does *not* do well yet — the backlog to work out next. The user-facing
summary lives in the [README](./README.md#limitations--known-issues); the engineering detail and
rationale live here.

**Performance — live recognition is single-in-flight with frame back-pressure.** Exactly one
recognition runs at a time (iOS: one `RecognizeTextRequest` gated by an `isProcessing` flag +
`alwaysDiscardsLateVideoFrames`; Android: `STRATEGY_KEEP_ONLY_LATEST` + the mandatory
`imageProxy.close()`). The preview texture updates every frame, but the *recognition* rate is bounded
by how fast the engine returns — under dense text or on lower-end devices it falls below the camera
frame rate, and late frames are dropped rather than queued (the intended trade-off: latency over
backlog). Levers to explore next: raising `minimumTextHeight` / downscaling before recognition, an
explicit frame-skip cadence, and the Android ROI pre-crop below. Default `RecognitionLevel.fast` for
live; `.accurate` is materially heavier.

**Region-of-interest is asymmetric.** iOS sets Vision's native `regionOfInterest`, so a smaller box
actually lowers recognition cost. Android v1 recognizes the full frame and *filters* lines whose
center falls outside the ROI ([#coordinate-normalization](#coordinate-normalization)) — correct
results, but **no speed-up**. A true YUV pre-crop on Android is the deferred optimization.

**Platform capability differences (inherent, not bugs).** `recognitionLevel` and `languages` apply on
iOS (Vision) and are **no-ops on Android** (the ML Kit Latin recognizer exposes neither and reads
Latin only). Per-line `confidence` is supplied by both, but the scales are **not comparable**. These
are documented in the [README](./README.md); they are engine properties, not defects.

**iOS rotation & background.** Orientation tracking uses `AVCaptureDevice.RotationCoordinator`
(iOS 17+) to keep the delivered buffer upright; it is **compile-verified but not yet exercised on a
physical device** (the Simulator has no camera). Explicit app-background teardown (gotcha 6 — stop the
session on `didEnterBackground`, restart on foreground) is not implemented: the session relies on
iOS's automatic capture suspension plus the consumer calling `stop`/`dispose`.

**iOS floor is 18.0.** iOS 13–17 are unsupported until the availability-gated `VNRecognizeTextRequest`
fallback lands ([#ios-capture-strategy](#ios-capture-strategy)).

**Deferred features (each additive and non-breaking when it lands):**

- **Static one-shot** `TextSight.recognizeImage` / `.recognizePath` over the same `@HostApi` and
  models — designed-for, not built ([#channel-topology](#channel-topology),
  [#public-api-via-single-export-file](#public-api-via-single-export-file)).
- **Word-level `RecognizedElement`s** — `RecognizedLine.elements` ships `null`/reserved; populating it
  is a minor.
- **iOS 13–17 hybrid** — `if #available(iOS 18)` → `RecognizeTextRequest`, else
  `VNRecognizeTextRequest` ([#ios-capture-strategy](#ios-capture-strategy)).
- **True ROI pre-crop on Android** (the perf lever above).
- **macOS** — Apple Vision is identical; a shared `darwin/` brings it in cheaply
  ([#ios-capture-strategy](#ios-capture-strategy)).
- **Additional Android scripts** (Chinese / Devanagari / Japanese / Korean) — each needs its own ML
  Kit recognizer + Gradle dependency.
- **Federation** — split into a platform-interface package + per-platform packages if third parties
  add platforms ([#federation-deferred](#federation-deferred)).

---

<a id="public-api-via-single-export-file"></a>
## Public API funnelled through `lib/text_sight.dart`

**Decision.** `lib/text_sight.dart` is the only file consumers import. It holds
`export 'src/…';` lines and nothing else; every implementation file lives under `lib/src/` and
is private by convention. Dart has no hard public/private boundary below `lib/`, so this funnel
is how the ecosystem signals private intent — and it gives one file to audit before a release.
Moving code *within* `lib/src/` is free; moving a symbol into or out of the re-export list is
semver-visible (minor to add, major to remove or change a signature). Prefer `show` over `hide`
if a partial export ever becomes necessary.

**Layering.** Both drivers funnel down through one federation seam:

```
PUBLIC   barrel re-exports — TextSightController · TextSightView · TextSight (one-shot)
         · TextSightCapture · RecognizedLine · RecognizedElement
         · RecognitionLevel · TextSightOptions
   │  both drivers delegate down ↓
SEAM     TextSightPlatform extends PlatformInterface   (federation boundary; one impl for now)
   │
IMPL     codegen @HostApi  +  EventChannel  +  TextureRegistry      (lands with native code)
```

The platform-interface seam is drawn now even though federation is deferred
([#federation-deferred](#federation-deferred)): both the live controller and the static
one-shot delegate to `TextSightPlatform.instance`, so a later split into a
`text_sight_platform_interface` plus per-platform packages is mechanical, not a rewrite.

**Module layout (`lib/src/`).** The recognizer is the core; capture is a seam, not a mode flag.
The directories make that physical:

```
lib/
├── text_sight.dart                   barrel — export 'src/…'; only
└── src/
    ├── recognition/                  capture-agnostic CORE — result models + recognizer config
    │   ├── text_sight_capture.dart
    │   ├── recognized_line.dart
    │   ├── recognized_element.dart
    │   ├── recognition_level.dart
    │   └── text_sight_options.dart
    ├── capture/                       the two DRIVERS over the one recognizer
    │   ├── text_sight_controller.dart    live-camera driver (v1)
    │   └── text_sight.dart               TextSight one-shot static driver (near-term)
    ├── view/
    │   └── text_sight_view.dart          Texture-backed widget (+ overlay painter later)
    └── platform/
        ├── text_sight_platform.dart      the federation seam
        └── messages.g.dart               generated control channel (later; never hand-edited)
```

`recognition/` holds only capture-agnostic types; `capture/` puts both drivers
(`TextSightController` live, `TextSight` one-shot) together so the "one recognizer, two drivers"
seam shows in the tree. Each public type gets its own file (per
[`CODESTYLE.md#naming`](./CODESTYLE.md#naming)).

**Result-model contracts.** The capture-agnostic types the barrel exposes:

- **`RecognizedLine.confidence` is `double?`, range `[0,1]`.** Both engines supply a per-line
  confidence — Apple Vision, and (re-verified for the pinned `play-services-mlkit-text-recognition`
  19.0.1) ML Kit v2 via `Text.Line.getConfidence()`. It is `null` only when the engine omits one
  for a given line; the two scales are **not guaranteed comparable** across platforms. `null`
  means **"not supplied,"** *not* "low confidence" — never synthesize a value to fill it. A
  consumer thresholding picks an explicit default (`(line.confidence ?? 1) >= min`) and never
  compares `null` to a bound.
- **`RecognizedLine.elements` is a reserved `List<RecognizedElement>?`.** Word-level elements
  are part of the model shape from v1 but stay **`null` until the feature ships**, so
  populating them later is an additive minor, not a breaking change. `RecognizedElement` is
  intentionally minimal — `text` · `boundingBox` · `confidence?`, the same contract as a line,
  one level down.
- **Both result types are capture-agnostic, immutable, and `const`-constructible**, with
  `toString`. They hold their lists directly — no defensive copy, since a `const` instance is
  passed a `const` (immutable) list (see
  [`CODESTYLE.md`](./CODESTYLE.md#listunmodifiable-over-unmodifiablelistview)).

**Configuration.** One config type, reused across both drivers:

- **`TextSightOptions` is the one source-agnostic recognizer config** — `level` · `languages` ·
  `roi` — accepted by *both* drivers. The live driver takes it on `TextSightController`; the
  static one-shot takes it per call, defaulting `level` to `.accurate` where the live default is
  `.fast`. Not a per-driver duplicate. `languages` is `Iterable<Locale>`, not raw BCP-47 strings —
  a closed enum would misstate a platform- and OS-version-dependent capability, so the type
  stays structured-but-open and maps to tags via `Locale.toLanguageTag()` at the seam.
- **`torchEnabled` is a controller-only parameter, deliberately *not* in `TextSightOptions`.**
  Torch is a live-session concern; a static image has none, so folding it into the shared
  recognizer config would be a category error. The seam, expressed in the type system:
  recognizer config is shared across drivers, session config is not.
- **`roi` is a `Rect`** in normalized `[0,1]` top-left space (the same type as the output
  boxes, not a bespoke twin) — its range is validated by a debug `assert` at the controller
  (the `const` `TextSightOptions` can't run a check in its own constructor). See
  [#coordinate-normalization](#coordinate-normalization).

**The static one-shot is a separate driver, not a session mode.** `TextSight.recognizeImage` /
`.recognizePath` (near-term) return a `Future<TextSightCapture>` and need no controller, camera
permission, texture, or session — they share only the recognizer and result models with the live
path, and ride the `@HostApi` ([#channel-topology](#channel-topology)).
