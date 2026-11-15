package com.lahaluhem.text_sight.recognition

import com.google.mlkit.vision.text.Text
import com.lahaluhem.text_sight.RegionOfInterestMessage

/**
 * Encodes [visionText] into the self-describing per-frame map that the capture channel emits, the
 * same shape the iOS side produces. [roi] (when set) centre-filters lines on the live path.
 */
internal fun encodeFrame(
    visionText: Text,
    region: FrameRegion,
    quarterTurns: Int,
    roi: RegionOfInterestMessage? = null,
): Map<String, Any?> {
    val width = region.uprightWidth.toDouble()
    val height = region.uprightHeight.toDouble()

    val lines = visionText.textBlocks
        .flatMap { block -> block.lines }
        .mapNotNull { line ->
            val box = line.boundingBox?.let(region::toFrame) ?: return@mapNotNull null
            if (!box.centerWithin(roi, width, height)) {
                return@mapNotNull null
            }

            mapOf(
                "text" to line.text,
                "confidence" to line.confidence.toDouble(),
                "left" to box.left / width,
                "top" to box.top / height,
                "width" to box.width() / width,
                "height" to box.height() / height,
                // Word-level elements are reserved for a future additive release.
                "elements" to null,
            )
        }

    return mapOf(
        "imageWidth" to width,
        "imageHeight" to height,
        "quarterTurns" to quarterTurns,
        "lines" to lines,
    )
}
