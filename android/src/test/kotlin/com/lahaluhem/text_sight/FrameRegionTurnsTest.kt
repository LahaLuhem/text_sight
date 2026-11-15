package com.lahaluhem.text_sight

import android.graphics.Rect
import com.lahaluhem.text_sight.recognition.FrameRegion
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config

/** Frames come stored turned, and ML Kit turns what it reads upright. */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class FrameRegionTurnsTest(private val rotationDegrees: Int) {
    // Not square, and the box off-centre, so a swapped side or a wrong turn can't pass.
    private val storedWidth = 400
    private val storedHeight = 300
    private val roi = RegionOfInterestMessage(left = 0.1, top = 0.2, width = 0.5, height = 0.3)
    private val region = FrameRegion(storedWidth, storedHeight, rotationDegrees, roi)
    private val crop = checkNotNull(region.crop)

    @Test
    fun `the crop turned upright is the box`() {
        val isQuarterTurned = rotationDegrees % 180 != 0
        val uprightWidth = if (isQuarterTurned) storedHeight else storedWidth
        val uprightHeight = if (isQuarterTurned) storedWidth else storedHeight
        val box = Rect(
            (roi.left * uprightWidth).roundToInt(),
            (roi.top * uprightHeight).roundToInt(),
            ((roi.left + roi.width) * uprightWidth).roundToInt(),
            ((roi.top + roi.height) * uprightHeight).roundToInt(),
        )

        assertEquals(box, crop.turned(rotationDegrees, storedWidth, storedHeight))
    }

    @Test
    fun `what ML Kit reports lands where the text sits in the frame`() {
        // Some text inside the crop, in the frame as stored.
        val text = Rect(crop.left + 5, crop.top + 10, crop.left + 25, crop.top + 18)
        // ML Kit measures it from the crop's corner, after turning the crop upright.
        val reported = Rect(text)
            .apply { offset(-crop.left, -crop.top) }
            .turned(rotationDegrees, crop.width(), crop.height())

        assertEquals(text.turned(rotationDegrees, storedWidth, storedHeight), region.toFrame(reported))
    }

    @Test
    fun `the crop starts and ends on even pixels and still covers the box`() {
        // Edges that land on odd pixels, in both upright sizes.
        val oddRoi = RegionOfInterestMessage(left = 0.1025, top = 0.21, width = 0.5, height = 0.3)
        val oddRegion = FrameRegion(storedWidth, storedHeight, rotationDegrees, oddRoi)
        val oddCrop = checkNotNull(oddRegion.crop)
        val box = Rect(
            (oddRoi.left * oddRegion.uprightWidth).roundToInt(),
            (oddRoi.top * oddRegion.uprightHeight).roundToInt(),
            ((oddRoi.left + oddRoi.width) * oddRegion.uprightWidth).roundToInt(),
            ((oddRoi.top + oddRoi.height) * oddRegion.uprightHeight).roundToInt(),
        )

        assertTrue("$oddCrop", listOf(oddCrop.left, oddCrop.top, oddCrop.right, oddCrop.bottom).all { it % 2 == 0 })
        assertTrue(oddCrop.turned(rotationDegrees, storedWidth, storedHeight).contains(box))
    }

    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "stored turned {0} degrees")
        fun rotations(): Collection<Array<Any>> = listOf(0, 90, 180, 270).map { arrayOf<Any>(it) }
    }
}

/** This rect in a [width] by [height] image, once the image is turned [degrees] clockwise. */
private fun Rect.turned(degrees: Int, width: Int, height: Int): Rect = when (degrees) {
    90 -> Rect(height - bottom, left, height - top, right)
    180 -> Rect(width - right, height - bottom, width - left, height - top)
    270 -> Rect(top, width - right, bottom, width - left)
    else -> Rect(this)
}
