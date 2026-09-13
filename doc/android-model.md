# The recognition model

iOS has nothing to do here. Vision ships with the OS, so there's no download and no waiting.

Android is the interesting one. The ML Kit model is **unbundled** by default: about 260 KB in your
APK, with the real thing pulled from Play Services the first time you use it. Most apps don't need
OCR the second they launch. The catch is that a scan started before the model lands comes back
empty.

## Give it a nudge

Call this when the user opens your scanner:

```dart
final state = await TextSightModel.ensureReady();
if (state is ModelUnavailable) {
  // No Play Services, or the download didn't make it. Offer a retry.
}
```

Call it as often as you like. It returns right away on iOS, and on Android too once the model is
around.

## Show the download

Want a progress bar? The readiness stream is a sealed type, so the compiler makes sure you've
handled every case:

```dart
TextSightModel.readiness.listen((state) {
  final label = switch (state) {
    ModelReady() => 'Ready to scan',
    ModelDownloading(:final progress) => 'Downloading… ${((progress ?? 0) * 100).round()}%',
    ModelUnavailable(:final reason) => 'Model unavailable ($reason)',
  };
});
```

The [`example/`](../example/) scanner does exactly this: `ensureReady()` to gate, the stream for a
real download bar.

## Or just bundle it

Ship the model inside your APK instead. One line in your app's `android/gradle.properties`:

```properties
com.lahaluhem.text_sight.useBundled=true
```

Now `ensureReady()` returns immediately and `ModelUnavailable` never shows up. You trade size for
it:

| Mode                  | App size                   | First use           | Offline              | Needs Play Services |
|-----------------------|----------------------------|---------------------|----------------------|---------------------|
| Unbundled *(default)* | ~260 KB                    | downloads on demand | after first download | yes                 |
| Bundled               | ~4 MB per script, per arch | instant             | yes                  | no                  |
