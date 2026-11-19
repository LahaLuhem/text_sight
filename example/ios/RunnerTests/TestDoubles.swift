import AVFoundation
import CoreGraphics
import CoreVideo
import Flutter
import ImageIO
import UIKit
import XCTest

@testable import text_sight

/// A blank BGRA buffer, all `handle` needs to stand in for a captured frame.
func makeTestPixelBuffer() throws -> CVPixelBuffer {
  var pixelBuffer: CVPixelBuffer?
  let code = CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA, nil,
                                 &pixelBuffer)
  XCTAssertEqual(code, kCVReturnSuccess)

  return try XCTUnwrap(pixelBuffer)
}

/// Renders `string` as large black text on a white field, clear enough for reliable recognition.
func renderText(_ string: String) -> UIImage {
  let size = CGSize(width: 512, height: 160)

  return UIGraphicsImageRenderer(size: size).image { context in
    UIColor.white.setFill()
    context.fill(CGRect(origin: .zero, size: size))
    (string as NSString).draw(at: CGPoint(x: 24, y: 36), withAttributes: [
      .font: UIFont.boldSystemFont(ofSize: 84),
      .foregroundColor: UIColor.black,
    ])
  }
}

/// Counts open capture configurations. AVFoundation reference-counts begin/commit and exposes no
/// way to read the depth, so mirror it here.
final class CountingCaptureSession: AVCaptureSession {
  private(set) var openConfigurations = 0

  override func beginConfiguration() {
    openConfigurations += 1
    super.beginConfiguration()
  }

  override func commitConfiguration() {
    openConfigurations -= 1
    super.commitConfiguration()
  }
}

/// Satisfies `TextSightCamera`'s texture dependency for the paths that never register a texture.
final class StubTextureRegistry: NSObject, FlutterTextureRegistry {
  func register(_ texture: FlutterTexture) -> Int64 { 1 }

  func textureFrameAvailable(_ textureId: Int64) {}

  func unregisterTexture(_ textureId: Int64) {}
}

/// Never finishes on its own: it parks until its task is cancelled. Lets a test hold a recognition
/// in flight and watch what teardown does to it.
final class ParkedRecognizer: TextRecognizer, @unchecked Sendable {
  let confidenceScale = ConfidenceScaleMessage.visionGraded

  let started = XCTestExpectation(description: "a frame reached the recognizer")
  let cancelled = XCTestExpectation(description: "the parked recognition was cancelled")

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    started.fulfill()

    do {
      // Long enough that only cancellation ends the wait.
      try await Task.sleep(nanoseconds: 30 * NSEC_PER_SEC)
    } catch {
      cancelled.fulfill()
      throw error
    }

    return []
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    XCTFail("the live path must not take the still-image entry point")

    return []
  }
}

/// Returns a line even once cancelled, as the legacy backend's Vision call does after it starts.
final class FinishesAnywayRecognizer: TextRecognizer, @unchecked Sendable {
  let confidenceScale = ConfidenceScaleMessage.visionGraded

  let started = XCTestExpectation(description: "a frame reached the recognizer")

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    started.fulfill()
    // Only cancellation ends the wait, and the line still comes back.
    try? await Task.sleep(nanoseconds: 30 * NSEC_PER_SEC)

    return [RecognizedLineData(text: "late", confidence: 1,
                               box: CGRect(x: 0, y: 0, width: 1, height: 1))]
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    XCTFail("the live path must not take the still-image entry point")

    return []
  }
}

/// Holds each recognition until the test releases it, and hands over the frame it got. A held one
/// ignores cancellation, so release it before teardown.
final class HeldRecognizer: TextRecognizer, @unchecked Sendable {
  let confidenceScale = ConfidenceScaleMessage.visionGraded

  /// Every frame that reached the recognizer, in order.
  let frames: AsyncStream<CVPixelBuffer>
  private let framesSink: AsyncStream<CVPixelBuffer>.Continuation
  private let lock = NSLock()
  private var held: CheckedContinuation<Void, Never>?

  init() {
    (frames, framesSink) = AsyncStream.makeStream()
  }

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    await withCheckedContinuation { continuation in
      lock.withLock { held = continuation }
      framesSink.yield(pixelBuffer)
    }

    return []
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    XCTFail("the live path must not take the still-image entry point")

    return []
  }

  /// Lets the recognition in progress finish.
  func release() {
    let continuation = lock.withLock {
      defer { held = nil }

      return held
    }
    continuation?.resume()
  }
}

/// Takes a fixed time and stamps every finish, so a test can read the gap between them. A cancelled
/// recognition leaves no stamp.
final class TimedRecognizer: TextRecognizer, @unchecked Sendable {
  let confidenceScale = ConfidenceScaleMessage.visionGraded

  private let latencyNanos: UInt64
  private let lock = NSLock()
  private var finishNanos: [UInt64] = []

  init(latencyMs: Double) {
    latencyNanos = UInt64(latencyMs * 1_000_000)
  }

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    try await Task.sleep(nanoseconds: latencyNanos)
    lock.withLock { finishNanos.append(DispatchTime.now().uptimeNanoseconds) }

    return []
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    XCTFail("the live path must not take the still-image entry point")

    return []
  }

  /// (recognitions finished, mean milliseconds between consecutive finishes).
  func stats() -> (Int, Double) {
    lock.withLock {
      guard finishNanos.count > 1 else { return (finishNanos.count, 0) }
      let span = Double(finishNanos[finishNanos.count - 1] - finishNanos[0]) / 1_000_000

      return (finishNanos.count, span / Double(finishNanos.count - 1))
    }
  }
}

/// Hands back each frame's lines in turn, repeating the last, so a test scripts what Vision sees.
final class ScriptedRecognizer: TextRecognizer, @unchecked Sendable {
  let confidenceScale = ConfidenceScaleMessage.visionGraded

  private let frames: [[RecognizedLineData]]
  private let lock = NSLock()
  private var next = 0

  init(frames: [[RecognizedLineData]]) {
    self.frames = frames
  }

  func recognize(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    nextLines()
  }

  func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation,
                 config: RecognitionConfig) async throws -> [RecognizedLineData] {
    nextLines()
  }

  private func nextLines() -> [RecognizedLineData] {
    lock.withLock {
      defer { next += 1 }

      return frames[min(next, frames.count - 1)]
    }
  }
}

/// Fails unless `work` throws a `PigeonError` with `code`.
func assertThrowsPigeonError(
  code: String, file: StaticString = #filePath, line: UInt = #line,
  _ work: @escaping () async throws -> Void
) async {
  do {
    try await work()
    XCTFail("expected a PigeonError(\(code)), got success", file: file, line: line)
  } catch let error as PigeonError {
    XCTAssertEqual(error.code, code, file: file, line: line)
  } catch {
    XCTFail("expected a PigeonError(\(code)), got \(error)", file: file, line: line)
  }
}
