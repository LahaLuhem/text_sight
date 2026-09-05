package com.lahaluhem.text_sight.camera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** The two selectors have to agree on shape. Robolectric supplies the real `Size`. */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class ResolutionSelectorsTest {
    @Test
    fun `preview and analysis ask for the same aspect ratio`() {
        assertEquals(
            analysisResolutionSelector().aspectRatioStrategy.preferredAspectRatio,
            previewResolutionSelector().aspectRatioStrategy.preferredAspectRatio,
        )
    }

    @Test
    fun `analysis asks for more than CameraX's VGA default`() {
        val bound = requireNotNull(analysisResolutionSelector().resolutionStrategy?.boundSize) {
            "no bound size, so analysis drops back to CameraX's own 640x480"
        }

        assertTrue(bound.width * bound.height > VGA_PIXELS)
    }

    private companion object {
        const val VGA_PIXELS = 640 * 480
    }
}
