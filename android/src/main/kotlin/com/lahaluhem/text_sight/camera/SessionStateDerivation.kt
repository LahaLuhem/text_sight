package com.lahaluhem.text_sight.camera

import androidx.camera.core.CameraState
import com.lahaluhem.text_sight.SessionActiveMessage
import com.lahaluhem.text_sight.SessionFailedMessage
import com.lahaluhem.text_sight.SessionPauseReasonMessage
import com.lahaluhem.text_sight.SessionPausedMessage
import com.lahaluhem.text_sight.SessionStateMessage

/**
 * The state to report for the owner's [status] and the latest [camera] state, or null when there
 * is nothing new to say: a parked owner, or a camera state on its way somewhere else.
 */
internal fun deriveSessionState(
    status: SessionLifecycleOwner.Status,
    camera: CameraState?,
): SessionStateMessage? =
    when (status) {
        SessionLifecycleOwner.Status.PARKED -> null
        SessionLifecycleOwner.Status.CAPPED ->
            SessionPausedMessage(reason = SessionPauseReasonMessage.APP_BACKGROUNDED)
        SessionLifecycleOwner.Status.ACTIVE -> camera?.let(::describe)
    }

private fun describe(camera: CameraState): SessionStateMessage? {
    val error = camera.error

    return when {
        error != null && error.type == CameraState.ErrorType.CRITICAL ->
            SessionFailedMessage(details = errorName(error.code))
        error != null ->
            SessionPausedMessage(
                reason = SessionPauseReasonMessage.INTERRUPTED,
                details = errorName(error.code),
            )
        camera.type == CameraState.Type.OPEN -> SessionActiveMessage()
        camera.type == CameraState.Type.PENDING_OPEN ->
            SessionPausedMessage(reason = SessionPauseReasonMessage.INTERRUPTED, details = "pendingOpen")
        else -> null
    }
}

/** CameraX exposes the codes as plain ints, so name them for the logs. */
private fun errorName(code: Int): String =
    when (code) {
        CameraState.ERROR_CAMERA_IN_USE -> "ERROR_CAMERA_IN_USE"
        CameraState.ERROR_MAX_CAMERAS_IN_USE -> "ERROR_MAX_CAMERAS_IN_USE"
        CameraState.ERROR_OTHER_RECOVERABLE_ERROR -> "ERROR_OTHER_RECOVERABLE_ERROR"
        CameraState.ERROR_STREAM_CONFIG -> "ERROR_STREAM_CONFIG"
        CameraState.ERROR_CAMERA_DISABLED -> "ERROR_CAMERA_DISABLED"
        CameraState.ERROR_CAMERA_FATAL_ERROR -> "ERROR_CAMERA_FATAL_ERROR"
        CameraState.ERROR_DO_NOT_DISTURB_MODE_ENABLED -> "ERROR_DO_NOT_DISTURB_MODE_ENABLED"
        CameraState.ERROR_CAMERA_REMOVED -> "ERROR_CAMERA_REMOVED"
        else -> "error($code)"
    }
