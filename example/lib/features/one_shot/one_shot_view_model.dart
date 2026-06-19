import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pmvvm/pmvvm.dart';
import 'package:text_sight/text_sight.dart';

import '../core/data/constants/core_constants.dart';

/// The outcome of one recognition: a `capture` on success or an `error` message on
/// failure (mutually exclusive; both null before the first run).
typedef OneShotResult = ({TextSightCapture? capture, String? error});

/// Recognizes a bundled sample image through both static entry points — no camera,
/// session, or permission. The in-flight gate lives on the view's
/// `AsyncIconActionButton`, so there is no busy flag here.
final class OneShotViewModel extends ViewModel {
  final _resultNotifier = ValueNotifier<OneShotResult?>(null);

  ValueListenable<OneShotResult?> get resultListenable => _resultNotifier;

  Future<void> onRecognizeBytesPressed() => _run(() async {
    final bytes = (await rootBundle.load(ConstMedia.sampleText.keyName)).buffer.asUint8List();

    return TextSight.recognizeImage(bytes);
  });

  Future<void> onRecognizePathPressed() => _run(() async {
    final bytes = (await rootBundle.load(ConstMedia.sampleText.keyName)).buffer.asUint8List();
    final file = File('${Directory.systemTemp.path}/text_sight_sample.png');
    await file.writeAsBytes(bytes);

    return TextSight.recognizePath(file.path);
  });

  Future<void> _run(Future<TextSightCapture> Function() recognize) async {
    try {
      _resultNotifier.value = (capture: await recognize(), error: null);
    } on Object catch (error) {
      _resultNotifier.value = (capture: null, error: error.toString());
    }
  }

  @override
  void dispose() {
    _resultNotifier.dispose();

    super.dispose();
  }
}
