package com.lahaluhem.text_sight.recognition

import android.graphics.Rect
import androidx.annotation.VisibleForTesting
import com.lahaluhem.text_sight.RegionOfInterestMessage

/** Whether the centre of this pixel rect falls inside [roi] (normalized [0, 1] top-left). */
@VisibleForTesting
internal fun Rect.centerWithin(
    roi: RegionOfInterestMessage?,
    imageWidth: Double,
    imageHeight: Double,
): Boolean {
    if (roi == null) return true

    val centerX = exactCenterX() / imageWidth
    val centerY = exactCenterY() / imageHeight

    return centerX >= roi.left &&
        centerX <= roi.left + roi.width &&
        centerY >= roi.top &&
        centerY <= roi.top + roi.height
}
