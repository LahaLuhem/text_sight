## Running on a physical iOS device

The iOS Simulator needs no code signing, and `flutter run` works as-is. It has no camera, so the app
substitutes one (see below). Real capture still needs a **physical device**, which needs an Apple
Development Team and a bundle identifier your team can register. That is
per-developer state, so it must not land in the committed Xcode project. Instead, create an
untracked override.

Create `ios/Flutter/LocalSigning.xcconfig` (gitignored) with your own values:

```
DEVELOPMENT_TEAM = ABCDE12345
PRODUCT_BUNDLE_IDENTIFIER = com.yourname.example.textSightExample
```

`Debug.xcconfig` / `Release.xcconfig` already `#include?` that file, so your values override the
committed defaults (lowercase id, empty team) without modifying anything tracked. Then `flutter run`
onto the device.

- Set the team **in that file**, not in Xcode's *Signing & Capabilities* tab, because the Xcode UI writes
  `DEVELOPMENT_TEAM` straight back into the tracked `project.pbxproj`, which is what this avoids.
- Apple App IDs are globally unique **and case-insensitive**: if your chosen id (or a case-variant of
  it) is already registered to another team, you'll get "cannot be registered… not available". Just
  pick a different, unique string.

## The live scanner on the iOS Simulator

The Simulator has no capture hardware at all, so the plugin's `initialize()` can only fail there. To
keep the live scanner usable, `main()` swaps the platform seam for a stand-in whenever it detects a
Simulator. Nothing to enable, just `flutter run`.

The real screen, the real controller, the real `TextSightView`, and real recognition: every frame
goes through the same on-device recognizer the one-shot demo uses, so the boxes and the text panel
are genuine output. Only the capture session is fake.

### Pointing your Mac's webcam at it

Run any server that streams JPEG frames on `127.0.0.1:8765`, framed as a **4-byte big-endian
length followed by that many bytes of JPEG**, and the stand-in will use it. Then hold a page up to
your Mac's camera and watch the scanner read it.

[CamBridge](https://github.com/engelon/CamBridge) is one such server, a small menu bar app that
streams your webcam. The protocol is deliberately trivial, so anything that speaks it works and you
are not tied to a particular tool.

The corner card names the source, so you can tell at a glance whether the bridge took:

| Card says    | Meaning                                                                           |
|--------------|-----------------------------------------------------------------------------------|
| Mac camera   | Frames are arriving from the bridge                                               |
| Sample image | Nothing is listening on 8765, so the bundled sample is used, drifting (see below) |

The stand-in retries the connection forever, so starting the bridge after the app is fine, and
so is never starting it at all.

### The sample drifts on purpose

With no bridge running, the fallback would be a conveniently fixed scene, and fixed boxes over a
fixed image prove nothing about live tracking. So the sample is redrawn every tick with a small
drift and tilt, the way the Android emulator's virtual scene sways, and each redrawn frame is
recognized on its own. The boxes you see are then genuinely chasing a moving image.

The motion lives in `SwayingFrames`, tuned by four constants in one place. Composing and encoding a
frame measures about 8 ms, so the recognizer is what limits the rate, not the drawing.

### Why the confidence colours may be missing

The chips and the box strokes are tinted by confidence tier, green through orange to red, but only
where the engine's numbers can actually be ranked. Vision on iOS 18+ reports a **coarse** scale
that parks every line on the same value, so on a modern iPhone or Simulator the tiers switch off,
the chips render plain, and a line under the results says why.

That is `ConfidenceScale.isRankable`, which the demo reads once through `EngineConfidence` and
branches on, and it is the pattern to copy. The recognition level is not the knob: the scale
follows the backend, which follows the OS version. `fast` and `accurate` are both flat on iOS 18+,
just at different constants.

### Faking the states that need hardware

The same card drives the two session states you otherwise cannot reach:

| Button    | What it does                                                                       |
|-----------|------------------------------------------------------------------------------------|
| Interrupt | Pauses as if the OS took the camera, then hands it back after six seconds          |
| Fail      | Reports a capture failure and parks the session, so **Retry** is the only way back |

Backgrounding the app (`Cmd+Shift+H`) pauses it the same way the real plugin does.

The stand-in is a no-op on a physical device and on Android, so neither loses any coverage. It also
cannot tell you anything about the capture graph, the preview texture, torch, or rotation, which
stay device-only.
