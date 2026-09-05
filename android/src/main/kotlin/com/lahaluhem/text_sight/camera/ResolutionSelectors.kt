package com.lahaluhem.text_sight.camera

import android.util.Size
import com.lahaluhem.text_sight.CaptureResolutionMessage
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy

/**
 * Both streams need the same ratio, or boxes drawn on the preview land off. 4:3 is the sensor's own
 * shape, so it also sees the most page.
 */
private val captureAspect = AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY

/** Medium misses little on a page. Low is CameraX's old default, high is for fine print. */
private fun CaptureResolutionMessage.target(): Size = when (this) {
    CaptureResolutionMessage.LOW -> Size(640, 480)
    CaptureResolutionMessage.MEDIUM -> Size(1600, 1200)
    CaptureResolutionMessage.HIGH -> Size(2560, 1920)
}

/** What ML Kit reads. The device gives the nearest size it has, not always this one. */
internal fun analysisResolutionSelector(resolution: CaptureResolutionMessage): ResolutionSelector =
    ResolutionSelector.Builder()
        .setAspectRatioStrategy(captureAspect)
        .setResolutionStrategy(
            ResolutionStrategy(
                resolution.target(),
                ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
            ),
        )
        .build()

/** What the user sees. CameraX picks the size, the texture gets scaled to the widget anyway. */
internal fun previewResolutionSelector(): ResolutionSelector =
    ResolutionSelector.Builder().setAspectRatioStrategy(captureAspect).build()
