# example

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Running on a physical iOS device

The iOS Simulator needs no code signing — `flutter run` works as-is (it has no camera, so the live
scanner only shows the "no camera" state there; use a real device for live scanning). A **physical
device** needs an Apple Development Team and a bundle identifier your team can register. That is
per-developer state, so it must not land in the committed Xcode project — instead, create an
untracked override.

Create `ios/Flutter/LocalSigning.xcconfig` (gitignored) with your own values:

```
DEVELOPMENT_TEAM = ABCDE12345
PRODUCT_BUNDLE_IDENTIFIER = com.yourname.example.textSightExample
```

`Debug.xcconfig` / `Release.xcconfig` already `#include?` that file, so your values override the
committed defaults (lowercase id, empty team) without modifying anything tracked. Then `flutter run`
onto the device.

- Set the team **in that file**, not in Xcode's *Signing & Capabilities* tab — the Xcode UI writes
  `DEVELOPMENT_TEAM` straight back into the tracked `project.pbxproj`, which is what this avoids.
- Apple App IDs are globally unique **and case-insensitive**: if your chosen id (or a case-variant of
  it) is already registered to another team, you'll get "cannot be registered… not available" — just
  pick a different, unique string.

