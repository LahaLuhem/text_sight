package com.lahaluhem.text_sight.region

import android.graphics.Rect
import com.lahaluhem.text_sight.RegionOfInterestMessage
import com.lahaluhem.text_sight.results.RecognizedLineData
import kotlin.math.roundToInt

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

    // Half the box's height past its top and bottom, since ML Kit turns a line cut along its length
    // into fragments. A read that takes in the whole frame needs no copy.
    private val read: Rect? = roi?.takeIf { box != null }
        ?.let {
            val guard = it.height / 2
            pixelRect(it.left, it.top - guard, it.left + it.width, it.top + it.height + guard)
        }
        ?.takeUnless(::isWholeFrame)

    val crop: Rect? = read?.turnedBack()

    // ML Kit measures from the crop's corner, not the frame's.
    fun toFrame(reported: Rect): Rect = Rect(reported).apply { offset(read?.left ?: 0, read?.top ?: 0) }

    fun keep(lines: List<RecognizedLineData>, shown: List<Rect> = emptyList()): List<RecognizedLineData> {
        val box = this.box ?: return lines

        return lines.filter { line ->
            // The read reaches past the box, so a line counts when its centre is inside.
            if (box.contains(line.box.centerX(), line.box.centerY())) return@filter true

            // One already on screen hangs on a bit past the edge, so a shaky hand doesn't blink it.
            val outside = maxOf(box.top - line.box.centerY(), line.box.centerY() - box.bottom)

            outside <= line.box.height() / 4 && shown.any { isSameLine(it, line.box) }
        }
    }

    // Loose enough that a line the hand nudged between frames still matches.
    private fun isSameLine(one: Rect, other: Rect): Boolean {
        val overlap = Rect(one)

        return overlap.intersect(other) && overlap.height() > minOf(one.height(), other.height()) / 2
    }

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
