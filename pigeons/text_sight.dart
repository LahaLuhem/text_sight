// Pigeon-only syntax (mutable fields, undocumented twins) that never ships.
// ignore_for_file: prefer-match-file-name
// ignore_for_file: avoid_positional_boolean_parameters

// The control channel's schema. Each message class is a private twin of a public type, mapped by
// `PigeonTextSightPlatform`. Per-frame results ride a plain EventChannel, hence no @EventChannelApi.
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

/// Transport twin of the scan box `Rect`, in `[0, 1]` from the top left.
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

  /// Whether the recognizer fixes likely misreads using a dictionary. Vision only.
  bool usesLanguageCorrection;
  List<String> languages;

  /// Smallest text to read, as a fraction of the frame height. ML Kit has no such dial, so Android
  /// ignores it.
  double minimumTextHeight;
  RegionOfInterestMessage? roi;
}

/// Transport twin of the public `ConfidenceScale`.
enum ConfidenceScaleMessage { visionGraded, visionCoarse, mlKit }

/// Transport twin of the public `CaptureResolution`.
enum CaptureResolutionMessage { low, medium, high }

/// Transport twin of the public `CameraPermissionStatus`.
enum CameraPermissionStatusMessage { granted, denied, permanentlyDenied }

/// Transport twin of the public `SessionPauseReason`.
enum SessionPauseReasonMessage { appBackgrounded, interrupted }

/// Transport twin of the public sealed `TextSightSessionState`, one case per state. Pigeon needs
/// the parent empty.
sealed class SessionStateMessage;

/// Twin of `SessionIdle`.
class SessionIdleMessage extends SessionStateMessage;

/// Twin of `SessionActive`.
class SessionActiveMessage extends SessionStateMessage;

/// Twin of `SessionPaused`.
class SessionPausedMessage extends SessionStateMessage {
  new({required this.reason, this.details});

  SessionPauseReasonMessage reason;
  String? details;
}

/// Twin of `SessionFailed`.
class SessionFailedMessage extends SessionStateMessage {
  new({this.details});

  String? details;
}

/// How to show the preview texture: its size once upright, and the clockwise quarter turns that
/// get it there. No public twin, since only `TextSightView` reads it.
class PreviewMessage {
  new({
    required this.textureId,
    required this.width,
    required this.height,
    required this.quarterTurns,
  });

  int textureId;
  int width;
  int height;
  int quarterTurns;
}

/// The control channel. Per-frame results stream over a plain EventChannel and the preview is a
/// texture, so neither rides here.
@HostApi()
abstract class TextSightHostApi {
  /// Opens the camera with [options] at [resolution]. Returns the preview texture id.
  ///
  /// Reopening an open session is fine, the old one is released first and this id replaces it.
  /// Recognition stays off until [start]. Resolution rides here because it cannot change
  /// mid-session.
  @async
  int initialize(TextSightOptionsMessage options, CaptureResolutionMessage resolution);

  /// Begins frame delivery and recognition. Not `@async`: both natives only flip a flag, and the
  /// Dart signature is `Future<void>` either way.
  void start();

  /// Pauses recognition, keeping the session open for a later [start]. Not `@async`, as [start].
  void pauseRecognition();

  /// Releases the camera and texture. Safe to call with nothing open.
  @async
  void dispose();

  // Only the live camera needs permission. The check is a plain read, and the request is async
  // because it waits on the system prompt.

  /// Reports the current camera-permission status without prompting.
  CameraPermissionStatusMessage checkCameraPermission();

  /// Prompts if the user hasn't decided yet, and resolves to the answer.
  @async
  CameraPermissionStatusMessage requestCameraPermission();

  /// Replaces the recognizer settings on an open session.
  void setOptions(TextSightOptionsMessage options);

  /// Turns the camera torch on or off.
  void setTorchEnabled(bool enabled);

  /// What a per-line confidence means on this device. Fixed once the engine is picked, so the
  /// Dart side reads it once and caches.
  ConfidenceScaleMessage confidenceScale();

  // Readiness sits here because both drivers share the one model. Progress streams over
  // com.lahaluhem.text_sight/readiness, so this call only hands back the final state.

  /// Fetches the model if it's missing (Android's default, through Play Services) and returns how
  /// that ended.
  @async
  Map<String, Object?> ensureModelReady();

  // The one-shot: no session, texture or permission. It returns the same map a live frame sends,
  // so the result models need no Pigeon twin.

  /// Reads text in the encoded image [bytes] (PNG, JPEG, …).
  @async
  Map<String, Object?> recognizeImage(Uint8List bytes, TextSightOptionsMessage options);

  /// Reads text in the image file at [path].
  @async
  Map<String, Object?> recognizePath(String path, TextSightOptionsMessage options);
}

/// Native-to-Dart notifications: rare and typed, so they ride Pigeon rather than an EventChannel.
@FlutterApi()
abstract class TextSightFlutterApi {
  /// Fired on every actual session transition native makes or observes.
  void onSessionStateChanged(SessionStateMessage state);

  /// Fired when the preview's size or turns change, recognition paused or not.
  void onPreviewChanged(PreviewMessage preview);
}
