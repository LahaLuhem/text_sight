<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [`AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`](#agentsmd-and-claudemd-are-symlinks-into-ai)
- [No-bundling: native dependencies never touch the Dart `pubspec.yaml`](#no-bundling-native-dependencies-never-touch-the-dart-pubspecyaml)
- [Channel topology: Pigeon control API + `EventChannel` results + `Texture` preview](#channel-topology-pigeon-control-api--eventchannel-results--texture-preview)
- [Coordinate normalization: top-left `[0,1]` in native code](#coordinate-normalization-top-left-01-in-native-code)
- [Federation deferred: one plugin package for v1](#federation-deferred-one-plugin-package-for-v1)
- [Public API funnelled through `lib/text_sight.dart`](#public-api-funnelled-through-libtext_sightdart)

<!-- TOC end -->

Consolidated source of truth for design decisions, rejected paths, and non-obvious
technical trade-offs.

READMEs, [`CODESTYLE.md`](./CODESTYLE.md), and [`.ai/AGENTS.md`](./.ai/AGENTS.md)
reference sections here by anchor (e.g. `APPENDIX.md#no-bundling`).

> **Status (repo-init):** the [symlink section](#ai-files-symlinked) below is final. The
> remaining sections are **stubs** — each decision is already locked by the build spec,
> but the full rationale is written as the corresponding implementation lands, so we
> never document reasoning for code that doesn't exist yet. The anchors are stable now
> (other docs already link to them); only the bodies grow.

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
> platform" corollary, and the verification recipe (`rg -i 'mlkit' Podfile.lock` → no
> matches). Cross-refs: [`CODESTYLE.md#swift-ios-macos`](./CODESTYLE.md#swift-ios-macos),
> [`CODESTYLE.md#kotlin-android`](./CODESTYLE.md#kotlin-android), and the hard rules in
> [`.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules).

---

<a id="channel-topology"></a>
## Channel topology: Pigeon control API + `EventChannel` results + `Texture` preview

**Decision.** Three concerns ride three different transports, deliberately, rather than being
funnelled through one channel:

- **Control + the one-shot recognize → typed codegen `@HostApi`.** The control surface
  (`initialize` / `start` / `stop` / `setRegionOfInterest` / `setRecognitionLevel` /
  `setLanguages` / `toggleTorch` / `dispose`) is request/response and benefits from a
  generated, type-checked Dart↔native boundary. The static one-shot (`recognizeImage` /
  `recognizePath`, when that driver lands) is *also* request/response, so it rides the **same**
  `@HostApi` as an `@async` method returning a `TextSightCapture` — not the results stream
  below. Natively it allocates a transient image handler and touches no camera session,
  texture, or event sink. _(Which codegen tool — Pigeon or Golubets — is settled in the next
  step; both are dev-time-only with zero runtime or bundling impact, so this topology holds
  either way.)_
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

**Generated code is committed and never hand-edited.** `messages.g.dart` is checked in (so
consumers and CI need no codegen step) and regenerated from the schema, never patched — see
[hard rule 7 in `.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules). The bounding-box geometry these
channels carry is specified in [#coordinate-normalization](#coordinate-normalization).

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

**Region-of-interest uses the same contract.** `RegionOfInterest` is a normalized `[0,1]`
top-left rect (the same space as the output boxes), not pixels — which is *why* it is a
dedicated value type with a positive-extent `assert`, not a bare `Rect` that would read as
pixels. Because ROI is part of the source-agnostic recognizer config it applies uniformly: the
live driver sets it via the controller; the static driver takes it as an optional parameter
(full-frame when omitted). On Apple the value goes to `VNImageRequestHandler.regionOfInterest`
after the same Y-flip (Vision's ROI is also bottom-left); on Android the frame is cropped to
the ROI before recognition.

**Orientation is an input, not an afterthought.** Recognition silently degrades if it is
wrong: the Apple side must pass the correct `CGImagePropertyOrientation`, the Android side the
`ImageProxy`'s `rotationDegrees`. The normalization above assumes the image has already been
interpreted in its display orientation. Cross-refs:
[#channel-topology](#channel-topology) (the transport that carries these boxes) and
[#public-api-via-single-export-file](#public-api-via-single-export-file) (the `RecognizedLine`
and `RegionOfInterest` types).

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
         · RecognitionLevel · RegionOfInterest · TextSightOptions
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
    │   ├── region_of_interest.dart
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

`recognition/` holds only capture-agnostic types — they carry no notion of where the pixels
came from. `capture/` puts the two drivers physically together so the "one recognizer, two
drivers" seam is visible in the tree: `TextSightController` streams live frames; `TextSight`
recognizes a single still; both delegate to the same platform surface. Each public type gets
its own file named after it (per [`CODESTYLE.md#naming`](./CODESTYLE.md#naming)).

**Result-model contracts.** The capture-agnostic types the barrel exposes:

- **`RecognizedLine.confidence` is `double?`, range `[0,1]`.** Apple Vision supplies a per-line
  confidence; ML Kit's public API does not surface a reliable per-line equivalent (to be
  re-verified against the pinned recognizer version when the Android side lands). `null` means
  **"this platform did not supply one,"** *not* "low confidence" — never synthesize a value to
  fill it. A consumer thresholding picks an explicit default (`(line.confidence ?? 1) >= min`)
  and never compares `null` to a bound. The nullable type also future-proofs the contract: if
  Android starts supplying confidence later, `null → value` is non-breaking.
- **`RecognizedLine.elements` is a reserved `List<RecognizedElement>?`.** Word-level elements
  are part of the model shape from v1 but stay **`null` until the feature ships**, so
  populating them later is an additive minor, not a breaking change. `RecognizedElement` is
  intentionally minimal — `text` · `boundingBox` · `confidence?`, the same contract as a line,
  one level down.
- **Both result types are capture-agnostic and immutable**, override `toString`, and expose
  their collections via `List.unmodifiable` so a callback can neither mutate the package's
  frame state nor be mutated out from under another consumer.

**Configuration.** One config type, reused across both drivers:

- **`TextSightOptions` is the one source-agnostic recognizer config** — `level` · `languages` ·
  `roi` — accepted by *both* drivers. The live driver takes it on `TextSightController`; the
  static one-shot takes it per call, defaulting `level` to `.accurate` where the live default is
  `.fast`. Not a per-driver duplicate.
- **`torchEnabled` is a controller-only parameter, deliberately *not* in `TextSightOptions`.**
  Torch is a live-session concern; a static image has none, so folding it into the shared
  recognizer config would be a category error. The seam, expressed in the type system:
  recognizer config is shared across drivers, session config is not.
- **`RegionOfInterest` is a dedicated normalized value type** (with a `fromLTWH` convenience),
  not a `Rect` — see [#coordinate-normalization](#coordinate-normalization) for why the
  normalized-vs-pixel distinction earns its own type and its `assert`.

**The static one-shot is a separate driver, not a session mode.**
`TextSight.recognizeImage` / `.recognizePath` (near-term) return a `Future<TextSightCapture>`
and require **no** `TextSightController`, camera permission, texture, or live session. They
share the recognizer and the result models with the live path and nothing else — the
embodiment of "capture-source is a seam, drivers over one recognizer." They ride the `@HostApi`
rather than the results stream; see [#channel-topology](#channel-topology).
