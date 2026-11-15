package com.lahaluhem.text_sight.recognition

import android.graphics.Rect
import com.lahaluhem.text_sight.RegionOfInterestMessage
import kotlin.math.roundToInt

/** The part of a frame ML Kit reads, and the way back from the boxes it reports. */
internal class FrameRegion(
    storedWidth: Int,
    storedHeight: Int,
    private val rotationDegrees: Int,
    roi: RegionOfInterestMessage? = null,
) {
    private val isQuarterTurned = rotationDegrees == 90 || rotationDegrees == 270

    // The roi and every box ML Kit reports are measured in the frame turned upright.
    val uprightWidth = if (isQuarterTurned) storedHeight else storedWidth
    val uprightHeight = if (isQuarterTurned) storedWidth else storedHeight

    // A box over the whole frame reads the same as no box, without the copy.
    private val box: Rect? = roi?.let { pixelBox(it) }
        ?.takeUnless { it.width() == uprightWidth && it.height() == uprightHeight }

    /** What to cut out of the frame as it's stored, or null to read all of it. */
    val crop: Rect? = box?.turnedBack()

    /** A box ML Kit measured from the crop's corner, moved onto the whole frame. */
    fun toFrame(reported: Rect): Rect = Rect(reported).apply { offset(box?.left ?: 0, box?.top ?: 0) }

    // Inside the frame and never empty, since ML Kit throws on an empty image.
    private fun pixelBox(roi: RegionOfInterestMessage): Rect {
        val left = (roi.left * uprightWidth).roundToInt().coerceIn(0, uprightWidth - 1)
        val top = (roi.top * uprightHeight).roundToInt().coerceIn(0, uprightHeight - 1)
        val right = ((roi.left + roi.width) * uprightWidth).roundToInt().coerceIn(left + 1, uprightWidth)
        val bottom = ((roi.top + roi.height) * uprightHeight).roundToInt().coerceIn(top + 1, uprightHeight)

        // Out to even pixels, since camera frames keep one colour sample per 2x2 block.
        return Rect(
            left / 2 * 2,
            top / 2 * 2,
            ((right + 1) / 2 * 2).coerceAtMost(uprightWidth),
            ((bottom + 1) / 2 * 2).coerceAtMost(uprightHeight),
        )
    }

    // ML Kit turns the crop upright itself, so cut the box turned back the other way.
    private fun Rect.turnedBack(): Rect = when (rotationDegrees) {
        90 -> Rect(top, uprightWidth - right, bottom, uprightWidth - left)
        180 -> Rect(uprightWidth - right, uprightHeight - bottom, uprightWidth - left, uprightHeight - top)
        270 -> Rect(uprightHeight - bottom, left, uprightHeight - top, right)
        else -> Rect(this)
    }
}
