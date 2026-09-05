<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#agentsmd-and-claudemd-are-symlinks-into-ai)
- [Dependabot automerges the boring tier, behind four aggregate checks](#dependabot-automerge)
- [No-bundling: native dependencies never touch the Dart `pubspec.yaml`](#no-bundling-native-dependencies-never-touch-the-dart-pubspecyaml)
- [Channel topology: Pigeon control API + `EventChannel` results + `Texture` preview](#channel-topology-pigeon-control-api--eventchannel-results--texture-preview)
- [Coordinate normalization: top-left `[0,1]` in native code](#coordinate-normalization-top-left-01-in-native-code)
- [iOS capture & recognition strategy: roll-your-own AVCapture + Swift Vision](#ios-capture-strategy)
- [Model readiness and the bundled / unbundled axis (Android)](#model-readiness)
- [Federation deferred: one plugin package for v1](#federation-deferred-one-plugin-package-for-v1)
- [Known limitations, performance, and deferred work](#known-limitations)
- [`@TaskQueue` on the control channel: measured, rejected for now](#taskqueue-rejected)
- [Public API funnelled through `lib/text_sight.dart`](#public-api-funnelled-through-libtext_sightdart)
- [Developing the Android module standalone in Android Studio](#android-standalone-dev)

<!-- TOC end -->

Consolidated source of truth for design decisions, rejected paths, and non-obvious
technical trade-offs.

READMEs, [`CODESTYLE.md`](./CODESTYLE.md), and [`.ai/AGENTS.md`](./.ai/AGENTS.md)
reference sections here by anchor (e.g. `APPENDIX.md#no-bundling`).

> **Status:** the symlink, dependabot-automerge, channel-topology, coordinate-normalization, iOS-capture-strategy,
> model-readiness, known-limitations, taskqueue-rejected, and public-API sections are written. `#no-bundling` and
> `#federation-deferred` stay stubs, locked decisions whose rationale is filled in when the
> corresponding code lands. Anchors are stable, and only stub bodies grow.

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
  together, and the root symlinks preserve auto-discovery.
- **Committed vs. local:** the `.ai/` canonical files are committed, and the root symlinks are
  **gitignored** (`/AGENTS.md`, `/CLAUDE.md` in [`.gitignore`](./.gitignore)), so nothing
  in the build/lint/test pipeline depends on them. Each contributor (or their agent)
  recreates the symlinks locally:

  ```bash
  ln -s .ai/AGENTS.md AGENTS.md
  ln -s .ai/CLAUDE.md CLAUDE.md
  ```

  A **real file** at the repo root beats the symlink. If a contributor prefers a
  committed root `AGENTS.md`/`CLAUDE.md`, that works too, and the `.ai/` copies stay the
  project default.
- **Cross-platform note:** symlinks survive `git clone` on macOS/Linux. On Windows hosts
  without symlink support enabled, the file may show up as a small text file containing
  the link target. If that ever bites a contributor, the fallback is to drop the symlinks
  and keep real files at root, hand-syncing the content.
- **`CODESTYLE.md` is not symlinked**: it sits directly at the repo root, since style
  serves humans and agents alike and is not AI-specific.

---

<a id="dependabot-automerge"></a>
## Dependabot automerges the boring tier, behind four aggregate checks
[`dependabot-automerge.yml`](./.github/workflows/dependabot-automerge.yml) arms GitHub's native
auto-merge (rebase) for patch and minor bumps in `github-actions`, `gradle` (both `/android` and
`/example/android`), and `pub` under `/example`, plus `github-actions` **majors**. Root `pub`,
and gradle / pub majors, wait for a human.
Dependabot has no `automerge` config key the way Renovate does, so the mechanism is a workflow. The
sibling
[`better_internet_connectivity_checker`](https://github.com/LahaLuhem/better_internet_connectivity_checker)
and [`hive_box_manager`](https://github.com/LahaLuhem/hive_box_manager) repos run the same shape.

- **Root `pub` stays manual.** It reaches every consumer's resolution and is semver-relevant, and
  bots are exempt from [`changelog.yml`](./.github/workflows/changelog.yml), so an automerged bump
  would ship with no release note.
- **`/android` gradle automerges anyway, unlike the siblings.** Its deps ride the AAR's POM to every
  downstream Android consumer (ML Kit, Play Services, CameraX), so these bumps *are*
  publish-relevant, and `Android example build + unit tests` stands in for the read-through. The cost is
  the missing changelog entry, not the build, so check the Android deps before a release if one landed.
- **Minor, not just patch,** because `dependabot.yml` groups both and `fetch-metadata` reports a
  group's *highest* semver step, and patch-only would skip most batches.
- **`github-actions` majors automerge too.** Actions reach no consumer, and a bad bump breaks the
  very CI that gates the merge. It is also the only shape this ecosystem produces: the `actions`
  group covers minor and patch, so majors always arrive alone, and #17, #18, #19 and #41 were all
  merged by hand under the patch/minor-only gate. Not covered by the gate, check these by hand:
  `actions/create-github-app-token` (only in `changelog.yml`, whose cider job skips bot PRs) and
  `publish.yml`'s tag-only OIDC path.
- **The ruleset is the load-bearing half.** Auto-merge waits only on *required* checks, so this is
  safe only while `main`'s ruleset is **active** and requires `repo-ok`, `package-ok`, `example-ok`,
  `conventions-ok`. Keep `required_signatures` off it: rebase-merge emits unsigned commits, so it
  would block every automerge.
- **`GITHUB_TOKEN` enables the merge, not the changelog App.** The App sits in the ruleset's bypass
  list, and a bypass covers status checks too, so merging as it would skip the gate this rests on.
  Its merges also trigger no further workflows, which costs nothing here: `package.yml`'s `gate`
  already skips post-merge pushes to `main`.
- **Aggregates, not the real job names.** `Dart format` and `Flutter analyze` each appear in two
  workflows, so a required list of real contexts is ambiguous, and a renamed one leaves every PR
  waiting forever. Each workflow instead closes with one `*-ok` job that `needs` its siblings and
  fails on `failure` or `cancelled`. They read `needs.*.result` by hand because a skipped job
  reports success, which is what keeps `conventions-ok` green on bot PRs and `package-ok` green on
  a post-merge push. Corollary: a cancelled `pr-conventions` run strands a red `conventions-ok` on
  the SHA, so `cancel-in-progress` skips `labeled` / `unlabeled` (Dependabot labels its own PR
  seconds after opening, which hit every bot PR) and stays on for a force-push.
- **`pull_request_target`** because Dependabot's `pull_request` runs get a read-only token and
  enabling auto-merge needs write. Safe as `changelog.yml`: PR code is never checked out.

---

<a id="no-bundling"></a>
## No-bundling: native dependencies never touch the Dart `pubspec.yaml`

> _Stub, to be written as the native sides land. This is the package's defining
> principle and the reason it exists._
>
> Will document: why the recognition engines are declared **only** in platform build
> files (ML Kit + CameraX in `android/build.gradle.kts`, and nothing but system frameworks,
> `Vision`, `AVFoundation`, on the Apple side via the podspec / `Package.swift`), so the
> Dart `pubspec.yaml` declares **no** recognition library. The payoff: iOS links
> **zero** third-party ML libraries, so the GoogleMLKit arm64 / Swift-Package-Manager
> warnings that motivated this package cannot arise. Includes the rejected path
> (`flutter_scalable_ocr` → `google_mlkit_text_recognition` as a *Dart* dep, which drags
> GoogleMLKit into the iOS build), the "no `camera` Dart dep either, native capture per
> platform" corollary, and the verification recipe (`rg -i 'mlkit' example/ios` → no
> matches, and the example is SPM-based, so there is no `Podfile.lock`). Cross-refs: [`CODESTYLE.md#swift-ios`](./CODESTYLE.md#swift-ios),
> [`CODESTYLE.md#kotlin-android`](./CODESTYLE.md#kotlin-android), and the hard rules in
> [`.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules).

---

<a id="camera-permission"></a>
## Camera permission: requested natively, no permission package

**Decision (2026-06-22).** text_sight requests camera permission itself, straight through the OS
APIs, and bundles **no** permission package. The public surface is two methods on
`TextSightController`: `checkCameraPermission()` (a prompt-free status read) and
`requestCameraPermission()` (drives the system prompt), both returning a unified
`CameraPermissionStatus { granted, denied, permanentlyDenied }`. `start()` stays permission-free, so
the app keeps control of *when* the prompt appears.

**Why not bundle `permission_handler`.** The request primitive is already free on both platforms,
`AVCaptureDevice.requestAccess` (AVFoundation) on iOS, `ActivityCompat.requestPermissions` plus a
`RequestPermissionsResultListener` (the Flutter embedding + AndroidX) on Android, which is exactly
what `permission_handler` wraps internally for *app* code. A plugin calls it directly (the
`mobile_scanner` approach), so bundling buys nothing and costs plenty:

- It lands in **every** downstream user's transitive closure for one effectively-boolean question.
- On iOS it makes consumers' lives *harder*, not easier: `permission_handler_apple` gates each
  permission behind `GCC_PREPROCESSOR_DEFINITIONS` macros in the **Podfile**, and Apple's static
  analyzer scans the binary for permission code at submission. Bundling it would force a Podfile
  macro step on every consumer and drag a CocoaPods-shaped config into the SPM / no-`Podfile`
  example, the opposite of removing boilerplate, and a direct hit on the package's
  [no-bundling identity](#no-bundling-native-dependencies-never-touch-the-dart-pubspecyaml).

So this is the no-bundling principle extended from the ML engines to permissions. Apps that already
use `permission_handler` keep working unchanged. This adds an option, it does not remove one.

**What stays the consumer's job.** The iOS `NSCameraUsageDescription` string is app-specific and
cannot be delegated. The Android `CAMERA` `<uses-permission>` ships in the plugin's *own* manifest
and merges automatically. The request and the status read are all the plugin now owns.

**The Android cost: `ActivityAware`.** A runtime permission request needs a foreground `Activity`,
which a plain `FlutterPlugin` never holds, since it gets only the application `Context`. So
`TextSightPlugin` implements `ActivityAware` to capture the `ActivityPluginBinding`, registers a
`RequestPermissionsResultListener`, and delegates the flow to `CameraPermissionRequester`. This is
unavoidable *regardless of approach*. Even `permission_handler` needs an Activity, it just hides the
plumbing. The capture pipeline binds to a headless `LifecycleOwner`, so Activity attach/detach never
disturbs a running session. The eager `checkSelfPermission` / `authorizationStatus` guards already in
`initialize()` stay as a defence-in-depth net (the request rides the same typed `@HostApi` as the
rest of the control surface, see [#channel-topology](#channel-topology)).

**The unified status contract hides a real platform asymmetry.** `granted`, then `denied` (not granted,
but a request may still surface the prompt), then `permanentlyDenied` (no prompt will appear, only system
settings can grant it). The platforms reach a refusal differently, and the enum papers over it:

- **iOS prompts exactly once.** After a decision, `requestAccess` resolves immediately with the
  stored value and never re-prompts. So an iOS refusal, and `.restricted` (parental controls / an
  MDM profile), maps to `permanentlyDenied`. `.notDetermined` maps to `denied`, since a request can
  still show the dialog.
- **Android distinguishes** a re-askable refusal from "don't ask again" via
  `shouldShowRequestPermissionRationale`, checked *after* the result. A prompt-free `check` (no
  Activity, and it must not trigger UI) cannot tell permanence apart, so it conservatively reports
  `denied`.

The actionable split for callers is the whole point: `denied` → asking again may help,
`permanentlyDenied` → route the user to system settings. The example dogfoods exactly this and, by
dropping its own `permission_handler` dependency, doubles as the no-bundling proof for the permission
path.

---

<a id="channel-topology"></a>
## Channel topology: Pigeon control API + `EventChannel` results + `Texture` preview

**Decision.** Three concerns ride three different transports, deliberately, rather than being
funnelled through one channel:

- **Control + the one-shot recognize → typed codegen `@HostApi`.** The control surface
  (`initialize` / `start` / `stop` / `setRegionOfInterest` / `setRecognitionLevel` /
  `setLanguages` / `setTorchEnabled` / `checkCameraPermission` / `requestCameraPermission` /
  `dispose`) is request/response and benefits from a generated, type-checked Dart↔native
  boundary. The static one-shot (`recognizeImage` /
  `recognizePath`) is *also* request/response, so it rides the **same** `@HostApi` as two
  `@async` methods that return the same self-describing per-frame map the results stream uses
  (decoded Dart-side into a `TextSightCapture`), not the results stream below. This is why the
  result models need no Pigeon twin. Natively each allocates a transient image handler and touches
  no camera session, texture, or event sink. _(The codegen tool is **Pigeon**, see below.)_
- **Live per-frame results → a plain `EventChannel` stream.** A camera delivers ~30 captures a
  second, and modelling that as a Pigeon `@FlutterApi` callback fights the codegen's
  request/response grain. An `EventChannel` is Flutter's idiomatic transport for a
  high-frequency native→Dart push, and the controller re-exposes it as a
  `Stream<TextSightCapture>`.
- **Camera preview → a `Texture`** via the texture registry. Pixels are not a codegen concern
  at all: the native side renders frames into a `FlutterTexture` and hands Dart only the
  integer texture id, which `TextSightView` mounts in a `Texture` widget.

**Why split at all.** Each transport matches the *shape* of its traffic: typed
request/response for control, an unbounded push-stream for results, a raw pixel surface for
preview. Collapsing them (frames as `@HostApi` return values, or pixels over a method channel)
means fighting the wrong tool on the hot path. The split also keeps the two drivers honest:
live and static **share** the `@HostApi` recognizer surface and the result models, but only the
*live* driver needs the `EventChannel` and the `Texture`, see
[#public-api-via-single-export-file](#public-api-via-single-export-file).

**Pigeon, not the Golubets fork** (`pigeon: ^27.1.0`, chosen 2026-06-17). Pigeon v27 covers the
whole control surface this schema needs (a typed `@HostApi`, `@async` methods, and the message
classes) and as the official Flutter-team tool it is the durable choice for a package others
depend on. Golubets' genuine additions (user-defined generics, advanced sealed classes, default
parameter values, true Swift-concurrency / Kotlin-coroutine codegen) go unused by this
flat-model, hand-written-public-types design. The model-readiness work (2026-06-22) reconfirmed
this head-on: its `TextSightReadinessState` *is* a sealed class, yet it stays hand-written and rides
the readiness `EventChannel` as a decoded map, so Golubets' sealed-class codegen would still have
gone unused. That, plus Golubets' own pub.dev page discouraging generated code in a published
package's public API and requiring both ends on the same version, kept the package on Pigeon (see
[#model-readiness](#model-readiness)). Low-risk and reversible: codegen is dev-time only and
`messages.g.dart` is committed, so the fallback is simply to freeze it. (Pigeon's own
`@EventChannelApi` could later type the results stream, but with `Rect`/`Size` models that can't
cross Pigeon, the hand-written plain `EventChannel` above stays more direct.)

**The per-frame wire format is a hand-written, self-describing map.** Each event on the captures
`EventChannel` (`com.lahaluhem.text_sight/captures`) is a `Map`: top-level `imageWidth` /
`imageHeight` (doubles, pixels post-rotation), `quarterTurns` (int, clockwise quarter-turns to
rotate the raw preview texture to display-upright, per [#coordinate-normalization](#coordinate-normalization)),
plus `lines`, a `List` of per-line maps:
`text` (String), `confidence` (double or null), `left` / `top` / `width` / `height` (the box,
normalized `[0,1]` top-left per [#coordinate-normalization](#coordinate-normalization)), and
`elements` (null in v1, reserved). `confidence` is null when the platform supplies none (ML Kit).
`elements` rides the wire as a reserved slot so populating it later is additive. The Dart side
decodes this in `PigeonTextSightPlatform`, and **each native side must emit exactly this shape.**
Map-based, not positional, so adding a key is non-breaking and frames stay legible in logs.

**Generated code is committed and never hand-edited.** `messages.g.dart` is checked in (so
consumers and CI need no codegen step) and regenerated from the schema, never patched. See
[hard rule 7 in `.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules). Regeneration is **two steps**,
`dart run pigeon --input pigeons/text_sight.dart` then
`dart format lib/src/platform/messages.g.dart`, because Pigeon emits ~80-column Dart while the
project's formatter gate (`page_width: 100`, applied tree-wide) would otherwise flag the output.
The `dart format` pass is deterministic and mechanical, not a hand-edit, so it does not breach the
never-patch rule, and a freshness check (regenerate-and-diff) must run the same format step before
comparing. The bounding-box geometry these channels carry is specified in
[#coordinate-normalization](#coordinate-normalization).

---

<a id="coordinate-normalization"></a>
## Coordinate normalization: top-left `[0,1]` in native code

**Decision.** Every bounding box that crosses the channel is **normalized to `[0,1]` with a
top-left origin, converted on the native side**, so the Dart overlay painter is
platform-agnostic and never branches on platform.

The three coordinate systems that meet here disagree:

- **Apple Vision** returns boxes normalized to `[0,1]` but with a **bottom-left** origin
  (`VNRecognizedTextObservation.boundingBox`). The Swift side flips Y
  (`top = 1 - (origin.y + height)`) before sending.
- **ML Kit** returns **pixel** rects in the *rotated* image space. The Kotlin side divides by
  the rotated image width/height to normalize.
- **Flutter** wants top-left normalized, so the painter maps a box onto the preview with one
  `BoxFit`-style transform.

Doing the conversion natively, where each side owns a small named helper (see
[`CODESTYLE.md#swift-ios`](./CODESTYLE.md#swift-ios) and
[`CODESTYLE.md#kotlin-android`](./CODESTYLE.md#kotlin-android)), establishes the unified
contract *before* the channel, so the Dart layer carries no platform conditionals.

**`TextSightCapture.imageSize`** is the pixel size of the analyzed frame/image **in the same
orientation as the normalized boxes** (post-rotation). A consumer maps a normalized box into
widget space with `imageSize` plus the fit used to display the preview, and it never needs the raw
sensor orientation.

**The preview texture is the one thing not pre-rotated.** Boxes and `imageSize` are reported in
display orientation, but the live preview is handed to the texture in the camera's *raw* (sensor)
orientation, since rotating frames natively is either costly or unreliable across the two capture stacks
(CameraX `Preview` → `SurfaceProducer` doesn't transform a raw surface, and an
`AVCaptureVideoDataOutput` connection rotation is fiddly). Each frame therefore carries
`quarterTurns`: the clockwise quarter-turns `TextSightView` applies via a `RotatedBox` to bring the
texture into the same display orientation the boxes already use, so the overlay aligns **without a
per-platform branch in Dart**. On Android `quarterTurns` is the `ImageProxy` rotation ÷ 90, kept live by mirroring the display
rotation into `ImageAnalysis.targetRotation` (a headless plugin session gets no automatic
orientation updates, so a `DisplayManager.DisplayListener` drives it, and without it only portrait is
right). On iOS it comes from `AVCaptureDevice.RotationCoordinator`, which also selects the
`CGImagePropertyOrientation` handed to Vision so recognition stays upright. A still image is read in
its EXIF orientation natively (iOS via `CGImageSource`, Android decodes the bitmap and reads
`ExifInterface`, passing the rotation to `InputImage`), so it is already upright and the static
one-shot reports `0`.

**Region-of-interest uses the same contract.** The ROI is a `Rect` in the same normalized `[0,1]`
top-left space as the output boxes (not pixels), with a debug `assert` at the consuming controller
enforces the range, since the `const` `TextSightOptions` can't validate in its own constructor.
Because ROI is part of the source-agnostic recognizer config it applies uniformly: the live driver
sets it via the controller, and the static driver takes it as an optional parameter (full-frame when
omitted). On Apple the value goes to `VNImageRequestHandler.regionOfInterest` after the same Y-flip
(Vision's ROI is also bottom-left). **One Apple wrinkle:** Vision measures its text-height floor
against the ROI rather than the frame, so a narrower box picks up smaller text than the whole frame
does. Harmless while that floor stays 0, and it has to be divided out the day it isn't. On Android
the static one-shot **crops** the upright bitmap to the ROI, so ML Kit reads only that region, a
true crop (like iOS) that also isolates partial-line text. The **live** stream still runs full-frame
and drops lines whose box center falls outside the ROI (cropping every frame would cost too much). A
true YUV pre-crop there is a future optimization.

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
`FlutterTexture`, mirroring the Android `TextSightCamera`. The primary recognizer is Vision's **Swift
`RecognizeTextRequest`** (the WWDC 2024 API) with a legacy `VNRecognizeTextRequest` fallback for
iOS 15-17 (the hybrid, below). The **deployment floor is 15.0** (`text_sight.podspec` +
`Package.swift`). iOS 18+ runs the modern path, and a future macOS target would floor at 15.0 for it
(the same API's macOS availability).

**Why roll-your-own, not `DataScannerViewController`.** VisionKit's `DataScannerViewController`
(iOS 16+, A12+) is turnkey, but it is a UIKit view controller that **owns its own camera preview
and result overlay**. It cannot render into a `FlutterTexture`, so adopting it would force iOS onto
a `UiKitView` platform-view path while Android renders to a `Texture`, so the two platforms would
diverge structurally, and the unified contract already built and verified on Android (the captures
`EventChannel`, the consumer-supplied `overlayBuilder`, the normalized-`Rect` ROI, per-line
confidence) would not survive. There is also **no turnkey live-text equivalent on Android** to pair
it with: Google's turnkey, Play-services-delivered scanner UIs are the **Code Scanner** (barcodes
only) and the **Document Scanner** (a capture-crop-enhance flow returning an image/PDF, not a live
per-frame OCR stream). Live text on Android is always CameraX + ML Kit wired by hand. A turnkey
route would therefore be both a worse fit *and* asymmetric. Roll-your-own keeps one architecture
across platforms and shares a future macOS `darwin/` (Vision is identical there).

**Why the Swift `RecognizeTextRequest`, not `VNRecognizeTextRequest`.** It is the API Apple steers
new code toward (Swift concurrency / `async`-`await`, `Sendable`, value-typed
`RecognizedTextObservation`s), and it keeps this package on the vendor-forward stack, the same
posture that puts Android on CameraX + ML Kit v2 and that the whole no-bundling effort embodies (off
GoogleMLKit-on-iOS). It runs the **same** Vision text engine as the legacy request, so this is a
modernity / ergonomics choice, **not** an accuracy or capability gain. Same engine turned out not to
mean same defaults, though: the modern request ships with a text-height floor and the legacy one
does not, so the same photo read on iOS 17 and came back empty on 18+. Both now set every knob
rather than inheriting one. `topCandidates(1)` confidence and a normalized `regionOfInterest` both
carry over. The modern API *was* an iOS 18 floor, the hybrid below recovers iOS 15-17 through the
legacy request while iOS 18+ keeps the modern path.

**Backwards-compatible hybrid (iOS 15-17), as built (issue #5).** The floor is **15.0**, raised
from the original 13.0 once Flutter 3.47 made 15 its own minimum, leaving 13 and 14 unreachable. A
`TextRecognizer` protocol abstracts two backends: `ModernTextRecognizer` (`@available(iOS 18, *)`,
the Swift `RecognizeTextRequest`) and `LegacyTextRecognizer` (`VNRecognizeTextRequest`, iOS 15-17,
*not* deprecated), and `TextRecognizerFactory.make()` is the **single** `#available(iOS 18, *)`
site, resolved once at `TextSightCamera` init (kept out of the ~30 fps path). Both backends emit the
identical neutral `RecognizedLineData`, so the captures-`EventChannel` map and the Y-flip stay shared
Only request construction and observation-mapping differ (the modern path uses
`NormalizedRect.toImageCoordinates(_:origin:.upperLeft)`. The legacy path flips lower-left→top-left
as `1 - maxY`, [#coordinate-normalization](#coordinate-normalization)). **iOS 18+ devices pay
nothing:** they take the same `RecognizeTextRequest` path as before, `#available` is one cached
OS-version compare (not a per-frame tax), and the legacy code never runs there. The legacy `perform`
is *synchronous*, so it runs on a dedicated serial queue bridged to `async` via a continuation, never
blocking the cooperative pool.

**Lowering the floor was *not* recognizer-only: the rotation gotcha (option C).** Dropping below 18
also exposed `AVCaptureDevice.RotationCoordinator` (iOS 17+) in the *capture* pipeline, and the earlier
"only the recognizer-construction site branches" guess was wrong. Rather than carry a second rotation
pipeline (the pre-17 `UIDevice` / `videoOrientation` path) for a device population we **do not expect
in practice**: iOS 15-16 is a vanishing slice by 2026, and most iOS-17-capable devices also run 18, so
the coordinator is gated `@available(iOS 17, *)` and on iOS 15-16 rotation is simply **not tracked**
(`currentRotationAngle` stays 0): basic, un-rotated *live* capture (the one-shot is unaffected, since it
reads EXIF). Recognition still works, and the live preview just won't follow device rotation. This
degraded fallback (**option C**) was chosen for near-free 15-16 reach at low maintenance. The full
pre-17 rotation path (**option A**) is **deferred until real bug reports from actual 15-16 users
justify it** (caveated in the [README](./README.md)). Cross-ref: [#channel-topology](#channel-topology).

---

<a id="model-readiness"></a>
## Model readiness and the bundled / unbundled axis (Android)

**Decision.** The on-device recognition model loads **lazily and under app control**, never on the
app-startup path, and whether it is **bundled or unbundled** is a build-time choice. Two orthogonal
axes, settled 2026-06-22:

- **Runtime readiness: `TextSightModel.ensureReady()` + `TextSightModel.readiness`.**
  Mode-agnostic: both the live and one-shot drivers recognize through the same model, so the API sits
  on neither driver but on its own `TextSightModel` namespace. `ensureReady()` resolves to a terminal
  `TextSightReadinessState` (`ModelReady` / `ModelUnavailable`), and `readiness` streams
  `ModelDownloading(progress)` in between. The app calls it when entering an OCR feature, so model
  loading is backgrounded rather than blocking launch.
- **Build-time bundling: the `com.lahaluhem.text_sight.useBundled` gradle flag.** Default unbundled
  (~260 KB/script, fetched via Google Play Services), and `=true` bundles the model into the APK
  (~4 MB/script/arch, instant + offline). The ML Kit Kotlin API is identical across the two
  artifacts, so the switch is a pure dependency swap in `android/build.gradle.kts`, and the recognizer
  code (`TextSightCamera`) is untouched.

**Why two axes, not one.** Bundling is a packaging decision the *app developer* makes once, at build
time, the only place an Android dependency-variant switch can live, so it is a `gradle.properties`
flag (the mechanism `mobile_scanner` uses, inverted because our default is unbundled). Borrowing that
*mechanism* does not make the Dart API a `mobile_scanner` clone. The readiness API is designed on its
own terms. Readiness is a *runtime* concern the app drives per session. The two interact but are not
the same lever: with the bundled model `ensureReady()` resolves instantly (the model is in the APK),
with the unbundled model it may download. The Kotlin side learns which from `BuildConfig.USE_BUNDLED`
(fed by the flag) and short-circuits to ready when bundled.

**Why lazy-by-default, with no install-time prefetch.** ML Kit's unbundled model has three delivery
paths: an install-time `com.google.mlkit.vision.DEPENDENCIES` manifest meta-data, an explicit
`ModuleInstallClient` download, or download-on-first-use. The plugin's `AndroidManifest.xml`
deliberately **omits** the meta-data: it merges into *every* consumer, so it would force an
OCR-model download at install for apps that may never use the feature, the opposite of lazy. The
default is therefore download-on-first-use, with `ensureReady()`, backed by `ModuleInstallClient`
(`areModulesAvailable` → `installModules` + an `InstallStatusListener` for progress), as the
app-controlled trigger. A consumer that genuinely wants eager prefetch re-adds the meta-data in their
own app manifest. (Removing the meta-data is a behavioural change from the prior build, not an API
one: first use now downloads instead of install time.)

**Failure is a state, not a throw.** The unbundled model needs Google Play Services, absent on
GMS-less / offline devices, and a download can fail. Both surface as `ModelUnavailable` with a typed
`reason` (`playServicesUnavailable` / `downloadFailed`), a state the consumer renders rather than a
crash ([hard rule 11](.ai/AGENTS.md#hard-rules)). None of it applies on iOS: Vision is a system
framework, so readiness is always `ModelReady` and `ensureReady()` is an instant no-op.

**Transport reuses the existing split** ([#channel-topology](#channel-topology)). `ensureModelReady()`
is one `@async` Pigeon control method returning the terminal-state map, and `readiness` is a plain
`EventChannel` (`com.lahaluhem.text_sight/readiness`) of self-describing maps, hand-decoded into the
sealed `TextSightReadinessState` exactly as the captures stream decodes into `TextSightCapture`. The
sealed type is **hand-written public Dart, never generated**, which is why a sealed result type did
*not* push the package onto Golubets (that analysis lives in [#channel-topology](#channel-topology)).

**The no-bundling contract is untouched.** That rule ([#no-bundling](#no-bundling)) is iOS-only, so no
third-party ML library in the *Apple* build. Android bundled-vs-unbundled is a separate, legitimate
axis: ML Kit is declared only in `android/build.gradle.kts` either way, and the bundled artifact
never reaches the Dart `pubspec.yaml`.

---

<a id="federation-deferred"></a>
## Federation deferred: one plugin package for v1

> _Stub, to be written if/when federation is reconsidered._
>
> Will document why v1 is a **single plugin package** declaring all platforms, rather than
> a federated set (`text_sight_platform_interface` + `text_sight_ios` +
> `text_sight_android`). Federation earns its complexity only when third parties add
> platforms or independent per-platform versioning is needed, and neither applies yet. The
> `plugin_platform_interface` dependency is already in place so the boundary can be drawn
> later without a disruptive restructure.

---

<a id="known-limitations"></a>
## Known limitations, performance, and deferred work

A running list of what v1 does *not* do well yet. The **active backlog is tracked as GitHub issues**
(<https://github.com/LahaLuhem/text_sight/issues>). What stays *here* is the permanent rationale that
isn't a backlog item:

**Platform capability differences (inherent, not bugs).** `recognitionLevel` and `languages` apply on
iOS (Vision) and are **no-ops on Android** (the ML Kit Latin recognizer exposes neither and reads
Latin only). Per-line `confidence` is supplied by both, but the scales are **not comparable**. These
are documented in the [README](./README.md), and they are engine properties, not defects.

**The two platforms capture different shapes, and cannot be matched.** Android runs 4:3, the
sensor's own shape. iOS has no 4:3 HD preset, so it runs 16:9. Forcing Android to match would crop
away page for nothing. `CaptureResolution` picks the size, the shape stays the platform's.

**Background auto-pause (both platforms).** The live session stops itself when the app leaves the
foreground and restarts on return, torch intent re-asserted. Rationale: both OSes forcibly gate the
camera for backgrounded apps anyway (iOS interrupts the session, Android revokes the camera from
idle UIDs), so leaning on that meant inheriting OS-owned recovery timing and a torch that silently
stayed off after return. Android derives the headless session owner's state from
`ProcessLifecycleOwner` capped by the session's intent, and iOS listens for the background/foreground
notifications and stops/starts the `AVCaptureSession` on its session queue.

**Federation is deferred (and likely unneeded).** v1 ships as one package, and the split into a
platform-interface package + per-platform implementations is only worth it if third parties add
platforms ([#federation-deferred](#federation-deferred)). Not tracked as an issue, so revisit only if
that need actually arises.

---

<a id="taskqueue-rejected"></a>
## `@TaskQueue` on the control channel: measured, rejected for now

`@TaskQueue(type: TaskQueueType.serialBackgroundThread)` moves a host method's message decode off the
platform thread. Attractive for `recognizeImage`, the one control method carrying a real payload. It
was measured on both platforms and **not kept**: it helps Android, clearly hurts iOS, and the
annotation is per-method with no per-platform form.

Measured by `example/integration_test/platform_thread_bench_test.dart`, which pings the synchronous
`checkCameraPermission` while 40 undecodable 8 MiB payloads cross the channel, so the number is the
channel hop and not inference. Read `p50` only, since `max` swings 2.4x run to run.

Criterion, fixed before the after-run: loaded `p50` at or under 300 us in two of three runs.

| Platform | baseline loaded `p50` | with `@TaskQueue` |
|---|---|---|
| Android emulator | 524 / 669 / 459 us | **216 / 233 / 319 us** |
| iOS simulator | 110 / 104 / 113 / 124 / 116 / 115 us | **33 / 95 / 2295 / 2483 / 2553 / 2632 us** |

Android's ranges do not overlap. iOS goes from tight and unimodal to bimodal, four of six runs about
20x worse. Six runs a side because the first iOS run (33 us) looked like a win and was not. Why iOS
degrades is unconfirmed, possibly contention on the serial queue `makeBackgroundTaskQueue` returns.

**What would change the answer.** Per-platform annotation support, a different payload profile (the
effect is payload-driven, so `recognizePath` and `ensureModelReady` were never candidates), real
hardware instead of an emulator and simulator, or an upstream fix on the iOS side. `initialize` and
`dispose` stay out regardless: they touch the texture registry and CameraX `LiveData`, which reject
non-main threads.

---

<a id="public-api-via-single-export-file"></a>
## Public API funnelled through `lib/text_sight.dart`

**Decision.** `lib/text_sight.dart` is the only file consumers import. It holds
`export 'src/…';` lines and nothing else. Every implementation file lives under `lib/src/`, and
is private by convention. Dart has no hard public/private boundary below `lib/`, so this funnel
is how the ecosystem signals private intent, and it gives one file to audit before a release.
Moving code *within* `lib/src/` is free, but moving a symbol into or out of the re-export list is
semver-visible (minor to add, major to remove or change a signature). Prefer `show` over `hide`
if a partial export ever becomes necessary.

**Layering.** Both drivers funnel down through one federation seam:

```
PUBLIC   barrel re-exports: TextSightController · TextSightView · TextSight (one-shot)
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

**Module layout (`lib/src/`).** The recognizer is the core, and capture is a seam, not a mode flag.
The directories make that physical:

```
lib/
├── text_sight.dart                   barrel: export 'src/…'; only
└── src/
    ├── recognition/                  capture-agnostic CORE: result models + recognizer config
    │   ├── text_sight_capture.dart
    │   ├── recognized_line.dart
    │   ├── recognized_element.dart
    │   ├── recognition_level.dart
    │   └── text_sight_options.dart
    ├── capture/                       the two DRIVERS over the one recognizer
    │   ├── text_sight_controller.dart    live-camera driver (v1)
    │   └── text_sight.dart               TextSight one-shot static driver
    ├── view/
    │   └── text_sight_view.dart          Texture-backed widget (+ overlay painter later)
    └── platform/
        ├── text_sight_platform.dart      the federation seam
        └── messages.g.dart               generated control channel (later; never hand-edited)
```

`recognition/` holds only capture-agnostic types, and `capture/` puts both drivers
(`TextSightController` live, `TextSight` one-shot) together so the "one recognizer, two drivers"
seam shows in the tree. Each public type gets its own file (per
[`CODESTYLE.md#naming`](./CODESTYLE.md#naming)).

**Result-model contracts.** The capture-agnostic types the barrel exposes:

- **`RecognizedLine.confidence` is `double?`, range `[0,1]`.** Both engines supply a per-line
  confidence: Apple Vision, and (re-verified for the pinned `play-services-mlkit-text-recognition`
  19.0.1) ML Kit v2 via `Text.Line.getConfidence()`. It is `null` only when the engine omits one
  for a given line, and the two scales are **not guaranteed comparable** across platforms, nor, on
  iOS, across versions: the modern `RecognizeTextRequest` (18+) reports **coarse** confidence
  (frequently `1.0`), whereas the legacy `VNRecognizeTextRequest` (15-17) is **graded**, so the same
  image read on an iOS 15 device scored `~0.5` for lines the iOS 18+ path scored `1.0`
  (device-verified). `null`
  means **"not supplied,"** *not* "low confidence", so never synthesize a value to fill it. A
  consumer thresholding picks an explicit default (`(line.confidence ?? 1) >= min`) and never
  compares `null` to a bound.
- **`RecognizedLine.elements` is a reserved `List<RecognizedElement>?`.** Word-level elements
  are part of the model shape from v1 but stay **`null` until the feature ships**, so
  populating them later is an additive minor, not a breaking change. `RecognizedElement` is
  intentionally minimal: `text` · `boundingBox` · `confidence?`, the same contract as a line,
  one level down.
- **Both result types are capture-agnostic, immutable, and `const`-constructible**, with
  `toString`. They hold their lists directly, with no defensive copy, since a `const` instance is
  passed a `const` (immutable) list (see
  [`CODESTYLE.md`](./CODESTYLE.md#listunmodifiable-over-unmodifiablelistview)).

**Configuration.** One config type, reused across both drivers:

- **`TextSightOptions` is the one source-agnostic recognizer config**: `level` · `languages` ·
  `roi`, accepted by *both* drivers. The live driver takes it on `TextSightController`, and the
  static one-shot takes it per call, defaulting `level` to `.accurate` where the live default is
  `.fast`. Not a per-driver duplicate. `languages` is `Iterable<Locale>`, not raw BCP-47 strings,
  a closed enum would misstate a platform- and OS-version-dependent capability, so the type
  stays structured-but-open and maps to tags via `Locale.toLanguageTag()` at the seam.
- **`torchEnabled` is a controller-only parameter, deliberately *not* in `TextSightOptions`.**
  Torch is a live-session concern and a static image has none, so folding it into the shared
  recognizer config would be a category error. The seam, expressed in the type system:
  recognizer config is shared across drivers, session config is not.
- **`roi` is a `Rect`** in normalized `[0,1]` top-left space (the same type as the output
  boxes, not a bespoke twin), and its range is validated by a debug `assert` at the controller
  (the `const` `TextSightOptions` can't run a check in its own constructor). See
  [#coordinate-normalization](#coordinate-normalization).

**The static one-shot is a separate driver, not a session mode.** `TextSight.recognizeImage` /
`.recognizePath` return a `Future<TextSightCapture>` and need no controller, camera permission,
texture, or session. They share only the recognizer and result models with the live path, and ride
the `@HostApi` ([#channel-topology](#channel-topology)).

---

<a id="android-standalone-dev"></a>
## Developing the Android module standalone in Android Studio

**Decision.** The plugin's `android/` carries a little **standalone-development scaffolding** so it
can be opened directly in Android Studio (`File > Open > android/`) with full symbol resolution,
including `io.flutter.*`. This is *not* Flutter's default plugin layout. `flutter create
--template=plugin` produces an `android/` that resolves only inside an app build. The additions:

- **`android/settings.gradle.kts`**: a `pluginManagement {}` block pinning the AGP version, so
  `plugins { id("com.android.library") }` resolves when `android/` is the Gradle root. (No Kotlin
  plugin. Standalone uses AGP 9's built-in Kotlin, see the migration note below.)
- **`android/gradle.properties`**: `useAndroidX` + JVM args only. (No `newDsl`/`builtInKotlin`
  opt-out flags, and the standalone build runs AGP 9's built-in Kotlin + new DSL.)
- **`android/build.gradle.kts`**: an `if (project == rootProject)` block that adds the Flutter
  engine embedding (`io.flutter:flutter_embedding_debug:1.0.0-<engine.version>`) as `compileOnly`
  plus `testImplementation`, reading the version from the pinned SDK so it tracks the channel rather
  than being hardcoded. Both configurations are needed: `compileOnly` covers the main source set
  only, so without the second the unit tests cannot resolve `io.flutter.*` and the standalone build
  fails to compile them.
- the **Gradle wrapper** (`gradlew`, `gradle/wrapper/`).

**Why Flutter doesn't do this for you.** A plugin's `android/` is a library module that Flutter only
ever builds as a *subproject* of a host app (`FlutterAppPluginLoaderPlugin` does
`settings.include(":<plugin>")`). In that context the app supplies AGP/Kotlin, so the plugin's
`settings.gradle.kts` is ignored as a subproject, and `dev.flutter.flutter-gradle-plugin`, applied
**only by apps**, injects the engine. So Flutter's supported way to develop plugin native code is to
open **`example/android`**, where everything resolves out of the box. The bare `android/` folder is
off that path: nothing provides `io.flutter`, and the engine is versioned by hash and meant to come
from the consuming app, so the template declares neither AGP versions nor the engine. Making it
resolve standalone requires coupling to a specific engine version (the `engine.version` read above),
which Flutter avoids baking into every generated plugin.

**Why it's safe for consumers.** Every addition is read **only when `android/` is the Gradle root**:
a subproject's `settings.gradle.kts` and root `gradle.properties` are ignored in an app build, and
the engine block is guarded by `project == rootProject` (false in-app). The whole lot is also
excluded from the published package via [`.pubignore`](./.pubignore), and a consuming app builds the
plugin with its own Gradle and never sees it. Both paths are verified to compile `lib` + the unit
tests: `example/android` (in-app) and `android/` standalone, with the engine resolving standalone
and the guard skipping it in-app.

**Wrapper hygiene.** The wrapper is committed (standard Gradle practice, since it pins the Gradle version
for reproducible builds, see the `!/gradle/wrapper/gradle-wrapper.jar` un-ignore in
`android/.gitignore`) but `.pubignore`d, so contributors get zero-setup standalone builds while the
tarball stays lean. `android/local.properties` (gitignored) must set `flutter.sdk` for the engine to
resolve standalone, and the build logs a one-line hint if it's missing (app builds never need it).

**AGP 9 built-in Kotlin, standalone only.** The standalone build runs AGP 9's **built-in Kotlin +
new DSL**: no `org.jetbrains.kotlin.android` plugin, no `builtInKotlin`/`newDsl` opt-out flags, and
no `sourceSets { java.srcDirs("src/main/kotlin") }` block (AGP 9 includes `src/main/kotlin` /
`src/test/kotlin` by default). This clears the AGP-9 deprecation warnings (`android {}` legacy
extension, `kotlin.android` "no longer required", the opt-out flags) **in the standalone window**.
The **example app cannot follow**: Flutter 3.44's `flutter build` migrator actively re-adds
`android.builtInKotlin=false` / `android.newDsl=false` to `example/android/gradle.properties` on
every build, so the in-app build, and its AGP-9 deprecation warnings, stays on legacy AGP until
Flutter itself migrates. The shared `build.gradle.kts` works in both contexts: built-in Kotlin
standalone, and AGP's legacy auto-apply of `kotlin.android` (using the example's pinned Kotlin
version) in-app. One consequence of the new DSL: `junit-platform-launcher` must be declared
explicitly on the test runtime classpath for `useJUnitPlatform()`, since the legacy DSL provided it
implicitly.

**`compileSdk` = latest *stable*, never preview.** `build.gradle.kts` pins `compileSdk = 36` (Android
16, Flutter 3.44's `flutter.compileSdkVersion` default), not a newer/preview level. AGP records a
library's `compileSdk` as the AAR's **`minCompileSdk`**, forcing every consumer to compile against at
least that, and since pub.dev ships this plugin as **source**, a higher value would also require
consumers to have that SDK platform installed, hard-breaking stock-Flutter apps. AGP ≥ 9.2 *enforces*
this (9.0 silently skipped it, which is how the example built before). This is the one spot where the
vendor-forward instinct misfires: it governs the plugin's own API floor (and `minSdk`), not the
compileSdk imposed on downstream apps. CameraX + ML Kit need nothing past stable 36.

**AGP 9.2.1 on Gradle 9.6.0, no configuration cache (yet).** Both contexts run AGP 9.2.1, which
requires Gradle ≥ 9.4.1 (so the example wrapper moved 9.1.0 → 9.6.0 to match standalone). Two known
non-fixables, both upstream: the *"Project object as a dependency notation"* Gradle-10 deprecation
comes from AGP's own `VariantDependenciesBuilder` (test-variant wiring, still present in the latest
stable, harmless until Gradle 10), and **configuration cache stays off** because AGP 9.2.1's
`JdkImageInput` (javac system-modules) isn't CC-serializable under Gradle 9.6, so a strict-mode CC build
fails storing the entry. Both are AGP's to fix, so re-evaluate when next bumping AGP.

**Cost / fallback.** Off the supported path, the setup tracks the engine version (automatically, via
`engine.version`) and ships a few `.pubignore`d dev-only files, in exchange for a lean plugin-only
IDE window instead of the full example app. If it ever becomes a maintenance drag, the fallback is
the supported path: delete the scaffolding and open `example/android`.
