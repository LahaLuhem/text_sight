package com.lahaluhem.text_sight

import android.graphics.Rect
import com.google.mlkit.vision.text.Text
import com.lahaluhem.text_sight.recognition.FrameRegion
import com.lahaluhem.text_sight.recognition.encodeFrame
import com.lahaluhem.text_sight.recognition.linesIn
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** The wire map has to match iOS's. */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class FrameEncodingTest {
    @Test
    fun `describes the frame upright and keeps every line in order`() {
        // Two blocks, since ML Kit groups lines into blocks and every one has to come through.
        val text = mlKitText(
            listOf(mlKitLine("ALPHA", Rect(10, 10, 110, 40))),
            listOf(mlKitLine("BETA", Rect(10, 50, 110, 80))),
        )

        val frame = frameOf(text, FrameRegion(100, 200, 90), quarterTurns = 1)

        assertEquals(200.0, frame["imageWidth"] as Double, 1e-9)
        assertEquals(100.0, frame["imageHeight"] as Double, 1e-9)
        assertEquals(1, frame["quarterTurns"] as Int)
        assertEquals(listOf("ALPHA", "BETA"), frame.lines().map { it["text"] })
    }

    @Test
    fun `normalizes each box to the frame and forwards its confidence`() {
        val text = mlKitText(listOf(mlKitLine("HELLO", Rect(100, 200, 400, 260), confidence = 0.97f)))

        // Not square and stored turned, so each side has to be divided by the upright one it matches.
        val line = frameOf(text, FrameRegion(500, 1000, 90), quarterTurns = 1).lines().single()

        assertEquals(0.97f.toDouble(), line["confidence"] as Double, 1e-6)
        assertEquals(0.1, line["left"] as Double, 1e-9)
        assertEquals(0.4, line["top"] as Double, 1e-9)
        assertEquals(0.3, line["width"] as Double, 1e-9)
        assertEquals(0.12, line["height"] as Double, 1e-9)
    }

    @Test
    fun `places a box from a cropped read where it sits in the whole frame`() {
        // The read starts at (200, 200), half the box's height above it, and ML Kit measures from there.
        val roi = RegionOfInterestMessage(left = 0.2, top = 0.3, width = 0.5, height = 0.2)
        val text = mlKitText(listOf(mlKitLine("CROP", Rect(0, 100, 100, 150))))

        val line = frameOf(text, FrameRegion(1000, 1000, 0, roi), quarterTurns = 0).lines().single()

        assertEquals(0.2, line["left"] as Double, 1e-9)
        assertEquals(0.3, line["top"] as Double, 1e-9)
    }

    @Test
    fun `keeps only the lines centred in the box`() {
        // Half the frame tall, so the read takes in the whole frame and the rule still has to apply.
        val roi = RegionOfInterestMessage(left = 0.0, top = 0.25, width = 1.0, height = 0.5)
        val text = mlKitText(
            listOf(
                mlKitLine("INSIDE", Rect(100, 450, 900, 550)),
                mlKitLine("CUT, CENTRE INSIDE", Rect(100, 230, 900, 290)),
                mlKitLine("CUT, CENTRE OUTSIDE", Rect(100, 210, 900, 270)),
                mlKitLine("ABOVE THE BOX", Rect(100, 100, 900, 160)),
            ),
        )

        val frame = frameOf(text, FrameRegion(1000, 1000, 0, roi), quarterTurns = 0)

        assertEquals(listOf("INSIDE", "CUT, CENTRE INSIDE"), frame.lines().map { it["text"] })
    }

    // How the camera builds a frame when nothing was on screen before.
    private fun frameOf(text: Text, region: FrameRegion, quarterTurns: Int) =
        encodeFrame(text.linesIn(region), region, quarterTurns)

    @Suppress("UNCHECKED_CAST")
    private fun Map<String, Any?>.lines() = this["lines"] as List<Map<String, Any?>>
}
