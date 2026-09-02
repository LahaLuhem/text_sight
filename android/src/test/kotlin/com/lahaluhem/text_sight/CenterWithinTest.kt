package com.lahaluhem.text_sight

import android.graphics.Rect
import com.lahaluhem.text_sight.recognition.centerWithin
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * `centerWithin`: does a recognized box's centre fall inside the normalized roi? This is the live
 * path's containment filter, so it decides which lines survive into a frame.
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class CenterWithinTest(
    // The runner reads this positionally for the row's display name, so no test body touches it.
    @Suppress("UnusedPrivateProperty") case: String,
    private val box: Rect,
    private val roi: RegionOfInterestMessage?,
    private val expected: Boolean,
) {
    @Test
    fun `keeps only boxes centred inside the roi`() {
        assertEquals(expected, box.centerWithin(roi, imageWidth = 1000.0, imageHeight = 1000.0))
    }

    companion object {
        private val quarterToThreeQuarters =
            RegionOfInterestMessage(left = 0.25, top = 0.25, width = 0.5, height = 0.5)

        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun cases(): Collection<Array<Any?>> = listOf(
            arrayOf("no roi keeps everything", Rect(0, 0, 10, 10), null, true),
            // Centre (0.5, 0.5) sits inside the [0.25, 0.75] box.
            arrayOf(
                "a box centred inside the roi is kept",
                Rect(400, 400, 600, 600), quarterToThreeQuarters, true,
            ),
            // Centre (0.9, 0.9) sits outside it.
            arrayOf(
                "a box centred outside the roi is dropped",
                Rect(880, 880, 920, 920), quarterToThreeQuarters, false,
            ),
            // Centre (0.5, 0.5) is exactly the roi's right/bottom edge, and bounds are inclusive.
            arrayOf(
                "a box centred exactly on the edge is kept",
                Rect(400, 400, 600, 600),
                RegionOfInterestMessage(left = 0.0, top = 0.0, width = 0.5, height = 0.5), true,
            ),
        )
    }
}
