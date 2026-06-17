import 'dart:async';

import 'package:flutter/material.dart';
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

  _SessionStatus _status = _SessionStatus.requesting;
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
      _status = _SessionStatus.requesting;
      _failure = null;
    });

    final permission = await Permission.camera.request();
    if (!mounted) return;

    if (!permission.isGranted) {
      return setState(() => _status = _SessionStatus.denied);
    }

    try {
      await _controller.start();
      if (!mounted) return;
      setState(() => _status = _SessionStatus.ready);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _SessionStatus.failed;
        _failure = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('TextSight'),
      actions: [
        if (_status == _SessionStatus.ready)
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
      _SessionStatus.requesting => const Center(child: CircularProgressIndicator()),
      _SessionStatus.denied => const _MessageView(
        icon: Icons.no_photography_outlined,
        message: 'Camera permission is required to recognize text.',
        actionLabel: 'Open settings',
        onAction: openAppSettings,
      ),
      _SessionStatus.failed => _MessageView(
        icon: Icons.error_outline,
        message: _failure ?? 'Could not start the camera.',
        actionLabel: 'Retry',
        onAction: _start,
      ),
      _SessionStatus.ready => _ScannerView(controller: _controller, capture: _capture),
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
    fit: StackFit.expand,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Icon(icon, size: 48),
          Text(message, textAlign: TextAlign.center),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
