import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:text_sight/text_sight.dart';

void main() => runApp(const TextSightExampleApp());

/// Demonstrates live, on-device text recognition with [TextSightView].
class TextSightExampleApp extends StatelessWidget {
  const TextSightExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TextSight',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const ScannerPage(),
  );
}

/// The single demo screen: a live preview with a recognized-text overlay.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

enum _SessionStatus { requesting, denied, ready, failed }

class _ScannerPageState extends State<ScannerPage> {
  final _controller = TextSightController();
  final ValueNotifier<TextSightCapture?> _capture = ValueNotifier(null);

  _SessionStatus _status = .requesting;
  String? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _controller.dispose();
    _capture.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _status = .requesting;
      _failure = null;
    });

    final permission = await Permission.camera.request();
    if (!mounted) return;

    if (!permission.isGranted) {
      return setState(() => _status = .denied);
    }

    try {
      await _controller.start();
      if (!mounted) return;
      setState(() => _status = .ready);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = .failed;
        _failure = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('TextSight'),
      actions: [
        IconButton(
          tooltip: 'One-shot still recognition',
          icon: const Icon(Icons.image_search_outlined),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const _StillRecognitionPage())),
        ),
        if (_status == .ready)
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              tooltip: 'Torch',
              icon: Icon(_controller.isTorchEnabled ? Icons.flash_on : Icons.flash_off),
              onPressed: () => _controller.setTorchEnabled(enabled: !_controller.isTorchEnabled),
            ),
          ),
      ],
    ),
    body: switch (_status) {
      .requesting => const Center(child: CircularProgressIndicator()),
      .denied => const _MessageView(
        icon: Icons.no_photography_outlined,
        message: 'Camera permission is required to recognize text.',
        actionLabel: 'Open settings',
        onAction: openAppSettings,
      ),
      .failed => _MessageView(
        icon: Icons.error_outline,
        message: _failure ?? 'Could not start the camera.',
        actionLabel: 'Retry',
        onAction: _start,
      ),
      .ready => _ScannerView(controller: _controller, capture: _capture),
    },
  );
}

/// The live preview, recognized-line overlay, and a scrolling text panel.
class _ScannerView extends StatelessWidget {
  const _ScannerView({required this.controller, required this.capture});

  final TextSightController controller;
  final ValueNotifier<TextSightCapture?> capture;

  @override
  Widget build(BuildContext context) => Stack(
    fit: .expand,
    children: [
      TextSightView(
        controller: controller,
        onResult: (result) => capture.value = result,
        overlayBuilder: (context, result, constraints) =>
            CustomPaint(size: constraints.biggest, painter: _BoundingBoxPainter(result.lines)),
        placeholderBuilder: (context) => const Center(child: CircularProgressIndicator()),
      ),
      Positioned(left: 0, right: 0, bottom: 0, child: _RecognizedTextPanel(capture: capture)),
    ],
  );
}

/// Paints each recognized line's normalized box scaled to the preview Size.
class _BoundingBoxPainter extends CustomPainter {
  _BoundingBoxPainter(this.lines);

  final List<RecognizedLine> lines;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF00E676);

    for (final line in lines) {
      final box = line.boundingBox;
      canvas.drawRect(
        Rect.fromLTWH(
          box.left * size.width,
          box.top * size.height,
          box.width * size.width,
          box.height * size.height,
        ),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_BoundingBoxPainter oldDelegate) => oldDelegate.lines != lines;
}

/// A bottom panel listing the most recently recognized lines.
class _RecognizedTextPanel extends StatelessWidget {
  const _RecognizedTextPanel({required this.capture});

  final ValueNotifier<TextSightCapture?> capture;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextSightCapture?>(
    valueListenable: capture,
    builder: (context, value, _) {
      final lines = value?.lines ?? const <RecognizedLine>[];

      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 160),
        color: Colors.black54,
        padding: const EdgeInsets.all(12),
        child: lines.isEmpty
            ? const Text('Point the camera at some text…')
            : SingleChildScrollView(
                child: Text(
                  [for (final line in lines) line.text].join('\n'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
      );
    },
  );
}

/// A centered icon + message + action button for permission/error states.
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const .all(24),
      child: Column(
        mainAxisSize: .min,
        spacing: 16,
        children: [
          Icon(icon, size: 48),
          Text(message, textAlign: .center),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}

/// A standalone demo of the static one-shot API — no camera, session, or permission.
///
/// Recognizes a bundled sample image two ways: from in-memory bytes via
/// [TextSight.recognizeImage], and from a file path via [TextSight.recognizePath].
class _StillRecognitionPage extends StatefulWidget {
  const _StillRecognitionPage();

  @override
  State<_StillRecognitionPage> createState() => _StillRecognitionPageState();
}

class _StillRecognitionPageState extends State<_StillRecognitionPage> {
  static const _asset = 'assets/sample_text.png';

  TextSightCapture? _capture;
  String? _error;
  var _busy = false;

  Future<void> _recognize({required bool fromFile}) async {
    setState(() {
      _busy = true;
      _error = null;
      _capture = null;
    });

    try {
      final bytes = (await rootBundle.load(_asset)).buffer.asUint8List();
      final capture = fromFile
          ? await TextSight.recognizePath(await _writeTempCopy(bytes))
          : await TextSight.recognizeImage(bytes);
      if (!mounted) return;
      setState(() => _capture = capture);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Writes [bytes] to a temp file so the path-based entry point can be demonstrated.
  Future<String> _writeTempCopy(Uint8List bytes) async {
    final file = File('${Directory.systemTemp.path}/text_sight_sample.png');
    await file.writeAsBytes(bytes);

    return file.path;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('One-shot recognition')),
    body: Padding(
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 16,
        children: [
          ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const .all(8),
              child: Image.asset(_asset, semanticLabel: 'Sample text', height: 150, fit: .contain),
            ),
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _recognize(fromFile: false),
                  child: const Text('From bytes'),
                ),
              ),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _busy ? null : () => _recognize(fromFile: true),
                  child: const Text('From file'),
                ),
              ),
            ],
          ),
          Expanded(
            child: switch ((_busy, _error, _capture)) {
              (true, _, _) => const Center(child: CircularProgressIndicator()),
              (_, final error?, _) => Center(
                child: Text('Failed: $error', textAlign: TextAlign.center),
              ),
              (_, _, final capture?) => ListView(
                children: [
                  Text(
                    '${capture.lines.length} lines · '
                    '${capture.imageSize.width.toInt()}×${capture.imageSize.height.toInt()} px · '
                    'quarterTurns ${capture.quarterTurns}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Divider(),
                  for (final line in capture.lines)
                    ListTile(
                      dense: true,
                      title: Text(line.text),
                      subtitle: line.confidence == null
                          ? null
                          : Text('confidence ${line.confidence!.toStringAsFixed(2)}'),
                    ),
                ],
              ),
              _ => const Center(child: Text('Tap a button to recognize the sample image.')),
            },
          ),
        ],
      ),
    ),
  );
}
