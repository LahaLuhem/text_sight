# AGENTS.md — `text_sight`

Tool-agnostic brief for any coding agent (Copilot, Cursor, Codex, Claude Code, …) working
in this package. Claude-Code-specific guidance lives in [CLAUDE.md](./CLAUDE.md).

## Project goal

A Flutter **plugin** for live, on-device **text recognition** — **Apple Vision on iOS**,
**ML Kit on Android** — the text-scanning sibling to
[`mobile_scanner`](https://pub.dev/packages/mobile_scanner). Two entry points: a live
camera widget (`TextSightView` + `TextSightController`) and a one-shot static call
(`TextSight.recognizeImage`/`.recognizePath`).

The gap it fills: existing live + cross-platform OCR wrappers run **ML Kit on iOS too**,
which drags `GoogleMLKit` pods into the iOS build and trips the arm64 /
Swift-Package-Manager deprecation warnings on Apple-Silicon simulators. `text_sight` uses
each platform's **native** engine so iOS links **zero** third-party ML libraries (Apple
Vision is a system framework) while Android keeps ML Kit (fine there). This isolation is
the package's reason to exist — see [`APPENDIX.md#no-bundling`](../APPENDIX.md#no-bundling).

- **pub id:** `text_sight`. **Brand/title:** TextSight. **Class prefix:** `TextSight*`
  (`TextSight`, `TextSightController`, `TextSightView`, `TextSightCapture`).
- **pub.dev topics:** `ocr`, `text-recognition`, `vision`, `mlkit`, `camera`.

## Stack

> **Freshly scaffolded.** Today the repo has `ios/`, `android/`, and the root meta-files.
> `lib/`, `pigeons/`, `example/`, `.github/`, and `scripts/` are the planned structure the
> build order populates — the *Repo layout* below is the target shape, not a claim that
> every path exists yet.

