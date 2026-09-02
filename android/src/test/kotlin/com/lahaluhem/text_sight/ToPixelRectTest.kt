package com.lahaluhem.text_sight

import android.graphics.Rect
import com.lahaluhem.text_sight.recognition.toPixelRect
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * `toPixelRect`: a normalized [0, 1] top-left roi onto a clamped pixel [Rect] that is never empty.
 * Robolectric supplies the real [Rect]. No camera or recognizer is involved, only the arithmetic.
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class ToPixelRectTest(
    // The runner reads this positionally for the row's display name, so no test body touches it.
    @Suppress("UnusedPrivateProperty") case: String,
    private val roi: RegionOfInterestMessage,
    private val imageWidth: Int,
    private val imageHeight: Int,
    private val expected: Rect,
) {
    @Test
    fun `maps the normalized roi onto pixels`() {
        val rect = roi.toPixelRect(imageWidth, imageHeight)

        assertEquals(expected, rect)
        // Asserted on every row, not just the clamping ones: ML Kit throws on an empty crop.
        assertTrue(rect.width() >= 1 && rect.height() >= 1)
    }

    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun cases(): Collection<Array<Any>> = listOf(
            arrayOf(
                "a centered roi lands on the matching pixel rect",
                RegionOfInterestMessage(left = 0.25, top = 0.25, width = 0.5, height = 0.5),
                1000, 500, Rect(250, 125, 750, 375),
            ),
            arrayOf(
                "a whole-frame roi covers every pixel",
                RegionOfInterestMessage(left = 0.0, top = 0.0, width = 1.0, height = 1.0),
                1920, 1080, Rect(0, 0, 1920, 1080),
            ),
            arrayOf(
                "an overflowing roi clamps to the image edge",
                RegionOfInterestMessage(left = 0.8, top = 0.8, width = 0.5, height = 0.5),
                1000, 1000, Rect(800, 800, 1000, 1000),
            ),
            arrayOf(
                // left/top coerced one pixel inside the far edge, right/bottom one past them.
                "a degenerate roi still yields one pixel",
                RegionOfInterestMessage(left = 1.0, top = 1.0, width = 0.0, height = 0.0),
                640, 480, Rect(639, 479, 640, 480),
            ),
        )
    }
}
