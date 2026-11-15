package com.lahaluhem.text_sight

import android.graphics.Rect
import com.google.mlkit.vision.text.Text
import com.lahaluhem.text_sight.recognition.FrameRegion
import com.lahaluhem.text_sight.recognition.encodeFrame
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * `encodeFrame`: recognized text onto the per-frame wire map, which has to come out byte-identical
 * to the one iOS emits. ML Kit's [Text] graph is mocked, since its value types expose no public
 * constructors. The box geometry lives in [FrameRegionTest], [FrameRegionTurnsTest] and
 * [CenterWithinTest].
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class FrameEncodingTest {
    @Test
    fun `describes the frame upright and keeps every line in order`() {
        val text = textOf(line("ALPHA", Rect(10, 10, 110, 40)), line("BETA", Rect(10, 50, 110, 80)))

        val frame = encodeFrame(text, FrameRegion(100, 200, 90), quarterTurns = 1)

        assertEquals(200.0, frame["imageWidth"] as Double, 1e-9)
        assertEquals(100.0, frame["imageHeight"] as Double, 1e-9)
        assertEquals(1, frame["quarterTurns"] as Int)
        assertEquals(listOf("ALPHA", "BETA"), frame.lines().map { it["text"] })
    }

    @Test
    fun `normalizes each box to the frame and forwards its confidence`() {
        val text = textOf(line("HELLO", Rect(100, 200, 400, 260), confidence = 0.97f))

        val line = encodeFrame(text, FrameRegion(1000, 1000, 0), quarterTurns = 0).lines().single()

        assertEquals(0.97f.toDouble(), line["confidence"] as Double, 1e-6)
        assertEquals(0.1, line["left"] as Double, 1e-9)
        assertEquals(0.2, line["top"] as Double, 1e-9)
        assertEquals(0.3, line["width"] as Double, 1e-9)
        assertEquals(0.06, line["height"] as Double, 1e-9)
        assertNull(line["elements"])
    }

    @Test
    fun `places a box from a cropped read where it sits in the whole frame`() {
        // The crop starts at (200, 100), and ML Kit reports the line at the crop's corner.
        val roi = RegionOfInterestMessage(left = 0.2, top = 0.1, width = 0.5, height = 0.5)
        val text = textOf(line("CROP", Rect(0, 0, 100, 50)))

        val line = encodeFrame(text, FrameRegion(1000, 1000, 0, roi), quarterTurns = 0).lines().single()

        assertEquals(0.2, line["left"] as Double, 1e-9)
        assertEquals(0.1, line["top"] as Double, 1e-9)
    }

    @Test
    fun `drops lines whose centre falls outside the roi`() {
        // The first line's centre (0.05, 0.25) is outside, the second's (0.85, 0.25) inside.
        val text = textOf(line("OUT", Rect(0, 0, 20, 50)), line("IN", Rect(150, 0, 190, 50)))
        val roi = RegionOfInterestMessage(left = 0.5, top = 0.0, width = 0.5, height = 1.0)

        val frame = encodeFrame(text, FrameRegion(200, 100, 0), quarterTurns = 0, roi = roi)

        assertEquals(listOf("IN"), frame.lines().map { it["text"] })
    }

    @Suppress("UNCHECKED_CAST")
    private fun Map<String, Any?>.lines() = this["lines"] as List<Map<String, Any?>>

    private fun line(text: String, box: Rect, confidence: Float = 0.9f): Text.Line {
        val line = mock<Text.Line>()
        whenever(line.text).thenReturn(text)
        whenever(line.confidence).thenReturn(confidence)
        whenever(line.boundingBox).thenReturn(box)

        return line
    }

    /** A mocked [Text] of one block holding [lines]. */
    private fun textOf(vararg lines: Text.Line): Text {
        val block = mock<Text.TextBlock>()
        whenever(block.lines).thenReturn(lines.toList())
        val text = mock<Text>()
        whenever(text.textBlocks).thenReturn(listOf(block))

        return text
    }
}
