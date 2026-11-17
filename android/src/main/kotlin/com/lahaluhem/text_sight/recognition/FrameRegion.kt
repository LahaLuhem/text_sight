package com.lahaluhem.text_sight.recognition

import android.graphics.Rect
import com.lahaluhem.text_sight.RegionOfInterestMessage
import kotlin.math.roundToInt

/** The part of a frame ML Kit reads, the way back from the boxes it reports, and which lines count. */
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
    private val box: Rect? = roi
        ?.let { pixelRect(it.left, it.top, it.left + it.width, it.top + it.height) }
        ?.takeUnless(::isWholeFrame)

    // The box plus half its height above and below, so a line up to the box's height that its edge
    // crosses isn't cut into fragments. Null when that's the whole frame, which needs no copy.
    private val read: Rect? = roi?.takeIf { box != null }
        ?.let {
            val guard = it.height / 2
            pixelRect(it.left, it.top - guard, it.left + it.width, it.top + it.height + guard)
        }
        ?.takeUnless(::isWholeFrame)

    /** What to cut out of the frame as it's stored, or null to read all of it. */
    val crop: Rect? = read?.turnedBack()

    /** A box ML Kit measured from the crop's corner, moved onto the whole frame. */
    fun toFrame(reported: Rect): Rect = Rect(reported).apply { offset(read?.left ?: 0, read?.top ?: 0) }

    /** Whether a line, measured on the whole frame, has its centre in the box. */
    fun keeps(line: Rect): Boolean = box?.contains(line.centerX(), line.centerY()) ?: true

    private fun isWholeFrame(rect: Rect) = rect.width() == uprightWidth && rect.height() == uprightHeight

    // Inside the frame and never empty, since ML Kit throws on an empty image.
    private fun pixelRect(left: Double, top: Double, right: Double, bottom: Double): Rect {
        val pixelLeft = (left * uprightWidth).roundToInt().coerceIn(0, uprightWidth - 1)
        val pixelTop = (top * uprightHeight).roundToInt().coerceIn(0, uprightHeight - 1)
        val pixelRight = (right * uprightWidth).roundToInt().coerceIn(pixelLeft + 1, uprightWidth)
        val pixelBottom = (bottom * uprightHeight).roundToInt().coerceIn(pixelTop + 1, uprightHeight)

        // Out to even pixels, since camera frames keep one colour sample per 2x2 block.
        return Rect(
            pixelLeft / 2 * 2,
            pixelTop / 2 * 2,
            ((pixelRight + 1) / 2 * 2).coerceAtMost(uprightWidth),
            ((pixelBottom + 1) / 2 * 2).coerceAtMost(uprightHeight),
        )
    }

    // ML Kit turns the crop upright itself, so cut it turned back the other way.
    private fun Rect.turnedBack(): Rect = when (rotationDegrees) {
        90 -> Rect(top, uprightWidth - right, bottom, uprightWidth - left)
        180 -> Rect(uprightWidth - right, uprightHeight - bottom, uprightWidth - left, uprightHeight - top)
        270 -> Rect(uprightHeight - bottom, left, uprightHeight - top, right)
        else -> Rect(this)
    }
}
