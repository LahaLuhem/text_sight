// Pigeon-specific syntax (mutable data fields,undocumented transport twins, etc) that is not shipped code
// ignore_for_file: prefer-match-file-name
// ignore_for_file: avoid_positional_boolean_parameters

// Pigeon schema — the INTERNAL, dev-time transport for the typed control API.
//
// These message classes are Pigeon-private twins of the public types: per the
// channel-topology decision, Pigeon stays an implementation detail and the
// public API is hand-written, so `TextSightPlatform`'s concrete implementation
// maps public <-> message types. Per-frame results do NOT ride Pigeon — they
// stream over a plain EventChannel — so no @EventChannelApi appears here.
@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'text_sight',
    dartOut: 'lib/src/platform/messages.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/lahaluhem/text_sight/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.lahaluhem.text_sight'),
    swiftOut: 'ios/text_sight/Sources/text_sight/Messages.g.swift',
  ),
)
library;

import 'package:pigeon/pigeon.dart';

/// Transport twin of the public `RecognitionLevel`.
enum RecognitionLevelMessage { fast, accurate }

/// Transport twin of the public `Rect` region-of-interest (normalized [0,1] top-left).
class RegionOfInterestMessage {
  RegionOfInterestMessage({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double left;
  double top;
  double width;
  double height;
}

/// Transport twin of the public `TextSightOptions`.
class TextSightOptionsMessage {
  TextSightOptionsMessage({required this.level, required this.languages, this.roi});

  RecognitionLevelMessage level;
  List<String> languages;
  RegionOfInterestMessage? roi;
}

/// Transport twin of the public `CameraPermissionStatus`.
enum CameraPermissionStatusMessage { granted, denied, permanentlyDenied }

/// The typed control channel. Per-frame results stream over a plain
/// EventChannel and the preview is a texture — neither rides this API.
@HostApi()
abstract class TextSightHostApi {
  /// Opens the camera with [options]; returns the preview texture id.
  @async
  int initialize(TextSightOptionsMessage options);

  /// Begins frame delivery and recognition.
  @async
  void start();

  /// Pauses recognition, keeping the session open for a later [start].
  @async
  void stop();

  /// Releases the camera and texture.
  @async
  void dispose();

  // Camera permission — the live camera path needs it; the static one-shot does not. The check is a
  // synchronous status read; the request is async because it drives the system prompt.

  /// Reports the current camera-permission status without prompting.
  CameraPermissionStatusMessage checkCameraPermission();

  /// Prompts for camera permission when it has not yet been decided, resolving to the resulting status.
  @async
  CameraPermissionStatusMessage requestCameraPermission();

  /// Restricts recognition to [roi], or clears it (whole frame) when null.
  void setRegionOfInterest(RegionOfInterestMessage? roi);

  /// Switches the recognizer's accuracy/latency level.
  void setRecognitionLevel(RecognitionLevelMessage level);

  /// Replaces the preferred recognition languages (BCP-47 tags).
  void setLanguages(List<String> languages);

  /// Turns the camera torch on or off.
  void setTorchEnabled(bool enabled);

  // Model readiness — mode-agnostic (both drivers recognize through the same model), so it
  // rides this control API rather than either driver. Triggers a check-and-fetch of the
  // on-device model and returns the terminal readiness map (decoded Dart-side, the same
  // self-describing style as the recognize calls). Intermediate progress streams over a
  // plain EventChannel (com.lahaluhem.text_sight/readiness), not this method.

  /// Ensures the recognition model is present (fetching the unbundled ML Kit model via
  /// Google Play Services when needed) and returns the terminal readiness state.
  @async
  Map<String, Object?> ensureModelReady();

  // Static one-shot driver — no camera session, texture, or permission. Each call runs a
  // transient native recognizer over a still image and returns the same self-describing
  // per-frame map the captures EventChannel emits (decoded Dart-side by `_decodeCapture`), so
  // the result models need no Pigeon twin. `quarterTurns` is 0 — a still is already upright.

  /// Recognizes text in the encoded image [bytes] (PNG/JPEG/…), honouring [options].
  @async
  Map<String, Object?> recognizeImage(Uint8List bytes, TextSightOptionsMessage options);

  /// Recognizes text in the image at file [path], honouring [options].
  @async
  Map<String, Object?> recognizePath(String path, TextSightOptionsMessage options);
}
