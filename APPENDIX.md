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

> _Stub — to be written alongside `pigeons/text_sight.dart` and the native channel wiring._
>
> Will document why the three concerns ride three different transports rather than one:
> the **control API** (initialize / start / stop / set-ROI / set-level / set-languages /
> toggle-torch / dispose) is typed codegen via **Pigeon** (`@HostApi`); **per-frame
> results** stream over a plain **`EventChannel`** (a 30fps callback is clunky as a Pigeon
> `@FlutterApi`); and the **camera preview** is a **`Texture`** via the texture registry
> (not a codegen concern at all). Also: the Pigeon-vs-Golubets choice (still open — both
> are dev-time codegen with zero runtime/bundling impact), and why the generated
> `messages.g.dart` is committed and never hand-edited.

---

<a id="coordinate-normalization"></a>
## Coordinate normalization: top-left `[0,1]` in native code

> _Stub — to be written alongside the Swift and Kotlin recognizers._
>
> Will document the unified bounding-box contract and **why the conversion happens
> natively, not in Dart**: Apple Vision returns normalized boxes with a **bottom-left**
> origin; ML Kit returns **pixel** rects in the *rotated* image space; Flutter wants
> **top-left** normalized. Each native side converts to top-left `[0,1]` before crossing
> the channel, so the Dart overlay painter is platform-agnostic and never branches on
> platform. Includes the orientation inputs that must be correct or recognition silently
> degrades (EXIF orientation on iOS, `rotationDegrees` on Android). Cross-refs the
> per-language style notes in [`CODESTYLE.md#swift-ios-macos`](./CODESTYLE.md#swift-ios-macos)
> and [`CODESTYLE.md#kotlin-android`](./CODESTYLE.md#kotlin-android).

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

> _Stub — to be written as the public surface (`TextSight`, `TextSightController`,
> `TextSightView`, the result models) takes shape._
>
> Will document the single-entry convention: `lib/text_sight.dart` is the only file
> callers import; implementation lives in `lib/src/` and nothing there is meant to be
> imported directly; the entry file is `export 'src/…';` lines only. Dart has no hard
> public/private boundary under `lib/`, so this convention is how the ecosystem signals
> private intent — and it gives one place to audit the public surface before a release.
> Moving code *within* `lib/src/` is free (private); moving anything into or out of the
> re-export list is semver-visible (minor for additions, major for removals / signature
> changes). Prefer `show` over `hide` if a partial export ever becomes necessary.
