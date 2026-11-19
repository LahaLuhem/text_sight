# CLAUDE.md: `text_sight`

Claude-Code-specific guidance. Project facts, stack, hard rules, and AI-agent guidelines
live in [AGENTS.md](./AGENTS.md). The full code-style guide lives in
[`../CODESTYLE.md`](../CODESTYLE.md). Design rationale lives in
[`../APPENDIX.md`](../APPENDIX.md). Read AGENTS.md and CODESTYLE.md first.

## Role & context

You're assisting with **text_sight**, a published Flutter plugin for on-device text recognition
(Vision on iOS, ML Kit on Android). Its reason to exist is that **iOS links zero third-party ML
libraries**, so the no-bundling rule is sacred. Treat the user as technical and direct. Breakage
is expensive: pub.dev never unpublishes a version (it only allows a retraction within 7 days), and
a tag push publishes automatically.

## Communication

- **Concise.** No "here's what I just did" recap. The diff speaks.
- **Explain the *why*** when recommending. The *what* is in the diff.
- Reference code as `file.dart:42` (markdown links if you can), native too
  (`TextSightPlugin.swift:88`, `TextSightPlugin.kt:30`).
- Flag breaking-API or lint-violation implications loudly and early.

## Technical choices: always ask first

The rule and the `★` convention are in [AGENTS.md](./AGENTS.md#guidelines-for-any-ai-agent). The
bar isn't "is this architecturally significant" but "could a reasonable maintainer disagree with
my pick". Obvious single-answer fixes (a typo, a clear bug with one correct patch, a lint error)
need no question.

## Tool preferences

- **Read / Edit / Grep / Glob** over `cat` / `sed` / `grep` / `find`. Always.
- **Bash** only for things without a dedicated tool: `flutter`, `dart`, `git`, and the
  native toolchains when needed (`xcodebuild`, `gradlew`). The user's shell aliases
  `flutter` / `dart` to the `.fvmrc`-pinned toolchain, so invoke them plainly, not the manager.
- **Lint with `dart analyze --fatal-infos --fatal-warnings .`**, as CI runs it: the shared lints
  promote many lints to `error:`, and those are the contract, not suggestions. The Swift/Kotlin
  sides are gated by detekt (`android/detekt.yml`) and SwiftLint (per-tree `.swiftlint.yml` under
  `ios/` and `example/ios/`) in CI. Still apply [`../CODESTYLE.md`](../CODESTYLE.md)'s native
  conventions by hand for what those don't cover.
- **Agent tool** for wide / open-ended searches or to keep large outputs out of main
  context. Not for trivial lookups.

## Scope awareness

- **Public-API edits** (anything in `lib/text_sight.dart` or re-exported from it, the
  `TextSight*` classes, the result models, enums) are pub.dev-visible. Treat them with
  care, and flag patch / minor / major under semver before landing.
- **`lib/src/` edits** are private. Refactor freely as long as the public re-exports stay
  stable. `lib/src/platform/messages.g.dart` is **generated**, so change
  `pigeons/text_sight.dart` and regenerate, never hand-edit the output.
- **Native edits (`ios/`, `android/`)** carry the no-bundling contract
  ([hard rules 1-3](./AGENTS.md#hard-rules)). A new SPM dependency is flag-and-ask, not forbidden.
  The backpressure and off-main-thread invariants (hard rule 5) are the most common source of
  plugin bugs.
- **`pigeons/text_sight.dart` edits** change the typed control-channel surface, so regenerate
  `messages.g.dart` in the same change and treat signature changes as public-API-class.
- **`example/` edits** are local, with no publish impact. The demo app is the living usage
  reference *and* the no-bundling test harness, so keep it building on both Android and iOS.
- **`analysis_options.yaml` edits** override dartender's shared lints, which every repo gets.
  Surface them loudly and add a written reason in `APPENDIX.md`.
- **`pubspec.yaml` edits** that touch `dependencies` add to every downstream user's
  transitive closure, so treat as public-API-class. Adding a recognition/camera dep is
  forbidden (hard rule 1). Changing `topics:` or `platforms:` is also pub.dev-visible.

## Auto-memory conventions for this project

- **`project` memories**: scope or constraints the user states aloud ("minimum Flutter bumps to X
  on date Y", "DataScanner path is on hold").
  Convert relative dates to absolute.
- **`feedback` memories**: corrections AND validated non-obvious choices. Include `Why`
  and `How to apply` lines.
- **`reference` memories**: external pointers (the pub.dev page, `mobile_scanner` /
  `apple_vision_recognize_text` / `flutter_scalable_ocr` upstreams, the Apple Vision /
  ML Kit docs). Not internal code paths, since those live in AGENTS.md or are derivable.
- **Do NOT save** Dart/Swift/Kotlin file paths, lint-rule lists, or API surface, since all
  derivable from the repo or APPENDIX.md. Re-deriving is safer than acting on a stale memory.
- **Before acting on a memory**, verify the named file / symbol still exists.

## Plan before editing when

- The change touches the public API (anything re-exported from `lib/text_sight.dart`).
- You're editing `pigeons/text_sight.dart` (the control-channel schema), so plan the shape
  against the channel topology in [`APPENDIX.md#channel-topology`](../APPENDIX.md#channel-topology)
  before regenerating.
- You're touching the native capture / recognition pipeline (AVCaptureSession + Vision on
  iOS, CameraX + ML Kit on Android), texture lifecycle, or threading, since the backpressure and
  texture-release invariants are subtle and leak-prone (hard rule 5).
- You're adding or removing a dependency in `pubspec.yaml`, or any native dependency.
- You're overriding a shared lint in `analysis_options.yaml`. Lint posture is project-wide, so any
  toggle deserves a written reason in APPENDIX.

For single-file, single-concern fixes inside `lib/src/`: just do it.

The release flow (`CHANGELOG.md`, `version:` in `pubspec.yaml`, and the matching git tag)
is **not** in the routine-edit list. All move together only when the user explicitly says
"cut a release". See *Forbidden / confirm-first actions* below.

## Commit / PR etiquette

- **Never commit without being asked.** Not after a fix, not as a "checkpoint".
- **Never push without being asked.** Especially not to `main`, and especially not a semver
  tag (which triggers pub.dev publish via `.github/workflows/publish.yml`).
- **Never `--amend`** unless the user asked. Create a new commit instead.
- **Never `--no-verify`, never `git add -A`.** Stage named paths.
- Match existing commit style (short imperative subject, no Claude-authored footer unless
  asked).
- When asked for a commit: show `git status` + `git diff`, draft the message, wait for
  approval.

<a id="forbidden-confirm-first-actions"></a>

## Forbidden / confirm-first actions

- **Never** `flutter pub publish` or `dart pub publish`. Publishing is one-way, since pub.dev
  never unpublishes a version and only lets you retract one within 7 days. Releases go through
  the Release run, whose tag push starts `.github/workflows/publish.yml`. Pushing a matching
  `X.Y.Z` git tag by hand starts it too, so that's a confirm-first action.
- **Never** push a semver tag (`git push origin <tag>` or `git push --tags`) without
  explicit instruction. The tag triggers `publish.yml`, which authenticates to pub.dev via
  OIDC (configured by `dart-lang/setup-dart`), and there is no manual confirmation step on the
  pub.dev side.
- **Never** run `cider` commands or hand-edit `CHANGELOG.md`, the `version:` field in
  `pubspec.yaml`, or `example/pubspec.lock`. Version bumps, CHANGELOG finalisation, and the
  example-lockfile resync are owned by the release run, the running `## [Unreleased]` buffer is
  bot-appended by `.github/workflows/changelog.yml`, and Dependabot bumps
  `example/pubspec.lock` too. After changing `example/pubspec.yaml`, run `flutter pub get` in
  `example/`. If the user asks for a release, point them at the **Release** workflow in the
  Actions tab, but don't start it for them (it pushes to `main` and triggers publish). The
  `cider:` block in `pubspec.yaml` is static config, so hand-edit it freely.
- **Never** hand-edit generated code (`lib/src/platform/messages.g.dart`). Regenerate from the
  Pigeon schema.
- **Never** edit `pubspec.lock` directly (root or `example/`). It's `flutter pub get`'s
  output.
- **Never** delete files under `.fvm/`, `.dart_tool/`, or `pubspec.lock` without approval.
  These are tooling state, and deleting them forces a re-resolve.
- **Destructive git** (`reset --hard`, `push --force`, `branch -D`, `clean -fd`): ask first.

## Definition of done

- Every check `ci / ok` waits on passes on your tree: the `needs:` of the `ok` job in
  [dartender's `ci.yml`](https://github.com/LahaLuhem/dartender/blob/main/.github/workflows/ci.yml),
  run with this repo's inputs from [`ci.yml`](../.github/workflows/ci.yml). So does every job in
  this repo's own [`plugin.yml`](../.github/workflows/plugin.yml), detekt and SwiftLint among
  them. Generated `Messages.g.*` is excluded from those, and for a new deviation, tune the config
  (not the generated code).
- DCM rules applied by hand (`dart analyze` doesn't run them, and CI runs no DCM):
  `no-empty-block`, `newline-before-return`, `prefer-commenting-analyzer-ignores`,
  `avoid-returning-widgets`, `prefer-correct-edge-insets-constructor`. The `dcm` CLI
  (`dcm analyze lib`) covers them if installed.
- **Native conventions hand-applied** per [`../CODESTYLE.md`](../CODESTYLE.md): Swift 2-space with
  system frameworks for recognition, Kotlin 4-space on built-in Kotlin, and every `ImageProxy`
  closed through `closeWhenSettled`.
- When native capture/recognition changed: build and run the example on **both** an Android
  emulator and an iOS simulator, or call out what you did NOT verify ("didn't run iOS, only the
  Android emulator").
- **No-bundling verified** when the dependency surface could have shifted:
  `grep -rEiI 'mlkit|googlemlkit|mlimage' example/ios` returns no matches (grep, since rg skips
  the gitignored SPM manifest). The example uses Swift Package Manager (no `Podfile.lock`), and
  the generated iOS SPM manifest must list no ML Kit package.
- `flutter pub publish --dry-run` clean if the change is publish-relevant, apart from its
  warning about uncommitted files, which fails it until you commit. Do **not** bump the version
  or add a CHANGELOG entry to make the dry-run happy, since those are release-time edits owned by
  the release run.
- Public API additions documented with `///` dartdoc and reflected in the README.
