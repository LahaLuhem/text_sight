package com.lahaluhem.text_sight

import android.graphics.Rect
import com.lahaluhem.text_sight.recognition.FrameRegion
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** What gets read when there's no box to cut out, or the box doesn't fit the frame. */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class FrameRegionTest {
    @Test
    fun `no box reads the whole frame and keeps boxes as reported`() {
        val region = FrameRegion(640, 480, 90)
        val reported = Rect(10, 20, 30, 40)

        assertNull(region.crop)
        assertEquals(reported, region.toFrame(reported))
    }

    @Test
    fun `a box over the whole frame reads it as it is`() {
        val roi = RegionOfInterestMessage(left = 0.0, top = 0.0, width = 1.0, height = 1.0)

        assertNull(FrameRegion(640, 480, 90, roi).crop)
    }

    @Test
    fun `a box past the frame's edge stops at the edge`() {
        val roi = RegionOfInterestMessage(left = 0.8, top = 0.8, width = 0.5, height = 0.5)

        assertEquals(Rect(800, 400, 1000, 500), FrameRegion(1000, 500, 0, roi).crop)
    }

    @Test
    fun `a box with no area still reads a pixel`() {
        // One in the middle and one on the far corner, which need different guards.
        val rois = listOf(
            RegionOfInterestMessage(left = 0.5, top = 0.5, width = 0.0, height = 0.0),
            RegionOfInterestMessage(left = 1.0, top = 1.0, width = 0.0, height = 0.0),
        )

        for (roi in rois) {
            val crop = checkNotNull(FrameRegion(640, 480, 0, roi).crop)

            // ML Kit throws on an empty image.
            assertTrue("$roi", !crop.isEmpty && Rect(0, 0, 640, 480).contains(crop))
        }
    }
}
