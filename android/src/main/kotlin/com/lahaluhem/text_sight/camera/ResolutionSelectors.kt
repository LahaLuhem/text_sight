package com.lahaluhem.text_sight.camera

import android.util.Size
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy

/**
 * Both streams need the same ratio, or boxes drawn on the preview land off. 4:3 is the sensor's own
 * shape, so it also sees the most page.
 */
private val captureAspect = AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY

/** ~2 MP. VGA misses about half a document's lines, and more pixels cost frame rate. */
private val analysisTarget = Size(1600, 1200)

/** What ML Kit reads. The device gives the nearest size it has, not always this one. */
internal fun analysisResolutionSelector(): ResolutionSelector =
    ResolutionSelector.Builder()
        .setAspectRatioStrategy(captureAspect)
        .setResolutionStrategy(
            ResolutionStrategy(
                analysisTarget,
                ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
            ),
        )
        .build()

/** What the user sees. CameraX picks the size, the texture gets scaled to the widget anyway. */
internal fun previewResolutionSelector(): ResolutionSelector =
    ResolutionSelector.Builder().setAspectRatioStrategy(captureAspect).build()
