# AGENTS.md: `text_sight`

Tool-agnostic brief for any coding agent (Copilot, Cursor, Codex, Claude Code, …) working
in this package. Claude-Code-specific guidance lives in [CLAUDE.md](./CLAUDE.md).

## Project goal

A Flutter plugin for live, on-device text recognition: Apple Vision on iOS, ML Kit on
Android. The text-scanning sibling to
[`mobile_scanner`](https://pub.dev/packages/mobile_scanner). Two entry points: a live
camera widget (`TextSightView` + `TextSightController`) and a one-shot static call
(`TextSight.recognizeImage`/`.recognizePath`).

The gap it fills: existing live + cross-platform OCR wrappers run ML Kit on iOS too,
which drags `GoogleMLKit` pods into the iOS build and trips the arm64 /
Swift-Package-Manager deprecation warnings on Apple-Silicon simulators. `text_sight` uses
each platform's native engine, so **iOS links zero third-party ML libraries** (Apple
Vision is a system framework) while Android keeps ML Kit (fine there). This isolation is
the package's reason to exist. See [`APPENDIX.md#no-bundling`](../APPENDIX.md#no-bundling).

- **pub id:** `text_sight`. **Brand/title:** TextSight. **Class prefix:** `TextSight*`
  (`TextSight`, `TextSightController`, `TextSightView`, `TextSightCapture`).
- **pub.dev topics:** `ocr`, `text-recognition`, `vision`, `mlkit`, `camera`.

## Stack

