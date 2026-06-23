import Foundation

/// One recognized line of text, platform-neutral: the string, a confidence in `[0, 1]`, and a
/// top-left-normalized bounding box. Each Vision backend maps its own observation type to this, so
/// `TextSightCamera.encodeFrame` and the per-frame wire `Map` never touch a Vision type — the
/// backend divergence is contained behind the `TextRecognizer` seam.
struct RecognizedLineData {
  let text: String
  /// `[0, 1]`. Vision always supplies a per-candidate confidence, so this is never synthesized.
  let confidence: Double
  /// Top-left-normalized `[0, 1]` — `minX` / `minY` are the box's left / top.
  let box: CGRect
}
