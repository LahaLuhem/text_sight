package com.lahaluhem.text_sight.results

import com.lahaluhem.text_sight.region.FrameRegion

// The same shape iOS sends, since one Dart decoder reads both.
internal fun encodeFrame(lines: List<RecognizedLineData>, region: FrameRegion, quarterTurns: Int): Map<String, Any?> {
    val width = region.uprightWidth.toDouble()
    val height = region.uprightHeight.toDouble()

    return mapOf(
        "imageWidth" to width,
        "imageHeight" to height,
        "quarterTurns" to quarterTurns,
        "lines" to lines.map { line ->
            mapOf(
                "text" to line.text,
                "confidence" to line.confidence.toDouble(),
                "left" to line.box.left / width,
                "top" to line.box.top / height,
                "width" to line.box.width() / width,
                "height" to line.box.height() / height,
                // Held for word boxes in a later release.
                "elements" to null,
            )
        },
    )
}
