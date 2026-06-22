import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pmvvm/pmvvm.dart';
import 'package:text_sight/text_sight.dart';

import 'data/enums/session_status.dart';

final class LiveScannerViewModel extends ViewModel {
  final _controller = TextSightController();

  final _sessionStatusNotifier = ValueNotifier(SessionStatus.preparingModel);
  final _shouldEnableTorchNotifier = ValueNotifier(false);
  String? _failure;

  @override
  void init() {
    unawaited(_start());
  }

  /// The session controller — bound to the view's `TextSightView`, and the source of its
  /// `captures` stream.
  TextSightController get controller => _controller;

  ValueListenable<SessionStatus> get sessionStatusListenable => _sessionStatusNotifier;

  ValueListenable<bool> get shouldEnableTorchListenable => _shouldEnableTorchNotifier;

  /// The failure message — meaningful only while the status is [SessionStatus.failed].
  String get failure => _failure ?? 'Could not start the camera.';

  Future<void> onRetryPressed() => _start();

  Future<void> onTorchToggled() async {
    final next = !_shouldEnableTorchNotifier.value;
    await _controller.updateTorchEnabled(enabled: next);
    _shouldEnableTorchNotifier.value = next;
  }

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
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _sessionStatusNotifier.value = .denied;

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

  static String _describeUnavailable(ModelUnavailable state) => switch (state.reason) {
    .playServicesUnavailable =>
      'Google Play Services is required to download the recognition model on this device.',
    .downloadFailed =>
      'The recognition model could not be downloaded. Check your connection and retry.',
  };

  @override
  void dispose() {
    _sessionStatusNotifier.dispose();
    _shouldEnableTorchNotifier.dispose();
    _controller.dispose();

    super.dispose();
  }
}
