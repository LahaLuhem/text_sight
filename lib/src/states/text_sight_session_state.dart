import 'package:meta/meta.dart';

/// The live camera session's state, as native reports it. Whether frames get read is separate,
/// see `TextSightController.isRecognizing`.
@immutable
sealed class const TextSightSessionState() {
  /// Const base constructor for the sealed hierarchy.
  this;
}

/// No camera session: before `start()`, after `dispose()`, or while a re-initialize swaps them.
final class const SessionIdle() extends TextSightSessionState {
  /// Creates the idle state.
  this;

  @override
  bool operator ==(Object other) => other is SessionIdle;

  @override
  int get hashCode => (SessionIdle).hashCode;

  @override
  String toString() => 'SessionIdle()';
}

/// The camera session is running. Frames are read only while `isRecognizing` is on and something
/// listens to `captures`.
final class const SessionActive() extends TextSightSessionState {
  /// Creates the active state.
  this;

  @override
  bool operator ==(Object other) => other is SessionActive;

  @override
  int get hashCode => (SessionActive).hashCode;

  @override
  String toString() => 'SessionActive()';
}

/// The session is open but sends no frames. The plugin resumes it once the cause goes away.
final class const SessionPaused({
  /// What paused the session.
  required final SessionPauseReason reason,

  /// The platform's own wording, for logs only.
  final String? details,
}) extends TextSightSessionState {
  /// Creates the paused state.
  this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionPaused && other.reason == reason && other.details == details;

  @override
  int get hashCode => Object.hash(reason, details);

  @override
  String toString() => 'SessionPaused(reason: $reason, details: $details)';
}

/// The session stopped on an error and stays stopped until `start()`. Your own calls throw their
/// failures instead.
final class const SessionFailed({
  /// The platform's own wording, for logs only.
  final String? details,
}) extends TextSightSessionState {
  /// Creates the failed state.
  this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SessionFailed && other.details == details;

  @override
  int get hashCode => details.hashCode;

  @override
  String toString() => 'SessionFailed(details: $details)';
}

/// Why a [SessionPaused] session is paused.
enum SessionPauseReason() {
  /// The app left the foreground. The plugin restarts the camera on return.
  appBackgrounded,

  /// The OS took the camera (a call, another app). Delivery resumes when it hands it back.
  interrupted,
}
