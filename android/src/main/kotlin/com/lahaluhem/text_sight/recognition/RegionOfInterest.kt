package com.lahaluhem.text_sight.recognition

import android.graphics.Rect
import androidx.annotation.VisibleForTesting
import com.lahaluhem.text_sight.RegionOfInterestMessage
import kotlin.math.roundToInt

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

/** `roi` (normalized [0, 1] top-left) as a pixel [Rect] clamped inside the image, never empty. */
@VisibleForTesting
internal fun RegionOfInterestMessage.toPixelRect(imageWidth: Int, imageHeight: Int): Rect {
    val pixelLeft = (left * imageWidth).roundToInt().coerceIn(0, imageWidth - 1)
    val pixelTop = (top * imageHeight).roundToInt().coerceIn(0, imageHeight - 1)
    val pixelRight = ((left + width) * imageWidth).roundToInt().coerceIn(pixelLeft + 1, imageWidth)
    val pixelBottom = ((top + height) * imageHeight).roundToInt().coerceIn(pixelTop + 1, imageHeight)

    return Rect(pixelLeft, pixelTop, pixelRight, pixelBottom)
}
