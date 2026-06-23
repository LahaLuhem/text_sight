package com.lahaluhem.text_sight.recognition

import android.graphics.Rect
import androidx.annotation.VisibleForTesting
import com.google.mlkit.vision.text.Text
import com.lahaluhem.text_sight.RegionOfInterestMessage

/**
 * Encodes [visionText] into the self-describing per-frame map that the capture channel emits — the same
 * shape the iOS side produces. [roi] (when set) centre-filters lines on the live path; the crop
 * origin [offsetX]/[offsetY] maps still-image boxes back into full-image coordinates.
 */
@VisibleForTesting
internal fun encodeFrame(
    visionText: Text,
    imageWidth: Int,
    imageHeight: Int,
    quarterTurns: Int,
    roi: RegionOfInterestMessage? = null,
    offsetX: Int = 0,
    offsetY: Int = 0,
): Map<String, Any?> {
    val width = imageWidth.toDouble()
    val height = imageHeight.toDouble()

    val lines = visionText.textBlocks
        .flatMap { block -> block.lines }
        .mapNotNull { line ->
            val boundingBox = line.boundingBox ?: return@mapNotNull null
            if (!boundingBox.centerWithin(roi, width, height)) {
                return@mapNotNull null
            }

            encodeLine(line, boundingBox, width, height, offsetX, offsetY)
        }

    return mapOf(
        "imageWidth" to width,
        "imageHeight" to height,
        "quarterTurns" to quarterTurns,
        "lines" to lines,
    )
}

/** Encodes one recognized [line] into its per-frame wire map (box normalized, origin-offset). */
@VisibleForTesting
internal fun encodeLine(
    line: Text.Line,
    boundingBox: Rect,
    imageWidth: Double,
    imageHeight: Double,
    offsetX: Int,
    offsetY: Int,
): Map<String, Any?> =
    mapOf(
        "text" to line.text,
        // ML Kit always supplies a per-line confidence (a primitive float) — never null.
        // Forwarded as a non-null Double the nullable RecognizedLine.confidence contract accepts.
        "confidence" to line.confidence.toDouble(),
        // The crop origin (0 on the live path) maps boxes back into full-image coordinates.
        "left" to (boundingBox.left + offsetX) / imageWidth,
        "top" to (boundingBox.top + offsetY) / imageHeight,
        "width" to boundingBox.width() / imageWidth,
        "height" to boundingBox.height() / imageHeight,
        // Word-level elements are reserved for a future additive release.
        "elements" to null,
    )
