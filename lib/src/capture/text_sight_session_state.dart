import 'package:meta/meta.dart';

/// What the live capture session is doing, as native reports it. Whether recognition is actually
/// running is a separate thing, see `TextSightController.isRecognizing`.
@immutable
sealed class const TextSightSessionState() {
  /// Const base constructor.
  this;
}

/// No session: before `start()`, after `dispose()`, or mid-swap while a re-initialize runs.
final class const SessionIdle() extends TextSightSessionState {
  /// Creates it.
  this;

  @override
  bool operator ==(Object other) => other is SessionIdle;

  @override
  int get hashCode => (SessionIdle).hashCode;

  @override
  String toString() => 'SessionIdle()';
}

/// Running. Frames are only recognized while `isRecognizing` is on and something listens to
/// `captures`.
final class const SessionActive() extends TextSightSessionState {
  /// Creates it.
  this;

  @override
  bool operator ==(Object other) => other is SessionActive;

  @override
  int get hashCode => (SessionActive).hashCode;

  @override
  String toString() => 'SessionActive()';
}

/// Alive but not delivering. The plugin picks it back up itself once the cause lifts.
final class const SessionPaused({
  /// What paused it.
  required final SessionPauseReason reason,

  /// The platform's own wording, for logs only.
  final String? details,
}) extends TextSightSessionState {
  /// Creates it.
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

/// Stopped on an error and parked there until `start()`. Failures of your own calls throw at the
/// call site instead.
final class const SessionFailed({
  /// The platform's own wording, for logs only.
  final String? details,
}) extends TextSightSessionState {
  /// Creates it.
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
  /// The app left the foreground. The plugin restarts the camera on the way back.
  appBackgrounded,

  /// The OS took the camera (a call, another app). Delivery resumes when it hands it back.
  interrupted,
}
