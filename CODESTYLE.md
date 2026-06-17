Plugin-package code style — Dart, Swift, Kotlin, and shell. Project facts (goal,
stack, repo layout, hard rules) live in [`.ai/AGENTS.md`](./.ai/AGENTS.md); design
rationale lives in [`APPENDIX.md`](./APPENDIX.md).

The lint posture is deliberately strict (see
[`analysis_options.yaml`](./analysis_options.yaml) — the `errors:` block promotes many
lints to errors). The house style values explicit types, no ambient mutability, and
small focused classes. The native sides (Swift, Kotlin) have no analyzer gate of their
own — the conventions below are applied by hand, the way the [DCM rules](#dcm-rules-applied-by-hand) are.

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Type safety & nullability](#type-safety--nullability)
- [Naming](#naming)
- [Formatting](#formatting)
- [Constants & magic numbers](#constants--magic-numbers)
- [Class structure](#class-structure)
- [Idioms](#idioms)
    * [Static dot shorthands (Dart 3.10+)](#static-dot-shorthands-dart-310)
    * [Drop redundant `<Type>` on collection literals](#drop-redundant-type-on-collection-literals)
    * [`Row.spacing` / `Column.spacing` / `Wrap.spacing` over interleaved `SizedBox` gaps](#rowspacing--columnspacing--wrapspacing-over-interleaved-sizedbox-gaps)
    * [Enhanced enums for per-variant config](#enhanced-enums-for-per-variant-config)
    * [`Navigator.maybeOf` over `Navigator.of` for fire-and-forget pops](#navigatormaybeof-over-navigatorof-for-fire-and-forget-pops)
    * [Collection-for / collection-if over `Iterable.map(…).toList()`](#collection-for--collection-if-over-iterablemaptolist)
    * [Library pipeline methods over hand-rolled loops (for data manipulation)](#library-pipeline-methods-over-hand-rolled-loops-for-data-manipulation)
    * [`dart:async` `wait` extensions over static `Future.wait(...)`](#dartasync-wait-extensions-over-static-futurewait)
    * [`List.unmodifiable(…)` over `UnmodifiableListView(…)`](#listunmodifiable-over-unmodifiablelistview)
    * [`part` / `part of` only when structurally needed](#part--part-of-only-when-structurally-needed)
- [Comments & dartdoc](#comments--dartdoc)
    * [`@docImport` for dartdoc-only references](#docimport-for-dartdoc-only-references)
- [DCM rules (applied by hand)](#dcm-rules-applied-by-hand)
- [Swift (iOS)](#swift-ios)
- [Kotlin (Android)](#kotlin-android)
- [Shell scripts](#shell-scripts)
- [Documentation conventions (Markdown)](#documentation-conventions-markdown)

<!-- TOC end -->

<a id="type-safety-nullability"></a>
## Type safety & nullability

- **Type-annotate every public symbol.** Inference is fine on locals; public surfaces
  (the `text_sight.dart` barrel and everything it re-exports) are not the place to rely
  on inference.
- **`final` by default for fields and locals.** Parameters are *not* required to be
  `final` — `avoid_final_parameters` allows mutation-shaped parameters, and
  `parameter_assignments` forbids the actual bad behaviour (mutating a parameter inside
  the body).
- **Nullability is explicit.** Use `T?` everywhere a value can be missing.
  `cast_nullable_to_non_nullable` is on — `as T` on a `T?` will fail lint. This matters
  for the result models: `RecognizedLine.confidence` is nullable by contract (Vision
  supplies it; ML Kit does not expose a per-line equivalent), so the type carries the
  "may be absent" fact — don't paper over it with a cast or a sentinel.
- **Constrain generic type parameters to `<T extends Object>` by default.** Unbounded
  `<T>` lets `null` and `dynamic` satisfy `T` — the same failure modes the explicit-
  nullability rule and the [`dynamic`-escape-hatch ban](./.ai/AGENTS.md#hard-rules)
  guard against elsewhere. Bind to `Object` so the type system enforces "some real
  value, not null"; if a particular call site needs `null`, the call site spells it as
  `T?` and the binding stays put. Loosen to raw `<T>` only when a value genuinely flows
  into an external API that relies on `null` as a sentinel `T` — don't reach for the
  exception speculatively.
- **Prefer type-pure representations over stringly- or primitively-typed ones.** Use a value's
  richer domain type — even a built-in one. `languages` is `Iterable<Locale>`, not `List<String>`
  of BCP-47 tags: `Locale` (from `dart:ui`) carries language/script/region and yields the tag via
  `toLanguageTag()` at the native boundary. Reach for a structured built-in, then a zero-cost
  `extension type`, before a bare primitive. **But don't force a *closed enum* onto an open,
  runtime-variable capability** — the recognizable-language set varies by platform, OS version,
  and bundled recognizers, so type-purity here is *structured but open*, not *enumerated*. A
  primitive handed straight to a platform API (a `Texture` id `int`) stays primitive.
- **Pick the narrowest collection type; `List` is the last resort, not the default.** `Set` for
  membership/uniqueness, `Iterable` for a sequence only walked (never indexed, added to, or
  re-materialized), `List` only when you genuinely index or need a materialized result. Inputs
  lean `Iterable` (`languages` is walked once in priority order); outputs consumers index and
  count stay `List` (`TextSightCapture.lines`, `RecognizedLine.elements`). Exception: channel
  transport — the platform codec carries only `List`/`Map`, so Pigeon message fields stay `List`.
- **No Java ceremony.** No getter-only abstract base classes, no `AbstractFooFactory`,
  no interface-per-class. Use mixins / sealed classes / records / extension types where
  they add clarity, not weight.

The `dynamic`-escape-hatch ban and the `print()`-in-library ban are listed under
[*Hard rules* in `.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules) — they're contracts, not
style.

---

<a id="naming"></a>
## Naming

- **Prefer abbreviations over initialisms for domain terms.** In code, comments,
  dartdocs, and log messages alike, expand. Widely-known protocol initialisms (HTTP,
  DNS, TCP, TLS, …), platform-name initialisms (iOS, OS), and the domain initialisms
  this package is *about* (OCR, ROI for region-of-interest) stay as-is once introduced;
  novel project terms get spelt out. The general-programming initialisms below also
  expand — shorthand that's "obvious" to the author is opaque to the next reader and
  indistinguishable from a typo:

  | Don't write | Write instead             |
    |-------------|---------------------------|
  | `cb`        | `callback` (with the type-suffix rule below: `<context>Callback` if shared scope makes bare `callback` ambiguous) |
  | `fn`        | `function` / `handler` / spell out the semantic role |
  | `cfg`       | `config` |
  | `idx`       | `index` (loop counters keep `i` / `j` per genre convention — see local-variable rule) |
  | `tmp`       | `temporary` / a name describing what it actually holds |
  | `req` / `res` / `resp` | `request` / `response` |
  | `ctx`       | `context` (Flutter's `BuildContext` arg stays `context` by convention) |
  | `evt`       | `event` |
  | `pb` / `sb` | `pixelBuffer` / `sampleBuffer` (recurring in the Vision capture path) |

  This rule binds *every* identifier — fields, locals, parameters, pattern bindings
  (`switch (x) { final cb => … }` is **out**; spell it). The only carve-outs are the
  genre conventions: single-letter loop counters (`i`, `j`), `e` in `catch (e)`,
  `(a, b)` in symmetric comparator pairs, `x`/`y` for coordinates (and these recur in
  the bounding-box math).
- **Local-variable names carry a concise type-suffix.** Dart is strongly typed, but a
  reader without IDE inlay-hints can't see the inferred type — the *name* has to do
  that work. Suffix a local with what it *is* so the next reader doesn't have to scroll
  back to the assignment to recover the type. **Callback parameters** are exempt and
  stay single-word (`capture`, `line`, `level`) — the enclosing call site already pins
  the type. **When a domain type exists, the suffix is the type name** —
  `recognizedLine` (not `line` when the type is ambiguous in scope),
  `recognitionLevel` (not `level`), `boundingBox` (not `box`). Generic suffixes
  (`Data`, `Info`, `Result`) lose the disambiguation the rule is meant to provide.

  ```dart
  // Prefer:
  final recognitionLevel = controller.recognitionLevel;
  final recognizedLines = capture.lines;

  // Over:
  final level = controller.recognitionLevel;
  final lines = capture.lines;
  ```

- **Unused closure parameters take the discard `_`, not a real name.** Don't declare an
  identifier you don't reference — `_` makes the unused-ness immediate.

  ```dart
  // Prefer:
  overlayBuilder: (_, capture, _) => _LinePainter(capture.lines),   // context + constraints unused

  // Over:
  overlayBuilder: (context, capture, constraints) => _LinePainter(capture.lines),
  ```

  Applies in dartdoc examples too — `(_)` is the idiomatic Dart form and users
  copy-pasting will inherit it. **Doesn't apply** to genre-conventional single-letter
  names (`i`/`j` in counters, `e` in `catch (e)`).
- **Don't rename callback params to disambiguate from a same-named outer-scope
  variable.** Dart's lexical scoping always picks the innermost binding — there's no
  ambiguity for the compiler, and a reader who knows the scoping rule sees the intent
  immediately. Renaming (`(dialogContext) => …`) signals a distinction worth tracking
  when in fact it carries none. The legitimate exception is when the closure body needs
  *both* the inner and outer same-named variable; then document the distinction in the
  **dartdoc on the callback**, not in the parameter name.
- **Files mirror their primary public symbol.** `TextSightController` lives in
  `text_sight_controller.dart`; `TextSightView` in `text_sight_view.dart`; each result
  model and config type gets its own file under `src/recognition/` (`TextSightCapture` in
  `text_sight_capture.dart`, `RecognizedLine` in `recognized_line.dart`, and so on). The
  `lib/src/` tree groups by concern — `recognition/` (capture-agnostic models + config),
  `capture/` (the live + static drivers), `view/`, `platform/` — see
  [`APPENDIX.md#public-api-via-single-export-file`](./APPENDIX.md#public-api-via-single-export-file).
  `file_names` enforces snake_case; the file ↔ symbol pairing is by convention.
  Pigeon-generated code lives in `messages.g.dart` (the `.g.` marks it generated — never
  hand-edit it).

---

<a id="formatting"></a>
## Formatting

- **Wrap text-file content at 100 columns.** `formatter.page_width: 100` in
  `analysis_options.yaml` is authoritative for Dart code; `.editorconfig`'s
  `max_line_length = 100` mirrors it for every other text file. Markdown and **dartdoc
  comments** follow the same cap manually — `dart format` does *not* reflow doc-comment
  prose, so a `///`-block hand-wrapped at 70 / 80 columns stays narrow forever unless
  someone refactors it. Default to ~95 columns of content (the leading `/// ` counts
  toward the limit) so a single trailing word doesn't push the line over. Reflow
  opportunistically when touching a doc block; don't churn unrelated files just to
  widen them.
- **Blank lines separate logical chunks within a method.** Group guard checks, setup,
  the main action, and finalisation with one blank line between groups. Lets readers
  scan past chunks they don't need without re-parsing them line-by-line. This applies on
  the native sides too (see [Swift](#swift-ios-macos) / [Kotlin](#kotlin-android)).
- **Prefer expression bodies** (single-statement methods write as `=>` returns) and
  **single quotes** (`prefer_single_quotes`).

---

<a id="constants-magic-numbers"></a>
## Constants & magic numbers

- **No magic numbers in `lib/` code.** Pull constants to named `static const`s with a
  descriptive identifier. Tuning knobs that ride on a public type (the default
  `RecognitionLevel`, the default language list, the default region-of-interest) belong
  as `static const`s on the class that owns them (`TextSightController` /
  the options type), so call sites read `TextSightController.defaultLanguages` and the
  origin is obvious.
- **Inline single-use defaults; don't promote to a named `kDefault…` constant.** A
  `kDefaultXxx` (or a public `static const` default) earns its name when the value is
  read from **more than one place** — typically a field default *and* a build-time
  substitution. When the value appears only as one constructor's parameter default — no
  second reader, no cross-file substitution — leave it as a literal and skip the
  constant. Two reasons:
    1. **API pollution.** Public `static const` defaults appear in auto-complete and in
       the rendered dartdoc. Each one a downstream user has to skim past.
    2. **No drift risk.** Constants exist partly to keep two readers from diverging on the
       same value. With only one reader, there's nothing to diverge from.

  A dartdoc reference (`Defaults to [kDefaultXxx]`) does **not** count as a second
  reader — once inlined, the dartdoc just spells out the literal: ``Defaults to `false` ``.

> Native-side magic numbers (recognition thresholds, pixel formats, EXIF orientation
> codes) follow the same rule — name them. See [Swift](#swift-ios-macos) /
> [Kotlin](#kotlin-android).

---

<a id="class-structure"></a>
## Class structure

- **Any class with fields and constructors: fields → constructors → other members.**
  Lets a reader scan the state shape first, then how to construct it, then how to use
  it. Within constructors, unnamed first, then factories. Static helpers go after the
  methods. Applies to the result types (`TextSightCapture`, `RecognizedLine`), the
  controller, and any helper type — wherever a class has both state and a constructor.
- **`assert` for dev-time errors, `throw` for runtime ones.** Constraints a caller can
  see violated during development (a region-of-interest with negative width, an empty
  language list where non-empty is required) belong in `assert` — stripped in release
  mode, zero runtime cost. Reserve `throw` and `Exception` for genuine runtime
  conditions the caller cannot guarantee at compile/dev time: an unsupported platform, a
  denied camera permission, a missing platform channel. A permission denial surfaces as
  a typed error/state, **not** a crash (see the hard rules in `.ai/AGENTS.md`).
- **Enforce constructor invariants with `assert(condition, message)` in the initializer
  list, not by silently accepting params and ignoring them downstream.** When a
  parameter is only meaningful alongside another, or two are mutually exclusive, say so
  loudly at construction time:

  ```dart
  TextSightController({TextSightOptions options = const TextSightOptions()})
    : assert(
        _isNormalizedRoi(options.roi),
        'Region-of-interest must be a normalized [0,1] rect with positive extent.',
      );
  ```

  **Why.** A param that gets silently dropped is a footgun: the user sets it, confirms
  via the dartdoc that it's wired, and never realises the value isn't reaching the
  native side. An `assert` fires the first time the invalid combination runs in debug
  mode, with a message pointing at the fix. Prefer compile-time exclusivity (two named
  constructors) when the invariant can be encoded in the signature; reach for `assert`
  when it can't (cross-parameter conditions, value-range checks).

  A `const` constructor's `assert` can use only constant expressions (no function calls), so a
  shared validation predicate lives behind a *non-const* constructor — the controller validates
  the ROI for both `TextSightOptions` and `setRegionOfInterest`, not the `const` options type
  itself.
- **Value types override `toString`.** Immutable data classes (`TextSightCapture`,
  `RecognizedLine`, the options/ROI records) implement `toString()` returning
  `'ClassName(field1: value1, field2: value2)'`. The default `Instance of 'ClassName'`
  is hostile in logs, exception traces, and `print` debugging. Include every field with
  a meaningful string representation; expression-bodied one-liner placed after the
  constructors, before any static helpers. Opaque fields (controllers, listenables,
  builder callbacks) are omitted — they add noise without informing the reader, and bare
  interpolation of a callable trips DCM's `avoid-missed-calls`. Pigeon-generated
  message classes are exempt — don't hand-edit generated code to add `toString`.

---

<a id="idioms"></a>
## Idioms

<a id="static-dot-shorthands-dart-310"></a>
### Static dot shorthands (Dart 3.10+)

Use static dot shorthands wherever the context type is known. They resolve from the
parameter / return / variable type, not from inference of arbitrary expressions. Drop
the leading type name in *all* of these positions, not just the obvious enum case:

- Enum values in patterns and arg slots:
  `recognitionLevel: .fast`, `case .accurate => …`, `crossAxisAlignment: .start`,
  `mainAxisSize: .min`.
- `EdgeInsets`-typed parameters and similar value types:
  `padding: const .all(16)`, `padding: const .symmetric(horizontal: 12, vertical: 4)`,
  `margin: .zero`.
- **Constructor field defaults** — when the field's declared type pins the context, the
  default literal drops its prefix:
  ```dart
  final RecognitionLevel level;
  const TextSightOptions({this.level = .fast});   // not RecognitionLevel.fast
  ```
  Top-level / `static const` initializations are the exception — without an explicit
  type annotation on the LHS, Dart infers the constant's type from the RHS, so the
  prefix has to stay (`const kDefaultLevel = RecognitionLevel.fast;`).

Skip when it hurts readability — `.new(…)` for unnamed constructors typically does, as
do cases where the surrounding context type isn't obvious without re-reading. After
dropping a fully-qualified prefix, the type name often disappears from the file
entirely — remove it from any `show` clauses too (`unused_shown_name` flags orphans).

<a id="drop-redundant-collection-literal-type-args"></a>
### Drop redundant `<Type>` on collection literals

When the surrounding context already pins the element / key / value type of a list,
set, or map literal — most often a parameter slot or assignment target — the explicit
`<Type>` prefix is dead weight:

```dart
// Prefer:
controller.setLanguages({'en-US', if (alsoFrench) 'fr-FR'})

// Over:
controller.setLanguages(<String>{'en-US', if (alsoFrench) 'fr-FR'})
```

Keep `<Type>` when inference would otherwise fall back to `dynamic`:

- **Empty literals without a slot.** `final lines = <RecognizedLine>[];` — the local has
  no context, so `[]` infers `List<dynamic>`. The annotation is doing real work.
- **Top-level / `static const` initialisers without a type annotation on the LHS.**

<a id="flex-spacing-over-sizedbox-gaps"></a>
### `Row.spacing` / `Column.spacing` / `Wrap.spacing` over interleaved `SizedBox` gaps

Flutter's flex widgets (`Row`, `Column`, `Wrap`, `Flex`) take a `spacing` parameter
(and `runSpacing` on `Wrap`) that inserts a uniform gap between adjacent children. Use
it instead of interleaving `SizedBox(width: …)` / `SizedBox(height: …)` between every
pair. Relevant in the example app and any overlay/scan-box chrome this package ships.

```dart
// Prefer:
Row(mainAxisSize: .min, spacing: 8, children: [icon, label])

// Over:
Row(mainAxisSize: .min, children: [icon, SizedBox(width: 8), label])
```

**Why.** The `spacing` form keeps `children` purely about content — the layout metadata
lives on the parent where it belongs. **Doesn't apply** when gaps differ between
adjacent pairs (fall back to explicit `SizedBox`), or when the gap depends on a
sibling's resolved size.

<a id="enhanced-enums-for-per-variant-config"></a>
### Enhanced enums for per-variant config

When a variant enum's values each carry a piece of configuration that diverges *per
value* — a native recognition-level mapping, a default threshold — attach the data to
the enum via Dart 3's enhanced-enum syntax. Don't define parallel top-level
`kDefault<Variant>Xxx` constants that the call site has to branch on.

```dart
// Prefer — the per-value datum lives on the value it describes:
enum RecognitionLevel {
    fast(usesLanguageCorrection: false),
    accurate(usesLanguageCorrection: true);

    final bool usesLanguageCorrection;
    const RecognitionLevel({required this.usesLanguageCorrection});
}
```

**Why.** Locality (the default lives on the variant; adding a value forces the choice at
compile time), discoverability (the IDE hovercard shows it), and call-site uniformity
(every branch references the same `level.usesLanguageCorrection` expression).
**Don't force it** — a discriminator-only enum whose values carry no package-read config
stays plain. Adding empty enum fields for symmetry is ceremony.

<a id="navigator-maybeof-over-of"></a>
### `Navigator.maybeOf` over `Navigator.of` for fire-and-forget pops

When dismissing a route from inside a callback whose only job is the pop — a "use this
result" button in the example, a modal close handler — reach for
`Navigator.maybeOf(context)?.pop(value)`, not `Navigator.of(context).pop(value)`.

```dart
// Prefer:
onPressed: (context) => Navigator.maybeOf(context)?.pop(capture),

// Over:
onPressed: (context) => Navigator.of(context).pop(capture),   // throws if no Navigator
```

**Why.** `Navigator.of(context)` asserts in debug and throws in release if no
`Navigator` exists in the ancestry. For fire-and-forget pops the right behaviour is a
silent no-op (the route may already be gone, the widget disposed mid-tap, the action
exercised in an isolated test) — exactly what `maybeOf(…)?.pop(…)` gives. The cost of
the defensive `?` is zero. **When `Navigator.of` is still right:** when you need the
return value of `push` and a missing Navigator is a setup bug you want surfaced loudly.

<a id="collection-for-collection-if-over-iterablemaptolist"></a>
### Collection-for / collection-if over `Iterable.map(…).toList()`

When *constructing* a data or widget literal, a literal list with embedded control flow
reads as data; a `.map(…).toList()` reads as a pipeline that incidentally produces data.
The literal form also doesn't bloat the file with `<T>` annotations the list-literal
context already infers:

```dart
// Prefer:
Column(
children: [
for (final line in capture.lines) Text(line.text),
],
)

// Over:
Column(
children: capture.lines.map((line) => Text(line.text)).toList(),
)
```

Drop explicit generic type arguments when the surrounding context already pins them;
keep them when inference would otherwise fall back to `dynamic`.

<a id="library-pipeline-methods-over-hand-rolled-loops"></a>
### Library pipeline methods over hand-rolled loops (for data manipulation)

The deliberate flip side of the [collection-for rule](#collection-for-collection-if-over-iterablemaptolist).
That rule is about *constructing* a literal — there, `[for (…) …]` reads as data. This
rule is about *transforming, filtering, flattening, or reducing* data — a genuine
pipeline, where a stream-style chain reads as exactly what it is, and re-deriving it
with an imperative loop plus a mutable accumulator obscures the intent (and
re-implements a method the SDK already ships).

Prefer the `dart:core` `Iterable` / `Set` / `Map` methods — `where`, `whereType<T>()`,
`map`, `expand`, `fold`, `Map.fromEntries`, `followedBy` — over a `for` loop that pushes
into a growable collection:

```dart
// Prefer — states the intent directly:
final highConfidenceText = capture.lines
        .where((line) => (line.confidence ?? 1) >= minConfidence)
        .map((line) => line.text)
        .join('\n');
```

**Boundary:** building a widget `children:` list or any data literal → collection-for.
Running a filter / flatten / reduce pipeline → these methods. A tell: if you seed an
empty collection and mutate it in a loop, that's usually a pipeline wearing a loop's
clothes. **Stay lazy; materialise deliberately** — don't end a chain with a reflexive
`.toList()`. Materialise only when the result is iterated more than once or an API
requires a `List`; when you do, `.toList(growable: false)` says it won't be mutated.

<a id="dartasync-wait-extensions-over-static-futurewait"></a>
### `dart:async` `wait` extensions over static `Future.wait(...)`

The extensions (`Iterable<Future<T>>.wait` and the record forms `FutureRecord2`…
`FutureRecord9`) live in `dart:async`'s `future_extensions.dart` and supersede the
static call. Relevant whenever the controller fans out concurrent platform-channel calls
(e.g. configure + start, or recognising a batch of images one-shot):

- **Fixed number of differently-typed futures → record form.** `(f1, f2).wait` returns
  `Future<(T1, T2)>` and destructures directly.
- **Dynamic number of same-typed futures → iterable form.** `iterable.wait` returns
  `Future<List<T>>`, but errors surface as `ParallelWaitError` carrying both per-slot
  values and per-slot errors — more useful than the first-error-wins of
  `Future.wait(iterable)`.

<a id="listunmodifiable-over-unmodifiablelistview"></a>
### `List.unmodifiable(…)` over `UnmodifiableListView(…)`

When you genuinely need to hand out a defensive copy of mutable internal state — a getter
exposing a private growable list — use `List.unmodifiable(…)` (same for `Set` / `Map`): it
*copies* (a snapshot decoupled from the source), whereas `UnmodifiableListView` only *wraps* (a
holder of the underlying list can still mutate it, and the view follows). Use the view only for
deliberate read-through visibility into private mutable state — rare here.

**Never inside a value type's constructor**, though: `: lines = List.unmodifiable(lines)` blocks
a `const` constructor for no gain — the result types (`TextSightCapture`, `RecognizedLine`) are
package-built from fresh channel data, and a `const` instance is passed a `const` (immutable)
list anyway. Make the constructor `const`, assign fields directly, and keep leaf types
(`RecognizedElement`) `const` so the types composing them can be too.

<a id="part-part-of-only-when-structurally-needed"></a>
### `part` / `part of` only when structurally needed

Not a smell on its own. Legitimate uses: sealed-class cases across files (Dart 3
requires the same library for sealed subtypes), and code-generation outputs — here, the
Pigeon-generated `messages.g.dart`. Avoid `part`/`part of` for general code
organisation — imports/exports are explicit, parts hide dependencies and leak
`_private` symbols across files within the library.

---

<a id="comments-dartdoc"></a>
## Comments & dartdoc

Public symbols carry `///` dartdoc that explains *why*, not *what* — types already carry
the *what*. See [hard rule on dartdoc in `.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules)
for the contract.

### `@docImport` for dartdoc-only references

When a file needs a symbol *only* for `[Name]` references in dartdoc (not in code), do
**not** add a regular `import` — that pulls the dependency into the runtime import graph
and hides intent. Use Dart's dartdoc-only directive instead:

```dart
/// @docImport 'src/view/text_sight_view.dart';
library;

import 'src/recognition/recognized_line.dart'; // Real code import.
```

**Why.** A regular `import` declares a runtime dependency. If the only reason is
`comment_references` resolution, the runtime graph lies — readers and tooling can't tell
the import is documentation-only, and dead-code elimination has nothing to lean on.
**How to apply.** Put the `@docImport` directive(s) as `///` comments directly above the
file's `library;` directive; code imports stay as regular `import` lines. The `library;`
directive is required for `@docImport` to attach — and `unnecessary_library_directive`
does not fire when a docImport is present.

---

<a id="dcm-rules-applied-by-hand"></a>
## DCM rules (applied by hand)

`flutter analyze` does not run them; they're declared in the `dart_code_metrics:` block
of `analysis_options.yaml` and treated as non-negotiable. Apply by hand (or via the
`dcm` CLI if installed: `dcm analyze lib`):

- **`no-empty-block`** — every block (function literal, `if`, `for`, `try`…) must
  contain code or a flutter-style `// TODO(handle): …` comment explaining the gap. Empty
  catch clauses are excused. An empty callback is a violation; give it work or a TODO.
  The intended escape valve is `// ignore: no-empty-block` with a one-line explanation —
  not a routine override.
- **`newline-before-return`** — separate a block-final `return` from preceding statements
  with one blank line. Inline guards like `if (cond) return;` do not need it.
- **`prefer-commenting-analyzer-ignores`** — every `// ignore:` line needs a `//`
  explanation adjacent to it (above, below, or appended). Dartdoc (`///`) does not count.
- **`avoid-returning-widgets`** — building-block helpers that return a `Widget` fragment
  trip this rule. Prefer subclassing `StatelessWidget` for any helper that is reused or
  appears more than once (an overlay painter's chrome, a scan-box frame). When a one-off
  helper is genuinely warranted, annotate the occurrence with a single-line `// ignore:`
  carrying a reason.
- **`prefer-correct-edge-insets-constructor`** — always pick the simplest valid
  `EdgeInsets[Directional]` constructor: `EdgeInsets.all(0)` → `EdgeInsets.zero`; all
  sides equal → `.all(v)`; `start == end && top == bottom` → `.symmetric(...)`; any side
  zero → `.only(...)` listing only the non-zero sides. Applies even when mirroring an
  upstream constant verbatim; if the upstream form is preserved for traceability, record
  it in the constant's dartdoc alongside the simplified value.

---

<a id="swift-ios-macos"></a>
## Swift (iOS)

The iOS side is Swift (Vision + AVFoundation). There is **no Swift
analyzer gate** in CI — these conventions are applied by hand, like the DCM rules above.
If a linter is ever wired, SwiftLint/`swift-format` should encode these rather than
replace them.

- **Two-space indentation.** Matches the Flutter plugin template this repo was scaffolded
  from and `.editorconfig`'s `[*.swift]` block. Don't reformat to 4.
- **System frameworks only — `import Vision`, `import AVFoundation`, `import CoreMedia`,
  `import CoreVideo`, `import Flutter`.** Never add a third-party dependency on this side.
  This is the load-bearing rule of the whole package (no GoogleMLKit on Apple platforms)
  and it's enforced structurally by the podspec / `Package.swift` carrying no
  dependencies — see [*Hard rules*](./.ai/AGENTS.md#hard-rules) and
  [`APPENDIX.md#no-bundling`](./APPENDIX.md#no-bundling). If you find yourself wanting a
  pod, stop and reconsider.
- **`guard … else { return }` for early exits; never force-unwrap (`!`).** Optionals
  from the capture pipeline (`CMSampleBufferGetImageBuffer`, `topCandidates(1).first`)
  are unwrapped with `guard let`. The per-frame backpressure check is the canonical
  shape:

  ```swift
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
    guard !isProcessing, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    else { return }   // drop the frame; no queueing
    isProcessing = true
    // …perform the Vision request, then isProcessing = false
  }
  ```

  Implicitly-unwrapped optionals (`var x: Foo!`) are out except where a framework
  contract forces them.
- **Run Vision off the main thread; marshal results back to main before the
  `EventChannel` sink.** The sample-buffer delegate already runs on its own queue —
  perform the `VNImageRequestHandler` there, then hop to `DispatchQueue.main` to emit. A
  result sent from a background thread to a Flutter sink is a crash waiting to happen.
- **`let` by default; `var` only for genuine mutable state** (the `isProcessing` flag,
  the texture id). Prefer `struct` for value types crossing into Dart.
- **Access control is explicit and minimal.** `public` only on the `FlutterPlugin`
  registration surface and what the channel genuinely needs; default `internal`;
  `private` for helpers and stored pipeline state.
- **`try?` to drop a failed *frame*, `do/catch` when a failure must surface.** A single
  Vision `perform` that throws on one live frame should drop that frame (`try?`), not
  tear down the session. A one-shot still-image recognise that fails *is* a reportable
  error — `do/catch` and propagate it to Dart.
- **Name things in full**, same as Dart: `pixelBuffer` not `pb`, `recognizedLine` not
  `rl`. Apple-API initialisms already capitalised by the SDK (`VNRecognizedTextObservation`)
  stay; your own identifiers expand. Normalise Vision's bottom-left bounding boxes to
  top-left **here**, in native code, with a named helper — not in Dart (see
  [`APPENDIX.md#coordinate-normalization`](./APPENDIX.md#coordinate-normalization)).

---

<a id="kotlin-android"></a>
## Kotlin (Android)

The Android side (CameraX + ML Kit) is Kotlin. No Kotlin analyzer gate runs in CI —
conventions are applied by hand. If `ktlint`/`detekt` is ever wired, it should encode
these.

- **Four-space indentation.** Matches the scaffold, the official Kotlin style guide, and
  `.editorconfig`'s `[{*.kt,*.kts,*.gradle.kts}]` block.
- **Stay on Flutter's built-in Kotlin.** Use the Flutter Gradle `plugins {}` DSL — **not**
  the legacy `apply plugin: 'kotlin-android'` + buildscript classpath. The whole point of
  this package is killing deprecation warnings; don't let the Android module emit the new
  KGP warning. See [*Hard rules*](./.ai/AGENTS.md#hard-rules).
- **ML Kit and CameraX dependencies live only in `android/build.gradle.kts`.** They never
  appear as Dart `pubspec.yaml` dependencies — that's the no-bundling contract from the
  Android side ([`APPENDIX.md#no-bundling`](./APPENDIX.md#no-bundling)).
- **Null-safety: prefer non-null types; use `?.` / `?:` / `let`, never `!!`.** The
  analyze entry point is the model:

  ```kotlin
  @OptIn(ExperimentalGetImage::class)
  private fun analyze(proxy: ImageProxy) {
      val mediaImage = proxy.image ?: return proxy.close()   // Elvis, not !!
      val input = InputImage.fromMediaImage(mediaImage, proxy.imageInfo.rotationDegrees)
      recognizer.process(input)
          .addOnSuccessListener { visionText -> /* map → RecognizedLine[], emit */ }
          .addOnCompleteListener { proxy.close() }   // MANDATORY — backpressure release
  }
  ```

- **`imageProxy.close()` in `addOnCompleteListener` is mandatory.** With
  `STRATEGY_KEEP_ONLY_LATEST`, the next frame is not delivered until the current proxy is
  closed — forgetting `close()` silently stalls the stream. Treat it as a correctness
  invariant, not a style nicety (it's also called out in
  [*Hard rules*](./.ai/AGENTS.md#hard-rules)).
- **Run ML Kit off the platform main thread; marshal results back to main for the
  `EventSink`.** Same reasoning as the Swift side.
- **`val` by default; `data class` for value types.** Mutable `var` only for genuine
  state. Use scope functions (`let` / `apply` / `also` / `run`) idiomatically, but don't
  nest them into unreadable towers.
- **Expression bodies for one-liners** (`fun foo() = …`), expand when a body needs
  statements. Spell out domain terms (`recognizedLine`, not `rl`); ML Kit normalises rects
  to pixel coords in the rotated image space — convert to top-left `[0,1]` **here**, with
  a named helper, before crossing into Dart
  ([`APPENDIX.md#coordinate-normalization`](./APPENDIX.md#coordinate-normalization)).

---

<a id="shell-scripts"></a>
## Shell scripts

- **`shellcheck` is the lint contract** for `scripts/*.sh`, mirroring `flutter analyze`
  for Dart. Run via `shellcheck scripts/*.sh`; `scripts/release.sh` preflight enforces
  it. Install with `brew install shellcheck`.
- **Prefer `# shellcheck disable=SC<code>` + a one-line "why" comment over refactoring
  for simple cases.** Refactor when the warning points at a real bug or the rewrite is
  genuinely clearer; reach for the directive when the code is correct as-is and
  ShellCheck's analysis is just over-conservative (e.g. SC2154 inside a quoted trap body).
  Always pair the directive with a comment so the next reader knows it's intentional, not
  a TODO.

---

<a id="documentation-conventions-markdown"></a>
## Documentation conventions (Markdown)

- **APPENDIX.md is the source of truth for rationale.** Hard rules, pitfalls, and
  workflow stay in `.ai/AGENTS.md` and `.ai/CLAUDE.md`; the "why we do it this way"
  essays live in [`APPENDIX.md`](./APPENDIX.md).
- **Explicit `<a id="…">` anchors** sit above every APPENDIX (and CODESTYLE) heading.
  Link to sections via the anchor, not the heading text.
- **Anchor stability is load-bearing.** When renaming a heading, keep the existing
  anchor. If you must change it, `rg '#<old-anchor>'` across the repo and update every
  caller in the same change.
- **Bare `flutter` / `dart` in command examples, never `fvm flutter` / `fvm dart`.** FVM
  is a local implementation detail — `.fvmrc` pins the channel. Docs (this file,
  README.md, AGENTS.md, CLAUDE.md, APPENDIX.md) stay tool-agnostic so external
  contributors aren't forced into FVM. The maintainer's shell aliases `flutter` / `dart`
  to the pinned toolchain for interactive use; scripts under `scripts/` prepend
  `.fvm/flutter_sdk/bin` to `PATH` if the symlink exists (so FVM users get the project
  pin) and fall back to whatever is on `PATH` otherwise — non-FVM contributors run the
  scripts unchanged.
