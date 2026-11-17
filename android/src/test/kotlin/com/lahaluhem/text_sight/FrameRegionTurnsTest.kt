package com.lahaluhem.text_sight

import android.graphics.Rect
import com.lahaluhem.text_sight.recognition.FrameRegion
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
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
    private val roi = RegionOfInterestMessage(left = 0.1, top = 0.3, width = 0.5, height = 0.2)

    @Test
    fun `the crop turned upright is the box plus half its height above and below`() {
        val crop = checkNotNull(FrameRegion(storedWidth, storedHeight, rotationDegrees, roi).crop)
        val isQuarterTurned = rotationDegrees % 180 != 0
        val uprightWidth = if (isQuarterTurned) storedHeight else storedWidth
        val uprightHeight = if (isQuarterTurned) storedWidth else storedHeight
        val guard = roi.height / 2
        val read = Rect(
            (roi.left * uprightWidth).roundToInt(),
            ((roi.top - guard) * uprightHeight).roundToInt(),
            ((roi.left + roi.width) * uprightWidth).roundToInt(),
            ((roi.top + roi.height + guard) * uprightHeight).roundToInt(),
        )

        assertEquals(read, crop.turned(rotationDegrees, storedWidth, storedHeight))
    }

    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "stored turned {0} degrees")
        fun rotations(): Collection<Array<Any>> = listOf(0, 90, 180, 270).map { arrayOf<Any>(it) }
    }
}
