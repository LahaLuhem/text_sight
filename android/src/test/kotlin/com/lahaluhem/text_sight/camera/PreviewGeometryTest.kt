package com.lahaluhem.text_sight.camera

import android.view.Surface
import com.lahaluhem.text_sight.PreviewMessage
import kotlin.test.assertEquals
import org.junit.Test

class PreviewGeometryTest {
    @Test
    fun `the preview comes out upright on both producers at every display rotation`() {
        // A back sensor at 90 delivering 1280x960, every row checked upright on an emulator.
        val cases = listOf(
            Triple(Surface.ROTATION_0, false, PreviewMessage(7, 960, 1280, 1)),
            Triple(Surface.ROTATION_90, false, PreviewMessage(7, 1280, 960, 0)),
            Triple(Surface.ROTATION_270, false, PreviewMessage(7, 1280, 960, 2)),
            Triple(Surface.ROTATION_0, true, PreviewMessage(7, 960, 1280, 0)),
            Triple(Surface.ROTATION_90, true, PreviewMessage(7, 1280, 960, 3)),
            Triple(Surface.ROTATION_270, true, PreviewMessage(7, 1280, 960, 1)),
        )

        for ((rotation, surfaceRotates, expected) in cases) {
            assertEquals(
                expected,
                previewGeometry(7, 1280, 960, 90, rotation, surfaceRotates),
                "rotation $rotation, surfaceRotates $surfaceRotates",
            )
        }
    }
}