- **It's a plugin, not a pure package**: it needs native code (Swift/Vision,
  Kotlin/ML Kit). One plugin package declares both platforms, and splitting it per platform is
  deferred ([`APPENDIX.md#federation-deferred`](../APPENDIX.md#federation-deferred)).
- **Flutter and Dart floors** are pinned in `pubspec.yaml`, and `.fvmrc` pins the Flutter
  channel for local use. They comfortably clear the Dart 3.10 static-dot-shorthand floor the
  code style leans on.
- **iOS, Swift**, using the system frameworks Vision + AVFoundation (+ CoreMedia / CoreVideo).
  `AVCaptureSession` feeds a `TextRecognizer`: Vision's Swift `RecognizeTextRequest` on iOS 18+,
  the older `VNRecognizeTextRequest` on iOS 15-17, picked once by a factory. The preview goes to a
  `FlutterTexture`. The floor is iOS 15.0 (Flutter's own since 3.47), and iOS 15-16 don't follow
  rotation, having no `RotationCoordinator`
  ([`APPENDIX.md#ios-capture-strategy`](../APPENDIX.md#ios-capture-strategy)). Ships through
  SwiftPM only (`ios/text_sight/Package.swift`), since CocoaPods is going read-only (hard rule 2).
- **Android, Kotlin**, using CameraX + ML Kit text recognition. `ImageAnalysis`
  (`STRATEGY_KEEP_ONLY_LATEST`) feeds a `TextRecognition` client, and the preview goes to a
  `Texture`. ML Kit + CameraX are declared only in `android/build.gradle.kts`, and the module stays
  on Flutter's built-in Kotlin (hard rule 3).
- **Channel topology** ([`APPENDIX.md#channel-topology`](../APPENDIX.md#channel-topology)):
  the control calls are Pigeon codegen (`@HostApi`). Per-frame results stream over a plain
  `EventChannel`, the camera preview is a `Texture`, and session state and preview geometry come
  back over a Pigeon `@FlutterApi`. Pigeon is a dev dependency, so it costs consumers nothing at
  runtime.
- **Two generators, one freshness gate.** Pigeon writes the wire types, `copy_with_extension_gen`
  writes `copyWith` for the public value types. Both outputs are committed, and CI's
  `codegen` job regenerates and fails if anything differs, so neither can drift from its
  source.
- **`dart analyze --fatal-infos --fatal-warnings .`**, as CI runs it. The lints are strict on
  purpose (`strict-casts` / `strict-inference` / `strict-raw-types` + the `errors:` block in
  [dartender's shared lints](https://github.com/LahaLuhem/dartender/blob/main/lints/lib/analysis_options.yaml),
  which `analysis_options.yaml` includes). **`flutter_test`** for Dart tests. detekt and SwiftLint
  gate the native code in `plugin.yml`, and the rest of their conventions are applied by hand
  ([`CODESTYLE.md`](../CODESTYLE.md)).
- **Published to pub.dev.** `.pubignore` controls the tarball. `CHANGELOG.md`, the
  `version:` field in `pubspec.yaml`, and the release tag move together in the Release run,
  which the user starts from the Actions tab (see
  [dartender's Releasing](https://github.com/LahaLuhem/dartender#releasing)). It also adds
  Dependabot's CHANGELOG lines. Every other line is bot-appended on merge
  (`.github/workflows/changelog.yml` via `cider`), one per PR with a `sem-*` label other than
  `sem-skip`. No manual `flutter pub publish`.

## Repo layout

```text
text_sight/
├── pubspec.yaml             Deps: flutter, plugin_platform_interface, meta, copy_with_extension,
│                            NO recognition lib (dev: Pigeon + build_runner codegen, test tooling)
├── pigeons/text_sight.dart  Pigeon schema for the typed control API (@HostApi)
├── lib/
│   ├── text_sight.dart            Public entry, only `export 'src/…';` lines
│   └── src/                       Private by convention, one public type per file
│       ├── options/               Data: TextSightOptions, DarwinOptions (Vision only), the enums
│       ├── results/               Data: TextSightCapture, RecognizedLine, ConfidenceScale
│       ├── states/                Data: session, readiness and permission states
│       ├── camera/                Live: TextSightController + TextSightView
│       ├── recognition/           One-shot TextSight, TextSightModel, TextSightEngine
│       └── platform/              text_sight_platform.dart (the platform seam) +
│                                  messages.g.dart (GENERATED by Pigeon, never hand-edit)
├── ios/                     iOS plugin (Swift + Vision + AVFoundation)
│   ├── text_sight/Package.swift  SwiftPM manifest, whose one dependency is swift-async-queue
│   ├── .swiftlint.yml            SwiftLint for the plugin Swift (RunnerTests: example/ios/.swiftlint.yml)
│   └── text_sight/Sources/text_sight/   AVCaptureSession + Vision, in concept folders
├── android/                 Android plugin (Kotlin + CameraX + ML Kit)
│   ├── build.gradle.kts          ML Kit + CameraX deps live ONLY here, built-in Kotlin
│   ├── detekt.yml                detekt config (deviations only, run from the repo root)
│   └── src/main/kotlin/com/lahaluhem/text_sight/   CameraX + ML Kit, same concept folders
├── example/                 Runnable demo, also the no-bundling test harness
├── analysis_options.yaml    Includes dartender's shared lints
├── .pubignore               Files excluded from `flutter pub publish`
├── .editorconfig            Text-file conventions (Dart 2 / Swift 2 / Kotlin 4 / shell 2 / …)
├── .fvmrc                   FVM channel pin
├── .github/workflows/       CI: dartender's callers (ci, codegen, conventions, changelog,
│                            release, publish) + this repo's plugin.yml
├── CHANGELOG.md             Release log (bot-appended on merge, finalised by the Release run)
├── README.md                pub.dev landing page (hook line + topics)
├── APPENDIX.md              Design rationale (anchor-keyed)
├── CODESTYLE.md             Plugin-package code style (Dart + Swift + Kotlin)
└── .ai/                     This file + CLAUDE.md (symlinked at root)
```

Where a new file goes, on all three platforms:
[`CODESTYLE.md#source-file-organization`](../CODESTYLE.md#source-file-organization).

**Platform support is iOS + Android**: the only platforms declared in `pubspec.yaml`'s
`plugin:` block. Adding another platform target is an explicit-conversation change (hard
rule 13).

## Hard rules

1. **No-bundling: recognition libraries never enter the Dart `pubspec.yaml`.** The load-bearing
   rule. ML Kit + CameraX are declared **only** in `android/build.gradle.kts`, and iOS recognizes
   and captures with system frameworks (rule 2). The Dart `pubspec.yaml` declares only `flutter`,
   `plugin_platform_interface` and pure-Dart helpers (`meta`, `copy_with_extension`). **Never add
   `camera`, `google_mlkit_*` or any recognition package as a Dart dependency**:
   `flutter_scalable_ocr`'s iOS podspec dragging in GoogleMLKit is the exact mistake this package
   exists to avoid. See [`APPENDIX.md#no-bundling`](../APPENDIX.md#no-bundling).
2. **Ship through `Package.swift` only, and recognize and capture with Apple's own
   frameworks.** No podspec, since CocoaPods is going read-only. The bar is *prefer-native*, not
   *zero-dependency*: **never** add a recognition or camera library, or anything that duplicates a
   system framework (`Vision`, `AVFoundation`). A small, maintained SPM library is fine where it
   leaves less code here, even when a native route exists, since code is a liability.
   swift-async-queue, which orders the pushes to Dart, is the one so far.
3. **The Android module stays on built-in Kotlin.** Use Flutter's Gradle `plugins {}` DSL,
   never the legacy `apply plugin: 'kotlin-android'` + buildscript classpath, since the legacy
   path emits the KGP deprecation warning this package is fighting.
4. **Normalize coordinates to top-left `[0,1]` in native code.** Vision gives normalized
   bottom-left boxes, ML Kit gives pixel boxes in the upright image, and Flutter wants top-left
   normalized. Convert on each native side so the Dart overlay never branches. See
   [`APPENDIX.md#coordinate-normalization`](../APPENDIX.md#coordinate-normalization).
5. **Never queue frames, apply backpressure.** iOS: one recognition in flight, newest frame next
   (`FrameGate`), + `alwaysDiscardsLateVideoFrames`. Android: `STRATEGY_KEEP_ONLY_LATEST` **and**
   a mandatory `imageProxy.close()` once each task settles (`closeWhenSettled`), since the next
   frame isn't delivered until the current proxy closes. Run recognition off the platform main
   thread, and hop back to main for the `EventChannel` sink.
6. **The public API lives only in `lib/text_sight.dart`.** That barrel re-exports from
   `lib/src/`, and the `src/` subtree is private by convention. Don't make users import
   `package:text_sight/src/…`. See
   [`APPENDIX.md#public-api-via-single-export-file`](../APPENDIX.md#public-api-via-single-export-file).
7. **Generated code is never hand-edited.** Pigeon's `messages.g.dart` and `Messages.g.*` come
   from `pigeons/text_sight.dart` (`dart run tool/pigeon.dart`), and `darwin_options.g.dart` from
   build_runner. Regenerate, don't patch.
8. **No `print()` in library code.** Diagnostic output is the caller's responsibility.
   `avoid_print` is a warning in the shared lints.
9. **No `dynamic` escape hatches.** `strict-casts`, `strict-inference`, and
   `strict-raw-types` are all on. If you reach for `dynamic` or unconstrained `Object?`,
   stop and reconsider.
10. **Public symbols carry dartdoc.** `public_member_api_docs` is on. Every public class /
    widget / function / getter needs a `///` comment that explains *why*, not *what*.
11. **Surface permission/error states, never crash.** A denied camera permission, an
    unsupported platform, or a missing channel is a typed state/error the consumer can
    render, not an unhandled throw. Document `NSCameraUsageDescription` (iOS) and the
    `CAMERA` permission (Android) for consumers.
12. **Semver, strictly.** Breaking changes only on a major bump. Any change to a public
    signature (`TextSightController`/`TextSightView` constructor, a public model field), a
    deletion, or a behavioural change of a documented contract is breaking, so surface the
    implication before the diff lands.
13. **iOS + Android only.** The plugin declares only `android` and `ios`. Don't add
    another platform target (web, desktop) without an explicit conversation.
14. **`CHANGELOG.md`, `version:`, and the release tag move together, and are
    pipeline-owned.** Routine CHANGELOG appends are bot-driven (`changelog.yml` + `cider`).
    Cutting a release is the **Release** run. Don't hand-edit `CHANGELOG.md`, the `version:`
    field, or `example/pubspec.lock`, which Dependabot bumps too. After changing
    `example/pubspec.yaml`, run `flutter pub get` in `example/`. See
    [*Forbidden / confirm-first actions* in CLAUDE.md](./CLAUDE.md#forbidden-confirm-first-actions).
    The `cider:` block in `pubspec.yaml` is static config and may be hand-edited.

## PR conventions

The `.github/workflows/conventions.yml` workflow enforces branch-name, PR-label, and
commit-subject rules on every PR. On merge, `.github/workflows/changelog.yml` auto-appends
to `CHANGELOG.md` based on the PR's `sem-*` label (via `cider log`). **PRs that don't
comply are blocked by CI.**

- **Branch name**: `<type>/#<issue>-<slug>`, where `<type>` is one of `feature`,
  `bugfix`, `chore` or `refactor`. Example: `chore/#12-tidy-readme`.
- **Exactly one `sem-*` label per PR**, mapped to a CHANGELOG section:

  | Label           | CHANGELOG section | When to use                                     |
  |-----------------|-------------------|-------------------------------------------------|
  | `sem-add`       | `### Added`       | New public API / feature                        |
  | `sem-change`    | `### Changed`     | Behavioural or signature change                 |
  | `sem-deprecate` | `### Deprecated`  | Public symbol marked for future removal         |
  | `sem-remove`    | `### Removed`     | Previously-public symbol dropped                |
  | `sem-bugfix`    | `### Fixed`       | Defect repair, no signature change              |
  | `sem-security`  | `### Security`    | Security-relevant fix                           |
  | `sem-skip`      | (skip)            | Internal-only change (CI, docs, tests, native build glue, …) |

  The PR title becomes the CHANGELOG line verbatim, so write it as a release-note bullet.
- PR body must not be empty, no merge commits in the PR range (rebase to integrate
  `main`), and commit subjects ≤ 82 characters.

Cutting a release is one run: **Release** in the Actions tab, then the bump. It runs CI, moves the
version, the CHANGELOG and `example/pubspec.lock` together, and pushes the tag `publish.yml` picks
up. [dartender's Releasing](https://github.com/LahaLuhem/dartender#releasing) has the rest.

## Testing

Three test layers, three runners. Each covers only logic that runs off the device. The capture
and recognition pipeline itself (CameraX + ML Kit, AVCaptureSession + Vision) isn't unit-tested.

- **Dart** (`test/`): `flutter test`. The controller and the view against a fake platform, and
  the Pigeon platform against a mocked host.
- **Android native** (`android/src/test/`): `flutter build apk --config-only` in `example/`,
  then `./gradlew :text_sight:testDebugUnitTest` in `example/android/`, as CI does. Robolectric
  gives real Android types like `Rect`, and Mockito stands in for ML Kit's `Text` and the camera's
  image planes. libyuv's copy itself needs a device.
- **iOS native** (`example/ios/RunnerTests/`): `xcodebuild test -workspace
  example/ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,…'
  -only-testing:RunnerTests`. Runs on a **simulator, not the host**, and tests helpers in place via
  `@testable import text_sight` (they're `internal`, not `private`, for this). Stand-in
  recognizers cover what would need a camera.
  - **Not a host `swift test`:** `Package.swift` finds `FlutterFramework` by a path that only
    resolves inside Flutter's build of the example, so the package can't resolve on its own.
  - **Two setup gotchas:** (1) the `RunnerTests` target's `IPHONEOS_DEPLOYMENT_TARGET` must be ≥
    the plugin's iOS floor (15.0) or SPM rejects the link, and (2) run
    `flutter build ios --config-only --debug --simulator` in `example/` first. It regenerates the
    SPM manifests, and a leftover device build otherwise leaves the test host unable to link.

Native unit-test deps are `test`-scoped only and never reach the published AAR or a consumer's
transitive closure, so they don't touch the no-bundling contract (hard rule 1).

## Style

Full guide: [`../CODESTYLE.md`](../CODESTYLE.md) (Dart, Swift and Kotlin). The rules to keep in
mind:

- Type-annotate every public symbol, and `final` by default for fields and locals.
- Nullability is explicit (no `as T` on `T?`), and `RecognizedLine.confidence` is never null,
  since both engines supply it.
- 100-column line width (`formatter.page_width: 100`), and `.editorconfig` mirrors it for every
  other text file.
- No magic numbers in `lib/` code. Name them as `static const`s.
- Public symbols carry `///` dartdoc explaining *why*, not *what*.
- **Native:** system-frameworks-only on iOS, ML Kit/CameraX confined to gradle on Android
  (the no-bundling import discipline), run recognition off the main thread, and honour the
  frame-backpressure invariants. Swift = 2-space, Kotlin = 4-space.

For everything else (naming, idioms, class structure, DCM rules, the Swift/Kotlin
sections, markdown conventions) go to [`../CODESTYLE.md`](../CODESTYLE.md).

## Guidelines for any AI agent

- **Always ask before making technical choices.** When a task admits more than one reasonable
  approach (wrapping `DataScannerViewController` or not, Pigeon or another codegen, whether a
  symbol belongs in the barrel, whether to add a dependency), **stop and ask**. Give the options
  with their trade-offs, say which you'd pick and why, then wait. Small choices count too, since
  they compound.
- **Mark recommendations with `★`,** so the user can reply by echoing or overriding ("★ for 1-4,
  change 5 to B").
- **Refactor first when it sets up the change.** If a feature would land cleaner on a different
  structure, do the behaviour-preserving refactor as its own step first, rather than bolting the
  feature onto a shape that fights it. Propose it like any other choice, and scope it to what the
  change rests on.
- **Verify the no-bundling held.** After an iOS build of the example,
  `grep -rEiI 'mlkit|googlemlkit|mlimage' example/ios` must find nothing (grep, since rg skips the
  gitignored SPM manifest). The example is SPM-based, so the generated
  `FlutterGeneratedPluginSwiftPackage` manifest is the real iOS dependency list. Run it whenever
  the native dependency surface could have shifted.
- **Document new user-facing API in the README.** Any new public class, widget, method, or
  configuration option must be added to the README in the same change. Rationale + design
  trade-offs belong in `APPENDIX.md`, and the README is the user-facing entry point.
- **Read the shared lints before writing Dart.** The lint posture is far stricter
  than the Dart default, and code that fails lint won't pass review.
- **Surface semver implications loudly.** If a change touches anything re-exported from
  `lib/text_sight.dart`, call out whether it's patch / minor / major before the diff lands.
- **Exercise changes in `example/` when feasible.** The demo app is both the living usage
  reference and the no-bundling test harness, so running it on an Android emulator *and* an
  iOS simulator is the most reliable verification path for any capture/recognition change.
  If you can't, call out explicitly what you did NOT verify.
