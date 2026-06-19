import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pmvvm/pmvvm.dart';
import 'package:text_sight/text_sight.dart';

import 'data/enums/session_status.dart';

/// Owns the live [TextSightController], the camera-permission flow, and the latest
/// capture. The view binds the controller to a `TextSightView` and reads the rest as
/// listenables.
final class LiveScannerViewModel extends ViewModel {
  final _controller = TextSightController();

  final _sessionStatusNotifier = ValueNotifier(SessionStatus.requesting);
  final _captureNotifier = ValueNotifier<TextSightCapture?>(null);
  final _shouldEnableTorchNotifier = ValueNotifier(false);
  StreamSubscription<TextSightCapture>? _captureSubscription;
  String? _failure;

  @override
  void init() {
    _captureSubscription = _controller.captures.listen(
      (capture) => _captureNotifier.value = capture,
    );
    unawaited(_start());
  }

  /// The session controller — bound directly to the view's `TextSightView`.
  TextSightController get controller => _controller;

  ValueListenable<SessionStatus> get sessionStatusListenable => _sessionStatusNotifier;

  ValueListenable<TextSightCapture?> get captureListenable => _captureNotifier;

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

  @override
  void dispose() {
    unawaited(_captureSubscription?.cancel());
    _sessionStatusNotifier.dispose();
    _captureNotifier.dispose();
    _shouldEnableTorchNotifier.dispose();
    _controller.dispose();

    super.dispose();
  }
}
