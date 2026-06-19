import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pmvvm/pmvvm.dart';
import 'package:text_sight/text_sight.dart';

import '/features/core/data/constants/core_constants.dart';
import '/features/core/data/recognition_result.dart';

/// Recognizes a bundled sample image through both static entry points — no camera,
/// session, or permission. The in-flight gate lives on the view's
/// `AsyncIconActionButton`, so there is no busy flag here.
final class OneShotViewModel extends ViewModel {
  final _resultNotifier = ValueNotifier<RecognitionResult?>(null);

  ValueListenable<RecognitionResult?> get resultListenable => _resultNotifier;

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
