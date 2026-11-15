package com.lahaluhem.text_sight

import android.graphics.Rect
import com.lahaluhem.text_sight.recognition.FrameRegion
import kotlin.math.roundToInt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** What gets cut out of a frame, and the way back. The four turns are in [FrameRegionTurnsTest]. */
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

    @Test
    fun `what ML Kit reports lands where the text sits in the frame`() {
        // Stored turned, so the crop and the box sit in different places.
        val roi = RegionOfInterestMessage(left = 0.1, top = 0.2, width = 0.5, height = 0.3)
        val region = FrameRegion(400, 300, 90, roi)
        val crop = checkNotNull(region.crop)
        // Some text inside the crop, in the frame as stored.
        val text = Rect(crop.left + 5, crop.top + 10, crop.left + 25, crop.top + 18)
        // ML Kit measures it from the crop's corner, after turning the crop upright.
        val reported = Rect(text)
            .apply { offset(-crop.left, -crop.top) }
            .turned(90, crop.width(), crop.height())

        assertEquals(text.turned(90, 400, 300), region.toFrame(reported))
    }

    @Test
    fun `the crop starts and ends on even pixels and still covers the box`() {
        // Every edge of this box lands on an odd pixel.
        val roi = RegionOfInterestMessage(left = 0.1025, top = 0.21, width = 0.5, height = 0.3)
        val (width, height) = 400 to 300
        val crop = checkNotNull(FrameRegion(width, height, 0, roi).crop)
        val box = Rect(
            (roi.left * width).roundToInt(),
            (roi.top * height).roundToInt(),
            ((roi.left + roi.width) * width).roundToInt(),
            ((roi.top + roi.height) * height).roundToInt(),
        )

        assertTrue("$crop", listOf(crop.left, crop.top, crop.right, crop.bottom).all { it % 2 == 0 })
        assertTrue(crop.contains(box))
    }
}
