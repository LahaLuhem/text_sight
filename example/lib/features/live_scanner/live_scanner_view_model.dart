import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pmvvm/pmvvm.dart';
import 'package:text_sight/text_sight.dart';

import 'data/enums/session_status.dart';

final class LiveScannerViewModel extends ViewModel {
  final _controller = TextSightController();

  final _sessionStatusNotifier = ValueNotifier(SessionStatus.preparingModel);
  final _shouldEnableTorchNotifier = ValueNotifier(false);
  String? _failure;
  SessionPauseReason? _pauseReason;

  @override
  void init() {
    _controller.addListener(_onSessionStateChanged);
    unawaited(_start());
  }

  /// The session controller, bound to the view's `TextSightView`, and the source of its
  /// `captures` stream.
  TextSightController get controller => _controller;

  ValueListenable<SessionStatus> get sessionStatusListenable => _sessionStatusNotifier;

  ValueListenable<bool> get shouldEnableTorchListenable => _shouldEnableTorchNotifier;

  /// The failure message, meaningful only while the status is [SessionStatus.failed].
  String get failure => _failure ?? 'Could not start the camera.';

  /// Why scanning is paused, meaningful only while the status is [SessionStatus.paused].
  String get pauseMessage => switch (_pauseReason) {
    SessionPauseReason.interrupted =>
      'The camera is in use elsewhere. Scanning resumes when it comes back.',
    SessionPauseReason.appBackgrounded || null => 'Paused while the app is in the background.',
  };

  Future<void> onRetryPressed() => _start();

  Future<void> onTorchToggled() async {
    final next = !_shouldEnableTorchNotifier.value;
    await _controller.updateTorchEnabled(enabled: next);
    _shouldEnableTorchNotifier.value = next;
  }

  /// Keeps the camera up but stops the recognizer, the thing to do when nobody reads the results.
  Future<void> onRecognitionToggled() =>
      _controller.isRecognizing ? _controller.pauseRecognition() : _controller.start();

  Future<void> _start() async {
    // Fetch the on-device model first (instant on iOS / with the bundled model). Keeps model loading
    // off app startup and lets the UI show download progress before the camera ever opens.
    _sessionStatusNotifier.value = .preparingModel;
    final readiness = await TextSightModel.ensureReady();
    if (readiness is ModelUnavailable) {
      _failure = _describeUnavailable(readiness);
      _sessionStatusNotifier.value = .failed;

      return;
    }

    _sessionStatusNotifier.value = .requesting;
    final permission = await _controller.requestCameraPermission();
    if (permission != .granted) {
      _sessionStatusNotifier.value = permission == .permanentlyDenied
          ? .permanentlyDenied
          : .denied;

      return;
    }

    try {
      await _controller.start();
      _sessionStatusNotifier.value = .ready;
    } on Object catch (error) {
      _failure = error.toString();
      _sessionStatusNotifier.value = .failed;
    }
  }

  // What happens to the session after start() arrives here. A start() that fails is caught above.
  void _onSessionStateChanged() {
    switch (_controller.sessionState) {
      case SessionActive():
        if (_sessionStatusNotifier.value case .paused || .failed) {
          _sessionStatusNotifier.value = .ready;
        }
      case SessionPaused(:final reason):
        _pauseReason = reason;
        _sessionStatusNotifier.value = .paused;
      case SessionFailed(:final details):
        _failure = details ?? 'The camera stopped.';
        _sessionStatusNotifier.value = .failed;
      case SessionIdle():
        break;
    }
  }

  static String _describeUnavailable(ModelUnavailable state) => switch (state.reason) {
    .playServicesUnavailable =>
      'Google Play Services is required to download the recognition model on this device.',
    .downloadFailed =>
      'The recognition model could not be downloaded. Check your connection and retry.',
  };

  @override
  void dispose() {
    _controller.removeListener(_onSessionStateChanged);
    _sessionStatusNotifier.dispose();
    _shouldEnableTorchNotifier.dispose();
    _controller.dispose();

    super.dispose();
  }
}
