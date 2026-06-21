# CLAUDE.md — `text_sight`

Claude-Code-specific guidance. Project facts, stack, hard rules, and AI-agent guidelines
live in [AGENTS.md](./AGENTS.md); the full code-style guide lives in
[`../CODESTYLE.md`](../CODESTYLE.md); design rationale lives in
[`../APPENDIX.md`](../APPENDIX.md). Read AGENTS.md and CODESTYLE.md first.

## Role & context
You're assisting with **text_sight**: a Flutter **plugin** for live, on-device text
recognition — Apple Vision on iOS, ML Kit on Android, the text-scanning sibling to
`mobile_scanner`. The whole point is that **iOS links zero third-party ML libraries**
(no GoogleMLKit), so the no-bundling discipline is sacred. Treat the user as technical and
direct. The package is published on pub.dev — changes are visible to every downstream
user, so breakage is expensive and slow to walk back (unpublished versions stay reserved
for 7 days, and a tag push triggers an automated publish).

## Communication
- **Concise.** No "here's what I just did" recap; the diff speaks.
- **Explain the *why*** when recommending. The *what* is in the diff.
- Reference code as `file.dart:42` (markdown links if you can); native too
  (`TextSightPlugin.swift:88`, `TextSightPlugin.kt:30`).
- Flag breaking-API or lint-violation implications loudly and early.

## Technical choices — always ask first
- **Do not silently pick between reasonable alternatives.** Whenever a task admits more
  than one defensible approach (the iOS strategy — roll-your-own AVCapture+Vision vs
  wrapping `DataScannerViewController`; Pigeon vs Golubets; bundled vs unbundled ML Kit on
  Android; whether a symbol belongs in the `lib/text_sight.dart` barrel or stays under
  `lib/src/`; the unified confidence contract; whether to add a dependency; etc.), **stop
  and ask**. Recommendations in the question are expected — list the options with
  trade-offs, say which you'd pick and why, then wait.
- **"Small" choices count.** The bar isn't "is this architecturally significant" — it's
  "could a reasonable maintainer disagree with my pick". If yes, ask.
