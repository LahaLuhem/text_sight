import 'package:meta/meta.dart';

/// The live capture session's state, as native reports it. Sealed for exhaustive switches,
/// value-equal so a repeated report is a no-op. Recognition is a separate axis, see
/// `TextSightController.isRecognizing`.
@immutable
sealed class TextSightSessionState {
  /// Const base constructor for the sealed hierarchy.
  const new();
}

/// No capture session: before `start()`, after `dispose()`, or while a re-initialize swaps sessions.
final class SessionIdle extends TextSightSessionState {
  /// Creates the idle state.
  const new();

  @override
  bool operator ==(Object other) => other is SessionIdle;

  @override
  int get hashCode => (SessionIdle).hashCode;

  @override
  String toString() => 'SessionIdle()';
}

/// The capture session is running. Frames are recognized only while `isRecognizing` is on and
/// something listens to `captures`.
final class SessionActive extends TextSightSessionState {
  /// Creates the active state.
  const new();

  @override
  bool operator ==(Object other) => other is SessionActive;

  @override
  int get hashCode => (SessionActive).hashCode;

  @override
  String toString() => 'SessionActive()';
}

/// The session exists but is not delivering. The plugin resumes it itself once the cause lifts.
final class SessionPaused extends TextSightSessionState {
  /// What paused the session.
  final SessionPauseReason reason;

  /// The platform's own wording, for logs only.
  final String? details;

  /// Creates the paused state.
  const new({required this.reason, this.details});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionPaused && other.reason == reason && other.details == details;

  @override
  int get hashCode => Object.hash(reason, details);

  @override
  String toString() => 'SessionPaused(reason: $reason, details: $details)';
}

/// The session stopped on an error and stays parked until `start()`. Failures of your own calls
/// throw at the call site instead.
final class SessionFailed extends TextSightSessionState {
  /// The platform's own wording, for logs only.
  final String? details;

  /// Creates the failed state.
  const new({this.details});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SessionFailed && other.details == details;

  @override
  int get hashCode => details.hashCode;

  @override
  String toString() => 'SessionFailed(details: $details)';
}

/// Why a [SessionPaused] session is paused.
enum SessionPauseReason {
  /// The app left the foreground. The plugin restarts the camera on return.
  appBackgrounded,

  /// The OS took the camera (a call, another app). Delivery resumes when it hands it back.
  interrupted,
}
