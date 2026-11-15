package com.lahaluhem.text_sight.recognition

import com.google.mlkit.vision.text.Text

/** The per-frame map the captures channel sends, in the same shape iOS sends. */
internal fun encodeFrame(visionText: Text, region: FrameRegion, quarterTurns: Int): Map<String, Any?> {
    val width = region.uprightWidth.toDouble()
    val height = region.uprightHeight.toDouble()

    val lines = visionText.textBlocks
        .flatMap { block -> block.lines }
        .mapNotNull { line ->
            val box = line.boundingBox?.let(region::toFrame) ?: return@mapNotNull null

            mapOf(
                "text" to line.text,
                "confidence" to line.confidence.toDouble(),
                "left" to box.left / width,
                "top" to box.top / height,
                "width" to box.width() / width,
                "height" to box.height() / height,
                // Held for word boxes in a later release.
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
