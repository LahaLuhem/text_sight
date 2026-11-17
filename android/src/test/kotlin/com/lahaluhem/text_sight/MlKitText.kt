package com.lahaluhem.text_sight

import android.graphics.Rect
import com.google.mlkit.vision.text.Text
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever

// ML Kit gives its results no public constructors, so tests build them from mocks.
internal fun mlKitLine(text: String, box: Rect, confidence: Float = 0.9f): Text.Line {
    val line = mock<Text.Line>()
    whenever(line.text).thenReturn(text)
    whenever(line.confidence).thenReturn(confidence)
    whenever(line.boundingBox).thenReturn(box)

    return line
}

internal fun mlKitText(vararg blocks: List<Text.Line>): Text {
    val text = mock<Text>()
    val textBlocks = blocks.map { lines ->
        mock<Text.TextBlock>().also { whenever(it.lines).thenReturn(lines) }
    }
    whenever(text.textBlocks).thenReturn(textBlocks)

    return text
}
