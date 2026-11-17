package com.lahaluhem.text_sight.recognition

import android.graphics.Rect
import com.google.mlkit.vision.text.Text
import com.lahaluhem.text_sight.RegionOfInterestMessage

internal class ShownLines {
    private var roi: RegionOfInterestMessage? = null
    private var boxes: List<Rect> = emptyList()

    fun linesIn(visionText: Text, region: FrameRegion, roi: RegionOfInterestMessage?): List<RecognizedLineData> {
        // A changed box starts with nothing shown.
        val lines = visionText.linesIn(region, if (roi == this.roi) boxes else emptyList())
        this.roi = roi
        boxes = lines.map { it.box }

        return lines
    }
}
