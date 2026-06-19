Example-app code style.
Library-package style lives in [`../CODESTYLE.md`](../CODESTYLE.md);
project facts and scope live in [`.ai/AGENTS.md`](./.ai/AGENTS.md).

Each heading below carries an explicit `<a id="…">` anchor. Link by anchor, not by
heading text, so renames don't break callers.

- [MVVM architecture](#mvvm-architecture)
- [Reactivity (ValueNotifier-first)](#reactivity-valuenotifier-first)
- [Naming](#naming)
    * [Boolean fields — modal verbs](#boolean-fields-modal-verbs)
    * [Callback methods — view-event suffix](#callback-methods-view-event-suffix)
- [ViewModel member ordering](#viewmodel-member-ordering)
- [Separation of concerns](#separation-of-concerns)
- [Widget composition](#widget-composition)
    * [Native widget parameters](#native-widget-parameters)
    * [Spacing — rule of 8](#spacing-rule-of-8)
    * [Platform-adaptive widgets](#platform-adaptive-widgets)
- [Async-action buttons](#async-action-buttons)

<a id="mvvm"></a>
## MVVM architecture

The example uses [pmvvm](https://pub.dev/packages/pmvvm) —
`MVVM.builder(viewModel: …, viewBuilder: …)` binds a `ViewModel` to a
`StatelessWidget` view. Each feature is a pair:
`lib/features/<feature>/<feature>_view.dart` + `<feature>_view_model.dart`.
Cross-feature shared widgets, constants, and platform shims live under
`lib/features/core/`. The landing hub (`features/core/views/home_view.dart`) pushes
each feature with `Navigator.push(MaterialPageRoute)`.

---

<a id="reactivity"></a>
## Reactivity (ValueNotifier-first)

All observable VM state is exposed as `ValueListenable<T>`, backed by a private
`ValueNotifier<T>`. Views subscribe via `ValueListenableBuilder`.

- **No `notifyListeners()`.** Every state-mutating method writes
  `_xNotifier.value = …` on the relevant notifier. `MVVM.builder`'s outer
  `viewBuilder` becomes a static frame; pmvvm earns its keep as DI + lifecycle, not as
  a rebuild trigger.
- **Naming: `_xNotifier` for the private field, `xListenable` for the public getter.**

  ```dart
  final _shouldUseAccurateNotifier = ValueNotifier(false);

  ValueListenable<bool> get shouldUseAccurateListenable => _shouldUseAccurateNotifier;
  ```

  The suffixes make it unambiguous which side reads vs. writes, and prevent the
  bare-noun field from colliding with the getter name. The view binds the getter; it
  cannot mutate.
- **Omit the obvious `<T>` on `ValueNotifier(…)`.** When the initial value pins the
  type, drop the explicit type argument (`ValueNotifier(false)`,
  `ValueNotifier(RecognitionLevel.accurate)`). Keep it only when the initial value is
  `null` and inference cannot recover the type (`ValueNotifier<TextSightCapture?>(null)`).
- **Group co-updated fields into one notifier with a record type.** Fields always
  written together — `(capture, elapsed)`, `(roi, level)` — share one
  `ValueNotifier<({…})?>`. One write per logical update, one tick per rebuild.
  Splitting them costs extra notifier ceremony and extra ticks for zero gain when they
  always move in lockstep. Promote the record to a top-level `typedef` so the public
  listenable's type does not fail the `library_private_types_in_public_api` lint.
- **Dispose every notifier in `dispose()`** before `super.dispose()`.
- **VM-internal state stays plain.** Fields no widget observes (e.g. a
  `StreamSubscription`, a cached `Stopwatch`) are plain Dart fields — no notifier
  ceremony.

---

<a id="naming"></a>
## Naming

<a id="naming-booleans"></a>
### Boolean fields — modal verbs

For boolean values and their derivatives (notifiers, listenables, getters), prefix
the identifier with a **modal verb** — `should`, `can`, `may`, `would`, `must` — to
make the read-site speak plain English. The bare-noun form (`useAccurate`,
`showConfidence`) reads as a noun and forces the reader to mentally add the verb.

- ★ Default to `should` for user preferences and UI toggle state — declarative,
  expresses the intent the user is encoding (`shouldUseAccurate`, `shouldShowConfidence`).
- Reach for `can` when the bool gates a capability rather than a preference
  (`canUseTorch`), `may` when it gates permission, `would` for hypothetical intent in
  unrun branches.

This applies to the field, its notifier, and its listenable getter together — they
refer to the same concept, so the modal-prefix stays consistent across the trio.
Callback method names (e.g. `onTorchToggled`) describe the **event** and continue to
match the UI label, so they keep the bare-noun form even when they mutate a `shouldXxx`
field — the event and the state describe different things.

<a id="naming-callbacks"></a>
### Callback methods — view-event suffix

VM methods invoked from the view are named **from the view's perspective**: what the
user did, not what the VM does in response. Pattern: `on<Event>` with a suffix
matching the widget kind that produced the event.

| Widget                          | Suffix     | Example                          |
|---------------------------------|------------|----------------------------------|
| `PlatformButton` (`onPressed`)  | `Pressed`  | `onRecognizePressed`             |
| `PlatformSwitch`                | `Toggled`  | `onTorchToggled`                 |
| `PlatformSlider.onChanged`      | `Changed`  | `onRoiWidthSliderChanged`        |
| `PlatformSlider.onChangeEnd`    | `Released` | `onRoiWidthSliderReleased`       |
| `PlatformSegmentButton`         | `Selected` | `onLevelSelected`                |
| `PlatformTextField.onChanged`   | `Changed`  | `onLanguageChanged`              |

Avoid VM-leaking names like `setX`, `runX`, `commitX`, `forceX` — those describe what
the VM does internally. The VM is still free to do whatever it likes inside the method
body (start a session, recompute a capture, toggle the torch); only the method *name*
must reflect the view event.

**Named-arg style** — keep the parameter name on the call site when the type is
bare-`bool` (and elsewhere where `avoid_positional_boolean_parameters` would fire on
the VM signature):

```dart
// VM
void onTorchToggled({required bool value}) => _shouldEnableTorchNotifier.value = value;

// View
onChanged: (value) => viewModel.onTorchToggled(value: value),
```

---

<a id="vm-member-ordering"></a>
## ViewModel member ordering

Apply this ordering to every `ViewModel` subclass. It lets a reader scan dependencies
→ construction → state → lifecycle entry → reads → writes → teardown without
backtracking.

1. **External-ref fields** — DI / services / package controllers held by reference
   (e.g. a `TextSightController`).
2. **Constructors** — unnamed first, then factories. Constructors assign to the
   external-ref fields.
3. **State fields** — notifiers, controllers, `late` subscriptions. Static class-level
   constants live with this group at the top.
4. **`init()`** — lifecycle entry; sets up streams / subscriptions / the session.
5. **Getters** — the `xListenable` getters and any other pure reads.
6. **Getter-like methods** — pure / near-pure reads expressed as methods (rare).
7. **Logic methods** — `on<Event>` handlers and complex orchestration. Simplest first
   if you can rank them; otherwise grouped by feature.
8. **Private helpers** — static helpers go at the end of this group.
9. **`dispose()`** — teardown, last.

---

<a id="separation-of-concerns"></a>
## Separation of concerns

- **The view is agnostic to the VM's inner workings.** It reads VM state, invokes VM
  callbacks, renders widgets. It does NOT know *how* the VM implements an action — only
  *what event* it is reporting.
- **Widget-state holding domain input belongs on the VM.** The package's
  `TextSightController`, a `TextEditingController`, a `FocusNode` — these carry state
  the VM operates on (starts a session, validates a language tag). The VM owns
  construction and disposal; the view binds directly
  (`TextSightView(controller: viewModel.controller)`). They ARE the state, not
  implementation to hide.
- **Widget-state describing pure UI presentation belongs on the view.** "This button is
  mid-async, show a spinner" is purely visual — no VM logic and no other widget consumes
  it. Use `tap_debouncer` (via `AsyncIconActionButton`) so the view tracks its own
  in-flight gate. Do NOT add an `isRunning` field on the VM for this.

---

<a id="widget-composition"></a>
## Widget composition

<a id="widget-native-params"></a>
### Native widget parameters

When a widget exposes a native parameter for what you need, use it. Do not reinvent it
with extra children, padding wrappers, or string tricks.

- **`Row(spacing:)` / `Column(spacing:)` over interleaved `Gap` / `SizedBox`.** Use
  whenever the gap should be uniform between every adjacent child pair.
- **`spacing:` over trailing whitespace in label strings.** A `Text('Languages:  ')`
  with magic trailing spaces is a hack; `Row(spacing: 8, children: […])` is the
  intended primitive.
- **`Gap` stays for `ListView` children** (no `spacing` parameter available) and for
  genuinely non-uniform sequences.

<a id="widget-spacing"></a>
### Spacing — rule of 8

All spacing values (`Gap`, `spacing:`, `Padding`, `EdgeInsets`, margins) follow an
8-pixel grid.

- **Default ladder: `8 → 16 → 24 → 32 …`** — multiples of 8 for any spacing ≥ 8.
- **Sub-8 escape hatch: `2`, `4`, `8`.** Used only when an 8-grid value would be too
  generous (tight typography, internal row padding, list-card vertical margin). Other
  sub-8 values (3, 5, 6, 7) are effectively never right.
- **`12` is rare** and almost always a sign of splitting the difference between 8 and
  16. Convert to 8 or 16 unless there's a concrete reason; if kept, drop a one-line
  `//` comment explaining why.
- **`PlatformCard` content `Padding`: `.all(16)`** by default — matches Material 3's
  standard content padding.
- **`PlatformCard` vertical margin in a list: `4`** (8 total between cards). Horizontal
  margin: `16` for screen-edge inset.

<a id="widget-platform-adaptive"></a>
### Platform-adaptive widgets

The example renders through
[`platform_adaptive_widgets`](https://pub.dev/packages/platform_adaptive_widgets) —
`PlatformScaffold`, `PlatformAppBar`, `PlatformButton`, `PlatformSlider`,
`PlatformSwitch`, `PlatformSegmentButton`, `PlatformListTile`,
`PlatformProgressIndicator` — so each screen is Material on Android and Cupertino on
iOS from a single widget tree. Things the library's surface does NOT enforce, all
iOS-only (Android's Material `Scaffold` masks them):

- **Wrap every `PlatformScaffold` body in `SafeArea`.** On iOS the scaffold is a
  `CupertinoPageScaffold`, which lets the body sit *behind* the translucent nav bar.
  Without the wrap, the top of a scrolling body hides under the bar.
- **Plug missing widgets under [`platform/`](lib/features/core/widgets/platform/), one
  per file, built on `PlatformWidget`.** `platform_adaptive_widgets` ships no
  `PlatformCard` / `PlatformChip` (Cupertino has no native equivalent), and a bare
  Material `Chip` throws "No Material widget found" under `CupertinoPageScaffold`. Build
  the stand-in with the public `PlatformWidget(materialBuilder:, cupertinoBuilder:)`
  escape hatch. These are temporary — they move into the base library later.
- **Keep `cupertino_icons` in `dependencies`.** The iOS nav bar's back chevron is a
  `CupertinoIcons` glyph; without that font bundled it renders as tofu.
  `uses-material-design: true` only covers the Material icon font.
- **Icons: `PlatformIcon(PlatformIcons.x)` where
  [platform_icons](https://pub.dev/packages/platform_icons) has the glyph,
  `Icon(context.platformIcon(material:, cupertino:))` for the rest.**
- **Colours: define them as `ConstTheme.<name>(context)` methods, never inline
  `Colors.*`.** Each wraps `platformValue(material:, cupertino:)` in
  `CupertinoDynamicColor.resolve(..., context)`, so Android gets the Material hue and
  iOS gets the matching dark-mode-resolved `CupertinoColors.system*`. Methods take a
  `BuildContext`, so they can't be `const` — drop `const` on widgets that consume them.
  The demo uses this for the confidence-tier palette (high/medium/low → green/orange/red)
  and the bounding-box stroke.
- **Import `platform_adaptive_widgets` and `platform_icons` wholesale — no `show`.**
  They *are* the adaptive default this example showcases. Reserve `show` for two cases:
  (1) `material_ui` / `flutter/cupertino` imports, where the narrow list is a deliberate
  signal this file is *diverging* from the platform look (`show Icons`, `show Colors`,
  `show CupertinoIcons`); and (2) a genuine name collision the analyzer flags.

---

<a id="async-action-buttons"></a>
## Async-action buttons

Every async button uses `AsyncIconActionButton`
(`lib/features/core/widgets/async_icon_action_button.dart`), which wraps `tap_debouncer`
with `cooldown: Duration.zero` and `PlatformButton.icon`. This:

- Removes the need for an `isRunning` field on the VM.
- Locks the button (via `isEnabled`) while the async work is in flight and re-arms
  immediately on completion.
- Standardises the busy state (a `PlatformProgressIndicator` spinner + busy label).

```dart
AsyncIconActionButton(
  onPressed: viewModel.onRecognizePressed,
  idleIcon: PlatformIcons.playFilled,
  idleLabel: 'Recognize',
  busyLabel: 'Recognizing…',
)
```
