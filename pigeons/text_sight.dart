// Pigeon-only syntax (mutable data fields, undocumented transport twins) that never ships
// ignore_for_file: prefer-match-file-name
// ignore_for_file: avoid_positional_boolean_parameters
// Pigeon reads fields from the class body, so a primary constructor generates empty messages
// ignore_for_file: use_primary_constructors

// The dev-time transport behind the control API, never published. Every `*Message` below is the
// private twin of a public type, and `TextSightPlatform`'s implementation does the mapping.
// Per-frame results ride a plain EventChannel, which is why there's no @EventChannelApi here.
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

enum RecognitionLevelMessage { fast, accurate }

/// Normalized `[0, 1]` from the top-left, twinning the public `Rect`.
class RegionOfInterestMessage {
  new({required this.left, required this.top, required this.width, required this.height});

  double left;
  double top;
  double width;
  double height;
}

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

enum ConfidenceScaleMessage { visionGraded, visionCoarse, mlKit }

enum CaptureResolutionMessage { low, medium, high }

enum CameraPermissionStatusMessage { granted, denied, permanentlyDenied }

enum SessionPauseReasonMessage { appBackgrounded, interrupted }

/// One case per public session state. Pigeon needs the parent empty.
sealed class SessionStateMessage;

class SessionIdleMessage extends SessionStateMessage;

class SessionActiveMessage extends SessionStateMessage;

class SessionPausedMessage extends SessionStateMessage {
  new({required this.reason, this.details});

  SessionPauseReasonMessage reason;
  String? details;
}

class SessionFailedMessage extends SessionStateMessage {
  new({this.details});

  String? details;
}

/// The typed control channel. Per-frame results stream over a plain EventChannel and the preview is
/// a texture, so neither rides this API.
@HostApi()
abstract class TextSightHostApi {
  /// Opens the camera and returns the preview texture id. Reopening is fine, the old session is
  /// released first. Recognition stays off until [start].
  ///
  /// [resolution] rides here rather than on [setOptions] because it can't change mid-session.
  @async
  int initialize(TextSightOptionsMessage options, CaptureResolutionMessage resolution);

  /// Starts frame delivery and recognition. Not `@async`: both natives only flip a flag, and the
  /// Dart signature is `Future<void>` either way.
  void start();

  /// Stops recognizing, keeping the session open for a later [start]. Not `@async`, as [start].
  void pauseRecognition();

  /// Releases the camera and texture. Idempotent.
  @async
  void dispose();

  /// Reads the camera-permission status without prompting.
  CameraPermissionStatusMessage checkCameraPermission();

  /// Prompts when the user hasn't decided yet. `@async` because it drives the system prompt.
  @async
  CameraPermissionStatusMessage requestCameraPermission();

  /// Replaces the recognizer settings on an open session. Resolution isn't in here, see
  /// [initialize].
  void setOptions(TextSightOptionsMessage options);

  void setTorchEnabled(bool enabled);

  /// Fixed once the engine is picked, so the Dart side reads it once and caches.
  ConfidenceScaleMessage confidenceScale();

  /// Fetches the unbundled ML Kit model through Play Services when it's needed, and returns the
  /// terminal state. Progress streams over com.lahaluhem.text_sight/readiness instead.
  @async
  Map<String, Object?> ensureModelReady();

  // Both one-shots hand back the same self-describing map the captures EventChannel emits, so the
  // result models need no Pigeon twin at all. `quarterTurns` is 0, a still is already upright.

  /// Recognizes text in an encoded image (PNG, JPEG, …).
  @async
  Map<String, Object?> recognizeImage(Uint8List bytes, TextSightOptionsMessage options);

  /// Recognizes text in the image file at [path].
  @async
  Map<String, Object?> recognizePath(String path, TextSightOptionsMessage options);
}

/// Native-to-Dart notifications: rare and typed, so they ride Pigeon rather than an EventChannel.
@FlutterApi()
abstract class TextSightFlutterApi {
  /// Fired on every actual session transition native makes or observes.
  void onSessionStateChanged(SessionStateMessage state);
}
