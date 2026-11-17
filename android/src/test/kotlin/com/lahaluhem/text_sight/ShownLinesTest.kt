package com.lahaluhem.text_sight

import android.graphics.Rect
import com.google.mlkit.vision.text.Text
import com.lahaluhem.text_sight.recognition.FrameRegion
import com.lahaluhem.text_sight.recognition.ShownLines
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class ShownLinesTest {
    // Its top edge sits at 250 px on a 1000 px frame.
    private val box = RegionOfInterestMessage(left = 0.0, top = 0.25, width = 1.0, height = 0.5)

    @Test
    fun `a line shown on the box's edge stays as the hand moves it just past`() {
        val shownLines = ShownLines()
        val region = FrameRegion(1000, 1000, 0, box)

        // Its centre starts just inside the top edge, then the hand lifts it just past.
        val frames = listOf(235, 225).map { top -> shownLines.linesIn(edgeLine(region, top), region, box) }

        assertEquals(listOf(listOf("EDGE"), listOf("EDGE")), frames.map { lines -> lines.map { it.text } })
    }

    @Test
    fun `a changed box starts with nothing shown`() {
        // The line stays put while the box moves down, leaving its centre just above the new top edge.
        val lowered = RegionOfInterestMessage(left = 0.0, top = 0.26, width = 1.0, height = 0.5)
        val shownLines = ShownLines()

        val frames = listOf(box, lowered).map { roi ->
            val region = FrameRegion(1000, 1000, 0, roi)
            shownLines.linesIn(edgeLine(region, top = 235), region, roi)
        }

        assertEquals(listOf(listOf("EDGE"), emptyList()), frames.map { lines -> lines.map { it.text } })
    }

    // ML Kit measures from the crop's corner, so a line meant to sit at `top` on the frame goes in
    // shifted by it.
    private fun edgeLine(region: FrameRegion, top: Int): Text {
        val reported = Rect(100, top, 900, top + 40)
        region.crop?.let { reported.offset(-it.left, -it.top) }

        return mlKitText(listOf(mlKitLine("EDGE", reported)))
    }
}
