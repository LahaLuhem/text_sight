package com.lahaluhem.text_sight.recognition

import android.graphics.Rect
import com.google.mlkit.vision.text.Text
import com.lahaluhem.text_sight.region.FrameRegion
import com.lahaluhem.text_sight.results.RecognizedLineData

// Every path gets its lines through here, so none can skip the box's rule.
internal fun Text.linesIn(region: FrameRegion, shown: List<Rect> = emptyList()): List<RecognizedLineData> {
    val lines = textBlocks
        .flatMap { block -> block.lines }
        .mapNotNull { line ->
            line.boundingBox?.let { RecognizedLineData(line.text, line.confidence, region.toFrame(it)) }
        }

    return region.keep(lines, shown)
}