- **It's a plugin, not a pure package** — it needs native code (Swift/Vision,
  Kotlin/ML Kit). For v1 a **single plugin package** declares both platforms; full
  federation is deferred ([`APPENDIX.md#federation-deferred`](../APPENDIX.md#federation-deferred)).
- **Flutter ≥ 3.44, Dart ≥ 3.12** (pinned in `pubspec.yaml`; `.fvmrc` pins the Flutter
  channel for local use). Dart 3.12 comfortably clears the 3.10 static-dot-shorthand floor
  the code style leans on.
- **iOS — Swift**, using the system frameworks **Vision** + **AVFoundation** (+ CoreMedia /
  CoreVideo). `AVCaptureSession` → `VNRecognizeTextRequest`, preview to a `FlutterTexture`.
  Ships **both** `ios/text_sight.podspec` **and** `ios/text_sight/Package.swift` so host
  apps on CocoaPods *or* SwiftPM both work — the SPM path is the cleanliness win. Neither
  declares a third-party dependency.
- **Android — Kotlin**, using **CameraX** + **ML Kit text recognition**. `ImageAnalysis`
  (`STRATEGY_KEEP_ONLY_LATEST`) → `TextRecognition` client, preview via `Texture`. ML Kit +
  CameraX are declared **only** in `android/build.gradle.kts`. The module stays on Flutter's
  **built-in Kotlin** (Gradle Kotlin-DSL, `plugins {}`) — never the legacy
  `apply plugin: 'kotlin-android'`, which re-introduces the KGP deprecation warning this
  package exists to avoid.
- **Channel topology** ([`APPENDIX.md#channel-topology`](../APPENDIX.md#channel-topology)):
  the typed **control API** (initialize / start / stop / set-ROI / set-level /
  set-languages / toggle-torch / dispose) is **Pigeon** codegen (`@HostApi`); **per-frame
  results** stream over a plain **`EventChannel`**; the **camera preview** is a `Texture`.
  Pigeon is the planned codegen tool (Golubets is a viable alternative — both are dev-time
  only, zero runtime/bundling impact); it isn't in `dev_dependencies` yet.
- **`flutter analyze`** for pedantic static analysis — the lint posture is deliberately
  strict (`strict-casts` / `strict-inference` / `strict-raw-types` + the `errors:`-promoted
  block in `analysis_options.yaml`). Pedantic mode is intentional, not negotiable.
  **`flutter_test`** for Dart unit/widget tests. The native sides have no analyzer gate —
  their conventions are applied by hand ([`CODESTYLE.md`](../CODESTYLE.md)).
- **Published to pub.dev.** `.pubignore` controls the tarball. `CHANGELOG.md`, the
  `version:` field in `pubspec.yaml`, and the release tag move in lockstep; CHANGELOG
  entries are bot-appended on merge (`.github/workflows/changelog.yml` via `cider`, driven
  by the PR's `sem-*` label and the `cider:` block in `pubspec.yaml`). Cutting a release is
  one command: `scripts/release.sh [patch|minor|major]` (see `scripts/README.md`). No
  manual `flutter pub publish`.

## Repo layout

```
text_sight/
├── pubspec.yaml             Deps: flutter, plugin_platform_interface — NO recognition lib
│                            (dev: flutter_test; Pigeon to be added for codegen)
├── pigeons/text_sight.dart  Pigeon schema for the typed control API (@HostApi)
├── lib/
│   ├── text_sight.dart            Public entry; `export 'src/…';` only
│   └── src/
│       ├── text_sight_view.dart        Texture-backed live widget
│       ├── text_sight_controller.dart  Control surface (start/stop/ROI/level/torch)
│       ├── models.dart                 TextSightCapture, RecognizedLine, enums
│       └── messages.g.dart             GENERATED by Pigeon — never hand-edit
├── ios/                     iOS plugin (Swift + Vision + AVFoundation)
│   ├── text_sight.podspec        CocoaPods; links system frameworks; NO third-party deps
│   ├── text_sight/Package.swift  SwiftPM manifest; system frameworks need no dependency line
│   └── text_sight/Sources/text_sight/   AVCaptureSession + VNRecognizeTextRequest + FlutterTexture
├── android/                 Android plugin (Kotlin + CameraX + ML Kit)
│   ├── build.gradle.kts          ML Kit + CameraX deps live ONLY here; built-in Kotlin
│   └── src/main/kotlin/com/LahaLuhem/text_sight/   CameraX ImageAnalysis + ML Kit recognizer
├── example/                 Runnable demo — also the no-bundling test harness
├── analysis_options.yaml    Strict-mode + opinionated lints
├── .pubignore               Files excluded from `flutter pub publish`
├── .editorconfig            Text-file conventions (Dart 2 / Swift 2 / Kotlin 4 / shell 2 / …)
├── .fvmrc                   FVM channel pin
├── .github/workflows/       CI: pr-conventions, changelog, package, example, repo, publish
├── scripts/                 release.sh + README (cider-driven release flow)
├── CHANGELOG.md             Release log (bot-appended on merge, hand-finalised at release)
├── README.md                pub.dev landing page (hook line + topics)
├── APPENDIX.md              Design rationale (anchor-keyed)
├── CODESTYLE.md             Plugin-package code style (Dart + Swift + Kotlin + shell)
└── .ai/                     This file + CLAUDE.md (symlinked at root)
```

**Platform support is iOS + Android** — the only platforms declared in `pubspec.yaml`'s
`plugin:` block. Adding another platform target is an explicit-conversation change (hard
rule 13).

## Hard rules

1. **No-bundling — recognition libraries never enter the Dart `pubspec.yaml`.** This is the
   load-bearing rule. ML Kit + CameraX are declared **only** in `android/build.gradle.kts`;
   the iOS side imports **only system frameworks** (`Vision`, `AVFoundation`). The Dart
   `pubspec.yaml` declares **no** recognition library — only `flutter` +
   `plugin_platform_interface`. **Do not add `camera`, `google_mlkit_*`, or any recognition
   package as a Dart dependency** — that's the exact mistake (`flutter_scalable_ocr`'s
   iOS podspec dragging in GoogleMLKit) this package exists to avoid. Native capture +
   native recognition per platform, always. See
   [`APPENDIX.md#no-bundling`](../APPENDIX.md#no-bundling).
2. **Ship both the podspec and `Package.swift` on the Apple side, with no third-party
   dependencies in either.** SPM-only and CocoaPods-only host apps must both build; the SPM
   cleanliness is the point. Adding a pod/SPM dependency violates rule 1.
3. **The Android module stays on built-in Kotlin.** Use Flutter's Gradle `plugins {}` DSL,
   never the legacy `apply plugin: 'kotlin-android'` + buildscript classpath — the legacy
   path emits the KGP deprecation warning this package is fighting.
4. **Normalize coordinates to top-left `[0,1]` in native code.** Vision gives normalized
   bottom-left boxes; ML Kit gives pixel rects in rotated space; Flutter wants top-left
   normalized. Convert on each native side so the Dart overlay is platform-agnostic and
   never branches. See [`APPENDIX.md#coordinate-normalization`](../APPENDIX.md#coordinate-normalization).
5. **Never queue frames — apply backpressure.** iOS: a single in-flight `VNImageRequest` +
   `alwaysDiscardsLateVideoFrames`. Android: `STRATEGY_KEEP_ONLY_LATEST` **and** a mandatory
   `imageProxy.close()` in `addOnCompleteListener` (the next frame isn't delivered until the
   current proxy closes). Run recognition off the platform main thread; marshal results back
   to main for the `EventChannel` sink.
6. **The public API lives only in `lib/text_sight.dart`.** That barrel re-exports from
   `lib/src/`; the `src/` subtree is private by convention. Don't make users import
   `package:text_sight/src/…`. See
   [`APPENDIX.md#public-api-via-single-export-file`](../APPENDIX.md#public-api-via-single-export-file).
7. **Generated code is never hand-edited.** `lib/src/messages.g.dart` is Pigeon's output —
   regenerate it from `pigeons/text_sight.dart`, don't patch it.
8. **No `print()` in library code.** Diagnostic output is the caller's responsibility.
   `avoid_print` is a warning in `analysis_options.yaml`.
9. **No `dynamic` escape hatches.** `strict-casts`, `strict-inference`, and
   `strict-raw-types` are all on. If you reach for `dynamic` or unconstrained `Object?`,
   stop and reconsider.
10. **Public symbols carry dartdoc.** `public_member_api_docs` is on. Every public class /
    widget / function / getter needs a `///` comment that explains *why*, not *what*.
11. **Surface permission/error states — never crash.** A denied camera permission, an
    unsupported platform, or a missing channel is a typed state/error the consumer can
    render, not an unhandled throw. Document `NSCameraUsageDescription` (iOS) and the
    `CAMERA` permission (Android) for consumers.
12. **Semver, strictly.** Breaking changes only on a major bump. Any change to a public
    signature (`TextSightController`/`TextSightView` constructor, a public model field), a
    deletion, or a behavioural change of a documented contract is breaking — surface the
    implication before the diff lands.
13. **iOS + Android only.** The plugin declares only `android` and `ios`. Don't add
    another platform target (web, desktop) without an explicit conversation.
14. **`CHANGELOG.md`, `version:`, and the release tag move together — and are
    pipeline-owned.** Routine CHANGELOG appends are bot-driven (`changelog.yml` + `cider`);
    cutting a release is `scripts/release.sh`. Don't hand-edit `CHANGELOG.md`, the
    `version:` field, or `example/pubspec.lock` without an explicit instruction to cut a
    release — see [*Forbidden / confirm-first actions* in CLAUDE.md](./CLAUDE.md#forbidden-confirm-first-actions).
    The `cider:` block in `pubspec.yaml` is static config and may be hand-edited.

## PR conventions

The `.github/workflows/pr-conventions.yml` workflow enforces branch-name, PR-label, and
commit-subject rules on every PR. On merge, `.github/workflows/changelog.yml` auto-appends
to `CHANGELOG.md` based on the PR's `sem-*` label (via `cider log`). **PRs that don't
comply are blocked by CI.**

- **Branch name** — `<type>/#<issue>-<slug>`, where `<type>` is one of `feature`,
  `bugfix`, `chore`, `refactor`, `hotfix`. Example: `chore/#12-tidy-readme`.
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

  The PR title becomes the CHANGELOG line verbatim — write it as a release-note bullet.
- **PR body must not be empty**, **no merge commits in the PR range** (rebase to integrate
  `main`), and **commit subjects ≤ 82 characters**.

Cutting a release is one command: `scripts/release.sh [patch|minor|major]` — see
`scripts/README.md` for usage, preflight, and the pipeline-owned-files contract.

## Style

Full guide: [`../CODESTYLE.md`](../CODESTYLE.md) (covers Dart, Swift, Kotlin, and shell).
The lint posture is deliberately strict (see `analysis_options.yaml`). Top-level rules to
keep in working memory:

- Type-annotate every public symbol; `final` by default for fields and locals.
- Nullability is explicit (no `as T` on `T?`); `RecognizedLine.confidence` is nullable by
  contract (Vision supplies it, ML Kit doesn't).
- 100-column line width (`formatter.page_width: 100`); `.editorconfig` mirrors it for every
  other text file.
- No magic numbers in `lib/` code — pull to named `static const`s.
- Public symbols carry `///` dartdoc explaining *why*, not *what*.
- **Native:** system-frameworks-only on iOS, ML Kit/CameraX confined to gradle on Android
  (the no-bundling import discipline); run recognition off the main thread; honour the
  frame-backpressure invariants. Swift = 2-space, Kotlin = 4-space.

For everything else — naming, idioms, class structure, DCM rules, the Swift/Kotlin
sections, markdown conventions — go to [`../CODESTYLE.md`](../CODESTYLE.md).

## Guidelines for any AI agent

- **Always ask before making technical choices.** When the task admits more than one
  reasonable approach (the iOS strategy — roll-your-own AVCapture+Vision vs wrapping
  `DataScannerViewController`; Pigeon vs Golubets; whether a symbol belongs in the public
  barrel or stays under `lib/src/`; the unified confidence contract; whether to add a
  dependency; etc.), **stop and ask**. Present the options with trade-offs, say which you'd
  pick and why, then wait. Don't silently pick one and build. This applies even when a
  choice feels small — small choices compound.
- **Mark recommendations with `★`.** Prefix your preferred option in every set with `★` so
  the user can scan and reply by echoing or overriding (e.g. "★ for 1–4, change 5 to B").
- **Verify the no-bundling actually held.** After adding `text_sight` to the example and
  building iOS, `rg -i 'mlkit|googlemlkit|MLImage' example/ios/Podfile.lock` must return
  **no matches**, and no GoogleMLKit pods should appear for iOS. This is the package's core
  acceptance check — run it whenever the native dependency surface could have shifted.
- **Document new user-facing API in the README.** Any new public class, widget, method, or
  configuration option must be added to the README in the same change. Rationale + design
  trade-offs belong in `APPENDIX.md`; the README is the user-facing entry point.
- **Read `analysis_options.yaml` before writing Dart.** The lint posture is far stricter
  than the Dart default — code that fails lint won't pass review.
- **Surface semver implications loudly.** If a change touches anything re-exported from
  `lib/text_sight.dart`, call out whether it's patch / minor / major before the diff lands.
- **Exercise changes in `example/` when feasible.** The demo app is both the living usage
  reference and the no-bundling test harness — running it on an Android emulator *and* an
  iOS simulator is the most reliable verification path for any capture/recognition change.
  If you can't, call out explicitly what you did NOT verify.
