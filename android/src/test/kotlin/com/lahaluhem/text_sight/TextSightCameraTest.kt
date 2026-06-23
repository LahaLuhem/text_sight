package com.lahaluhem.text_sight

import android.graphics.Rect
import com.google.mlkit.vision.text.Text
import com.lahaluhem.text_sight.recognition.centerWithin
import com.lahaluhem.text_sight.recognition.encodeFrame
import com.lahaluhem.text_sight.recognition.encodeLine
import com.lahaluhem.text_sight.recognition.toPixelRect
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Host-side unit tests for the pure box-geometry and per-frame encoding helpers behind the captures
 * wire contract. Robolectric supplies a real [android.graphics.Rect]; ML Kit's [Text] graph is
 * mocked, since its value types expose no public constructors. No camera, recognizer, or texture is
 * involved — only the platform-independent arithmetic.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class TextSightCameraTest {
    // region toPixelRect — normalized [0, 1] top-left -> clamped pixel Rect, never empty.

    @Test
    fun `toPixelRect maps a centered roi to the matching pixel rect`() {
        val roi = RegionOfInterestMessage(left = 0.25, top = 0.25, width = 0.5, height = 0.5)

        val rect = roi.toPixelRect(imageWidth = 1000, imageHeight = 500)

        assertEquals(Rect(250, 125, 750, 375), rect)
    }

    @Test
    fun `toPixelRect spanning the whole frame covers every pixel`() {
        val roi = RegionOfInterestMessage(left = 0.0, top = 0.0, width = 1.0, height = 1.0)

        val rect = roi.toPixelRect(imageWidth = 1920, imageHeight = 1080)

        assertEquals(Rect(0, 0, 1920, 1080), rect)
    }

    @Test
    fun `toPixelRect clamps a roi that overflows the image`() {
        val roi = RegionOfInterestMessage(left = 0.8, top = 0.8, width = 0.5, height = 0.5)

        val rect = roi.toPixelRect(imageWidth = 1000, imageHeight = 1000)

        // right/bottom clamp to the image edge; left/top stay inside so the rect is non-empty.
        assertEquals(Rect(800, 800, 1000, 1000), rect)
        assertTrue(rect.width() > 0)
        assertTrue(rect.height() > 0)
    }

    @Test
    fun `toPixelRect never yields an empty rect for a degenerate roi`() {
        val roi = RegionOfInterestMessage(left = 1.0, top = 1.0, width = 0.0, height = 0.0)

        val rect = roi.toPixelRect(imageWidth = 640, imageHeight = 480)

        // left/top coerced one pixel inside the far edge; right/bottom at least one past them.
        assertEquals(639, rect.left)
        assertEquals(479, rect.top)
        assertEquals(640, rect.right)
        assertEquals(480, rect.bottom)
        assertTrue(rect.width() >= 1)
        assertTrue(rect.height() >= 1)
    }

    // endregion

    // region centerWithin — does the box center fall inside the (normalized) roi?

    @Test
    fun `centerWithin is always true when the roi is null`() {
        val box = Rect(0, 0, 10, 10)

        assertTrue(box.centerWithin(roi = null, imageWidth = 100.0, imageHeight = 100.0))
    }

    @Test
    fun `centerWithin accepts a box centered inside the roi`() {
        val roi = RegionOfInterestMessage(left = 0.25, top = 0.25, width = 0.5, height = 0.5)
        // Center (0.5, 0.5) sits inside the [0.25, 0.75] box.
        val box = Rect(400, 400, 600, 600)

        assertTrue(box.centerWithin(roi, imageWidth = 1000.0, imageHeight = 1000.0))
    }

    @Test
    fun `centerWithin rejects a box centered outside the roi`() {
        val roi = RegionOfInterestMessage(left = 0.25, top = 0.25, width = 0.5, height = 0.5)
        // Center (0.9, 0.9) sits outside the [0.25, 0.75] box.
        val box = Rect(880, 880, 920, 920)

        assertFalse(box.centerWithin(roi, imageWidth = 1000.0, imageHeight = 1000.0))
    }

    @Test
    fun `centerWithin includes a box centered exactly on the roi edge`() {
        val roi = RegionOfInterestMessage(left = 0.0, top = 0.0, width = 0.5, height = 0.5)
        // Center exactly (0.5, 0.5) == the roi's right/bottom edge; the bounds are inclusive.
        val box = Rect(400, 400, 600, 600)

        assertTrue(box.centerWithin(roi, imageWidth = 1000.0, imageHeight = 1000.0))
    }

    // endregion

    // region encodeLine — one recognized line -> its per-frame wire map.

    @Test
    fun `encodeLine normalizes the box and forwards confidence`() {
        val line = mock<Text.Line>()
        whenever(line.text).thenReturn("HELLO")
        whenever(line.confidence).thenReturn(0.97f)

        val map = encodeLine(
            line,
            boundingBox = Rect(100, 200, 400, 260),
            imageWidth = 1000.0,
            imageHeight = 1000.0,
            offsetX = 0,
            offsetY = 0,
        )

        assertEquals("HELLO", map["text"])
        assertEquals(0.97f.toDouble(), map["confidence"] as Double, 1e-6)
        assertEquals(0.1, map["left"] as Double, 1e-9)
        assertEquals(0.2, map["top"] as Double, 1e-9)
        assertEquals(0.3, map["width"] as Double, 1e-9)
        assertEquals(0.06, map["height"] as Double, 1e-9)
        assertNull(map["elements"])
    }

    @Test
    fun `encodeLine offsets boxes back into full-image coordinates`() {
        val line = mock<Text.Line>()
        whenever(line.text).thenReturn("CROP")
        whenever(line.confidence).thenReturn(0.5f)

        // The box is relative to a crop whose origin is (200, 100) in the full image.
        val map = encodeLine(line, Rect(0, 0, 100, 50), 1000.0, 1000.0, offsetX = 200, offsetY = 100)

        assertEquals(0.2, map["left"] as Double, 1e-9)
        assertEquals(0.1, map["top"] as Double, 1e-9)
    }

    // endregion

    // region encodeFrame — the full Text graph -> the self-describing per-frame map.

    @Test
    fun `encodeFrame builds the self-describing frame map and flattens blocks`() {
        val text = twoLineText("ALPHA", Rect(10, 10, 110, 40), "BETA", Rect(10, 50, 110, 80))

        val frame = encodeFrame(text, imageWidth = 200, imageHeight = 100, quarterTurns = 1)

        assertEquals(200.0, frame["imageWidth"] as Double, 1e-9)
        assertEquals(100.0, frame["imageHeight"] as Double, 1e-9)
        assertEquals(1, frame["quarterTurns"] as Int)

        @Suppress("UNCHECKED_CAST")
        val lines = frame["lines"] as List<Map<String, Any?>>
        assertEquals(2, lines.size)
        assertEquals("ALPHA", lines[0]["text"])
        assertEquals("BETA", lines[1]["text"])
    }

    @Test
    fun `encodeFrame drops lines whose center falls outside the roi`() {
        // Left line center ~ (0.05, 0.25) is outside; right line center ~ (0.85, 0.25) is inside.
        val text = twoLineText("OUT", Rect(0, 0, 20, 50), "IN", Rect(150, 0, 190, 50))
        val roi = RegionOfInterestMessage(left = 0.5, top = 0.0, width = 0.5, height = 1.0)

        val frame = encodeFrame(text, imageWidth = 200, imageHeight = 100, quarterTurns = 0, roi = roi)

        @Suppress("UNCHECKED_CAST")
        val lines = frame["lines"] as List<Map<String, Any?>>
        assertEquals(1, lines.size)
        assertEquals("IN", lines.single()["text"])
    }

    // endregion

    /** A mocked [Text] of one block holding two lines, each with a stubbed text/confidence/box. */
    private fun twoLineText(
        firstText: String,
        firstBox: Rect,
        secondText: String,
        secondBox: Rect,
    ): Text {
        val first = mock<Text.Line>()
        whenever(first.text).thenReturn(firstText)
        whenever(first.confidence).thenReturn(0.9f)
        whenever(first.boundingBox).thenReturn(firstBox)

        val second = mock<Text.Line>()
        whenever(second.text).thenReturn(secondText)
        whenever(second.confidence).thenReturn(0.9f)
        whenever(second.boundingBox).thenReturn(secondBox)

        val block = mock<Text.TextBlock>()
        whenever(block.lines).thenReturn(listOf(first, second))

        val text = mock<Text>()
        whenever(text.textBlocks).thenReturn(listOf(block))

        return text
    }
}
