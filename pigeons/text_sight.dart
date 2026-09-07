// Pigeon-only syntax (mutable data fields, undocumented transport twins) that never ships
// ignore_for_file: prefer-match-file-name
// ignore_for_file: avoid_positional_boolean_parameters

// Pigeon schema: the dev-time transport behind the control API, never public. These message
// classes are private twins of the public types, mapped by `TextSightPlatform`'s implementation.
// Per-frame results ride a plain EventChannel instead, which is why no @EventChannelApi shows up.
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
  new({required this.left, required this.top, required this.width, required this.height});

  double left;
  double top;
  double width;
  double height;
}

/// Transport twin of the public `TextSightOptions`.
class TextSightOptionsMessage {
  new({
    required this.level,
    required this.usesLanguageCorrection,
    required this.languages,
    required this.minimumTextHeight,
    this.roi,
  });

  RecognitionLevelMessage level;

  /// Whether the recognizer fixes likely misreads against a lexicon. Vision only.
  bool usesLanguageCorrection;
  List<String> languages;

  /// Smallest text to read, as a fraction of the scan box. Vision shrinks the image to suit, so 0
  /// keeps every pixel. ML Kit has no such dial, so Android ignores it.
  double minimumTextHeight;
  RegionOfInterestMessage? roi;
}

/// Transport twin of the public `ConfidenceScale`.
enum ConfidenceScaleMessage { visionGraded, visionCoarse, mlKit }

/// Transport twin of the public `CaptureResolution`.
enum CaptureResolutionMessage { low, medium, high }

/// Transport twin of the public `CameraPermissionStatus`.
enum CameraPermissionStatusMessage { granted, denied, permanentlyDenied }

/// The typed control channel. Per-frame results stream over a plain
/// EventChannel and the preview is a texture. Neither rides this API.
@HostApi()
abstract class TextSightHostApi {
  /// Opens the camera with [options] at [resolution]. Returns the preview texture id.
  ///
  /// Reopening an already-open session is fine: the old one is released first, so the id this
  /// returns replaces the previous one. Recognition comes back off until [start]. Resolution rides
  /// here, not on the options, because it cannot change mid-session.
  @async
  int initialize(TextSightOptionsMessage options, CaptureResolutionMessage resolution);

  /// Begins frame delivery and recognition. Not `@async`: both natives only flip a flag, and the
  /// Dart signature is `Future<void>` either way.
  void start();

  /// Pauses recognition, keeping the session open for a later [start]. Not `@async`, as [start].
  void pauseRecognition();

  /// Releases the camera and texture. Idempotent, so calling it with nothing open is fine.
  @async
  void dispose();

  // Camera permission: the live camera path needs it, the static one-shot does not. The check is a
  // synchronous status read, and the request is async because it drives the system prompt.

  /// Reports the current camera-permission status without prompting.
  CameraPermissionStatusMessage checkCameraPermission();

  /// Prompts for camera permission when it has not yet been decided, resolving to the resulting status.
  @async
  CameraPermissionStatusMessage requestCameraPermission();

  /// Replaces the recognizer settings on an open session. Resolution is not in here, it cannot
  /// change mid-session, so it rides [initialize] instead.
  void setOptions(TextSightOptionsMessage options);

  /// Turns the camera torch on or off.
  void setTorchEnabled(bool enabled);

  /// What a per-line confidence means on this device. Fixed once the engine is picked, so the
  /// Dart side reads it once and caches.
  ConfidenceScaleMessage confidenceScale();

  // Readiness sits here because both drivers share the one model. Progress streams over
  // com.lahaluhem.text_sight/readiness, so this call only hands back the final state.

  /// Ensures the recognition model is present (fetching the unbundled ML Kit model via
  /// Google Play Services when needed) and returns the terminal readiness state.
  @async
  Map<String, Object?> ensureModelReady();

  // Static one-shot driver: no camera session, texture, or permission. Each call runs a
  // transient native recognizer over a still image and returns the same self-describing
  // per-frame map the captures EventChannel emits (decoded Dart-side by `_decodeCapture`), so
  // the result models need no Pigeon twin. `quarterTurns` is 0, since a still is already upright.

  /// Recognizes text in the encoded image [bytes] (PNG/JPEG/…), honouring [options].
  @async
  Map<String, Object?> recognizeImage(Uint8List bytes, TextSightOptionsMessage options);

  /// Recognizes text in the image at file [path], honouring [options].
  @async
  Map<String, Object?> recognizePath(String path, TextSightOptionsMessage options);
}
