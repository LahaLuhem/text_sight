import Foundation

enum FrameEncoding {
  /// The per-frame map Dart decodes. Android's `FrameEncoding` sends the same keys.
  static func encodeFrame(_ lines: [RecognizedLineData],
                          imageWidth: Double, imageHeight: Double,
                          quarterTurns: Int) -> [String: Any] {
    let encodedLines = lines.map { line -> [String: Any] in
      [
        "text": line.text,
        "confidence": line.confidence,
        "left": Double(line.box.minX),
        "top": Double(line.box.minY),
        "width": Double(line.box.width),
        "height": Double(line.box.height),
        // Words aren't filled in yet.
        "elements": NSNull(),
      ]
    }

    return [
      "imageWidth": imageWidth,
      "imageHeight": imageHeight,
      "quarterTurns": quarterTurns,
      "lines": encodedLines,
    ]
  }
}
