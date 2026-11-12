package com.lahaluhem.text_sight.camera

import com.lahaluhem.text_sight.PreviewMessage

/**
 * [displayRotation] is a `Surface.ROTATION_*`. A [surfaceRotates] producer (the SurfaceTexture one)
 * has already applied the sensor's turn, so only the display's is left.
 */
internal fun previewGeometry(
    textureId: Long,
    bufferWidth: Int,
    bufferHeight: Int,
    sensorDegrees: Int,
    displayRotation: Int,
    surfaceRotates: Boolean,
): PreviewMessage {
    val displayDegrees = displayRotation * 90
    val uprightDegrees = (sensorDegrees - displayDegrees).mod(360)
    val turnDegrees = ((if (surfaceRotates) 0 else sensorDegrees) - displayDegrees).mod(360)
    val isQuarterTurned = uprightDegrees % 180 != 0

    return PreviewMessage(
        textureId = textureId,
        width = (if (isQuarterTurned) bufferHeight else bufferWidth).toLong(),
        height = (if (isQuarterTurned) bufferWidth else bufferHeight).toLong(),
        quarterTurns = (turnDegrees / 90).toLong(),
    )
}
