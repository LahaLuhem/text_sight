import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Mirrors `harness/payloads.dart` including seeds, so a `document` here matches one there.
// Benchmark
//ignore: prefer-match-file-name
enum PageProfile {
  /// A street sign or label: a few short lines.
  sign(minLines: 1, maxLines: 3, minTextLen: 3, maxTextLen: 14),

  /// A receipt: many short lines.
  receipt(minLines: 18, maxLines: 30, minTextLen: 4, maxTextLen: 28),

  /// A page of prose: long lines.
  document(minLines: 45, maxLines: 70, minTextLen: 20, maxTextLen: 60),

  /// Worst case: a very dense page.
  dense(minLines: 100, maxLines: 140, minTextLen: 8, maxTextLen: 40);

  new({
    required this.minLines,
    required this.maxLines,
    required this.minTextLen,
    required this.maxTextLen,
  });

  final int minLines;
  final int maxLines;
  final int minTextLen;
  final int maxTextLen;
}

/// A rendered page plus the shape it came from.
typedef RenderedPage = ({
  Uint8List pngBytes,
  int lineCount,
  int width,
  int height,
  double fontSize,
  int inkPixels,
});

/// Renders [profile] as black text on a fixed-size white page, so decode cost is constant and
/// latency differences come from density alone. Type shrinks to fit, capped so a sign stays sane.
Future<RenderedPage> renderPage(PageProfile profile) async {
  final random = Random(profile.index + _profileSeedBase);
  final lineCount = profile.minLines + random.nextInt(profile.maxLines - profile.minLines + 1);
  final lines = List.generate(lineCount, (_) => _line(random, profile));

  const textBoxHeight = _pageHeight - _margin * 2;
  final fontSize = min(_maxFontSize, textBoxHeight / (lineCount * _lineHeight));
  final painter = TextPainter(
    text: TextSpan(
      text: lines.join('\n'),
      style: TextStyle(color: const Color(0xFF000000), fontSize: fontSize, height: _lineHeight),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: _pageWidth - _margin * 2);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, _pageWidth, _pageHeight),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  painter.paint(canvas, const Offset(_margin, _margin));

  final image = await recorder.endRecording().toImage(_pageWidth.round(), _pageHeight.round());
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final raw = await image.toByteData();

    return (
      pngBytes: png!.buffer.asUint8List(),
      lineCount: lineCount,
      width: _pageWidth.round(),
      height: _pageHeight.round(),
      fontSize: fontSize,
      inkPixels: _countInk(raw!),
    );
  } finally {
    image.dispose();
  }
}

/// Non-white pixels: separates a blank render from a recognizer that read nothing.
int _countInk(ByteData raw) {
  var ink = 0;
  for (var offset = 0; offset + 3 < raw.lengthInBytes; offset += 4) {
    if (raw.getUint8(offset) < 200) ink++;
  }

  return ink;
}

/// Real words, so `accurate`'s language correction has something sensible to chew on.
String _line(Random random, PageProfile profile) {
  final target = profile.minTextLen + random.nextInt(profile.maxTextLen - profile.minTextLen + 1);
  final words = <String>[];
  var length = 0;
  while (length < target) {
    final word = _lexicon[random.nextInt(_lexicon.length)];
    words.add(word);
    length += word.length + 1;
  }

  return words.join(' ');
}

/// Matches `payloads.dart`, so line counts line up across the two suites.
const _profileSeedBase = 0x51760000;

/// Big enough that `dense`'s type stays legible.
const _pageWidth = 2000.0;
const _pageHeight = 2800.0;
const _margin = 48.0;
const _maxFontSize = 56.0;
const _lineHeight = 1.35;

const _lexicon = [
  'total',
  'invoice',
  'quantity',
  'price',
  'summary',
  'delivery',
  'address',
  'reference',
  'account',
  'balance',
  'payment',
  'received',
  'thank',
  'you',
  'order',
  'number',
  'date',
  'station',
  'platform',
  'departure',
  'arrival',
  'gate',
  'terminal',
  'notice',
  'warning',
];