- **Mark your recommendation with `★`.** When presenting options, prefix your preferred
  pick(s) with `★` so the user can scan and reply by echoing or overriding (e.g. "go with
  ★ for 1–4, change 5 to B").
- **Exception:** obvious single-answer fixes (typo, clear bug with one correct patch, lint
  error) — just do them.

## Tool preferences
- **Read / Edit / Grep / Glob** over `cat` / `sed` / `grep` / `find`. Always.
- **Bash** only for things without a dedicated tool: `flutter`, `dart`, `git`, and the
  native toolchains when needed (`pod`, `xcodebuild`, `gradlew`). The user's shell aliases
  `flutter` / `dart` to whatever toolchain manager serves the `.fvmrc`-pinned channel —
  invoke plain `flutter` / `dart`, not the manager directly.
- **Lint with `flutter analyze`** — the project promotes many lints to `error:` in
  `analysis_options.yaml`; those are the contract, not suggestions. The Swift/Kotlin sides are
  gated by **detekt** (`detekt.yml`) and **SwiftLint** (`.swiftlint.yml`) in CI; still apply
  [`../CODESTYLE.md`](../CODESTYLE.md)'s native conventions by hand for what those don't cover.
- **Agent tool** for wide / open-ended searches or to keep large outputs out of main
  context. Not for trivial lookups.

## Scope awareness
- **Public-API edits** (anything in `lib/text_sight.dart` or re-exported from it — the
  `TextSight*` classes, the result models, enums) are pub.dev-visible. Treat them with
  care; flag patch / minor / major under semver before landing.
- **`lib/src/` edits** are private. Refactor freely as long as the public re-exports stay
  stable. `lib/src/messages.g.dart` is **generated** — change `pigeons/text_sight.dart` and
  regenerate, never hand-edit the output.
- **Native edits (`ios/`, `android/`)** carry the no-bundling contract. Adding a pod / SPM
  dependency on the Apple side, or a non-gradle path to ML Kit, breaks the package's reason
  to exist — see [hard rules 1–3 in AGENTS.md](./AGENTS.md#hard-rules). The frame-backpressure
  and off-main-thread invariants (hard rule 5) are the most common source of plugin bugs.
- **`pigeons/text_sight.dart` edits** change the typed control-channel surface; regenerate
  `messages.g.dart` in the same change and treat signature changes as public-API-class.
- **`example/` edits** are local — no publish impact. The demo app is the living usage
  reference *and* the no-bundling test harness; keep it building on both Android and iOS.
- **`analysis_options.yaml` edits** affect every Dart file. Surface lint-posture changes
  loudly and add a written reason in `APPENDIX.md`.
- **`pubspec.yaml` edits** that touch `dependencies` add to every downstream user's
  transitive closure — treat as public-API-class. Adding a recognition/camera dep is
  forbidden (hard rule 1). Changing `topics:` or `platforms:` is also pub.dev-visible.

## Auto-memory conventions for this project
- **`project` memories** — scope/constraints the user states aloud (e.g. "ship v0.1 before
  the sprint ends", "minimum Flutter bumps to X on date Y", "DataScanner path is on hold").
  Convert relative dates to absolute.
- **`feedback` memories** — corrections AND validated non-obvious choices. Include **Why**
  and **How to apply** lines.
- **`reference` memories** — external pointers (the pub.dev page, `mobile_scanner` /
  `apple_vision_recognize_text` / `flutter_scalable_ocr` upstreams, the Apple Vision /
  ML Kit docs). Not internal code paths — those live in AGENTS.md or are derivable.
- **Do NOT save** Dart/Swift/Kotlin file paths, lint-rule lists, or API surface — all
  derivable from the repo or APPENDIX.md. Re-deriving is safer than acting on a stale memory.
- **Before acting on a memory**, verify the named file / symbol still exists.

## Plan before editing when
- The change touches the public API (anything re-exported from `lib/text_sight.dart`).
- You're editing `pigeons/text_sight.dart` (the control-channel schema) — plan the shape
  against the channel topology in [`APPENDIX.md#channel-topology`](../APPENDIX.md#channel-topology)
  before regenerating.
- You're touching the native capture / recognition pipeline (AVCaptureSession + Vision on
  iOS, CameraX + ML Kit on Android), texture lifecycle, or threading — the backpressure and
  texture-release invariants are subtle and leak-prone (hard rule 5).
- You're adding or removing a dependency in `pubspec.yaml`, or any native dependency.
- You're changing `analysis_options.yaml`. Lint posture is project-wide; any toggle deserves
  a written reason in APPENDIX.

For single-file, single-concern fixes inside `lib/src/`: just do it.

The release flow — `CHANGELOG.md`, `version:` in `pubspec.yaml`, and the matching git tag —
is **not** in the routine-edit list. All move together only when the user explicitly says
"cut a release"; see *Forbidden / confirm-first actions* below.

## Commit / PR etiquette
- **Never commit without being asked.** Not after a fix, not as a "checkpoint".
- **Never push without being asked.** Especially not to `main`, and especially not a semver
  tag (which triggers pub.dev publish via `.github/workflows/publish.yml`).
- **Never `--amend`** unless the user asked — create a new commit instead.
- **Never `--no-verify`**, **never `git add -A`** — stage named paths.
- Match existing commit style (short imperative subject, no Claude-authored footer unless
  asked).
- When asked for a commit: show `git status` + `git diff`, draft the message, wait for
  approval.

<a id="forbidden-confirm-first-actions"></a>
## Forbidden / confirm-first actions
- **Never** `flutter pub publish` or `dart pub publish`. Publishing is effectively one-way —
  pub.dev reserves the version for 7 days after retraction. Releases happen through the
  tag-triggered workflow at `.github/workflows/publish.yml`; pushing a matching `X.Y.Z` git
  tag is the trigger and is itself a confirm-first action.
- **Never** push a semver tag (`git push origin <tag>` or `git push --tags`) without
  explicit instruction. The tag triggers `publish.yml`, which authenticates to pub.dev via
  OIDC (configured by `dart-lang/setup-dart`) — there is no manual confirmation step on the
  pub.dev side.
- **Never** run `cider` commands or hand-edit `CHANGELOG.md`, the `version:` field in
  `pubspec.yaml`, or `example/pubspec.lock` without an explicit instruction to cut a
  release. Version bumps, CHANGELOG finalisation, and the example-lockfile resync are owned
  by [`scripts/release.sh`](../scripts/release.sh); the running `## [Unreleased]` buffer is
  bot-appended by `.github/workflows/changelog.yml`. If the user asks for a release, suggest
  `scripts/release.sh <bump>` — don't invoke it for them (it pushes to `origin/main` and
  triggers publish). The `cider:` block in `pubspec.yaml` is static config — hand-edit it
  freely.
- **Never** hand-edit generated code (`lib/src/messages.g.dart`) — regenerate from the
  Pigeon schema.
- **Never** edit `pubspec.lock` directly (root or `example/`). It's `flutter pub get`'s
  output.
- **Never** delete files under `.fvm/`, `.dart_tool/`, or `pubspec.lock` without approval.
  These are tooling state; deleting them forces a re-resolve.
- **Destructive git** (`reset --hard`, `push --force`, `branch -D`, `clean -fd`) → ask first.

## Definition of done
- `flutter analyze` clean (the `errors:` block promotes many lints to errors —
  non-negotiable).
- `dart format --output=none --set-exit-if-changed .` clean (100-column width matches
  `analysis_options.yaml`'s `formatter.page_width`).
- DCM rules applied by hand (`flutter analyze` doesn't run them) — `no-empty-block`,
  `newline-before-return`, `prefer-commenting-analyzer-ignores`, `avoid-returning-widgets`,
  `prefer-correct-edge-insets-constructor`. The `dcm` CLI (`dcm analyze lib`) covers them if
  installed.
- `flutter test` green (where tests exist).
- **Native conventions hand-applied** per [`../CODESTYLE.md`](../CODESTYLE.md) (Swift 2-space
  + system-frameworks-only; Kotlin 4-space + built-in-Kotlin + mandatory `imageProxy.close()`).
- **detekt + SwiftLint clean** — native lint gates (`detekt.yml` / `.swiftlint.yml`, run in CI).
  Generated `Messages.g.*` is excluded; for a new deviation, tune the config (not the generated code).
- When native capture/recognition changed: build and run the example on **both** an Android
  emulator and an iOS simulator — or explicitly call out what you did NOT verify (e.g.
  "didn't exercise on iOS — only ran the Android emulator").
- **No-bundling verified** when the dependency surface could have shifted:
  `rg -i 'mlkit|googlemlkit|MLImage' example/ios` returns no matches. The example uses Swift
  Package Manager (no `Podfile.lock`); the generated iOS SPM manifest must list no ML Kit package.
- `flutter pub publish --dry-run` clean if the change is publish-relevant. Do **not** bump
  the version or add a CHANGELOG entry to make the dry-run happy — those are release-time
  edits owned by `scripts/release.sh`.
- Public API additions documented with `///` dartdoc and reflected in the README.
