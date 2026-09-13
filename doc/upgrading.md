# Upgrading to 1.0

Two reshuffles. The camera session got a state model, and every Vision-only setting moved behind
`darwin`, so Android can no longer be handed a setting it silently drops.

## Renames

| 0.2                        | 1.0                                                                                         |
|----------------------------|---------------------------------------------------------------------------------------------|
| `controller.stop()`        | `controller.pauseRecognition()`                                                             |
| `controller.isRunning`     | `controller.isRecognizing`                                                                  |
|                            | `controller.sessionState`, new. [What it's for](../README.md#know-what-the-camera-is-doing) |
| `updateRecognitionLevel()` | `updateOptions()`                                                                           |
| `updateLanguages()`        | `updateOptions()`                                                                           |
| `updateRegionOfInterest()` | `updateOptions()`                                                                           |
| the three matching getters | one `controller.options`                                                                    |
| `line.confidence ?? 1`     | `line.confidence`, non-null now                                                             |

## Options regrouped

`roi` is the only one left at the top, being the only one both platforms honour.

```dart
// 0.2
TextSightOptions(level: RecognitionLevel.accurate, languages: [Locale('de')], roi: box);

// 1.0
TextSightOptions(
  roi: box,
  darwin: DarwinOptions(
    recognitionLevel: RecognitionLevel.accurate,
    preferredLanguages: [Locale('de')],
  ),
);
```

## Two changes the compiler won't catch

- **`fast` corrects by default now.** Correction used to ride on the level, off for `fast` and on
  for `accurate`, so `level.usesLanguageCorrection` is gone. It's
  `DarwinOptions.usesLanguageCorrection` now, defaulting on. Pass `usesLanguageCorrection: false`
  for the old `fast`.
- **Android stopped pretending.** `updateRecognitionLevel()` and `updateLanguages()` reported
  success there and did nothing at all. Under `darwin`, ignoring them is the stated contract.

`captures` is unchanged. A test fake of `TextSightPlatform` needs `sessionStates` once it starts a
controller.
