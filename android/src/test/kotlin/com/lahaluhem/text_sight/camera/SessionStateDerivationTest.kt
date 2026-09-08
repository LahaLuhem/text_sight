package com.lahaluhem.text_sight.camera

import androidx.camera.core.CameraState
import com.lahaluhem.text_sight.SessionActiveMessage
import com.lahaluhem.text_sight.SessionFailedMessage
import com.lahaluhem.text_sight.SessionPauseReasonMessage
import com.lahaluhem.text_sight.SessionPausedMessage
import com.lahaluhem.text_sight.SessionStateMessage
import com.lahaluhem.text_sight.camera.SessionLifecycleOwner.Status
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config

/** `deriveSessionState`: owner status plus camera state in, the state to report (or nothing) out. */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
internal class SessionStateDerivationTest(
    // The runner reads this positionally for the row's display name, so no test body touches it.
    @Suppress("UnusedPrivateProperty") case: String,
    private val status: Status,
    private val camera: CameraState?,
    private val expected: SessionStateMessage?,
) {
    @Test
    fun `derives the state to report`() {
        assertEquals(expected, deriveSessionState(status, camera))
    }

    companion object {
        private val interrupted = SessionPauseReasonMessage.INTERRUPTED

        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun cases(): Collection<Array<Any?>> = listOf(
            arrayOf("a parked owner says nothing", Status.PARKED, open(), null),
            arrayOf(
                "a capped owner is the plugin's own pause", Status.CAPPED, null,
                SessionPausedMessage(reason = SessionPauseReasonMessage.APP_BACKGROUNDED),
            ),
            arrayOf("an active owner with no camera state yet says nothing", Status.ACTIVE, null, null),
            arrayOf("an open camera is active", Status.ACTIVE, open(), SessionActiveMessage()),
            arrayOf("opening is transient", Status.ACTIVE, state(CameraState.Type.OPENING), null),
            arrayOf("closing is transient", Status.ACTIVE, state(CameraState.Type.CLOSING), null),
            arrayOf("closed without an error is transient", Status.ACTIVE, state(CameraState.Type.CLOSED), null),
            arrayOf(
                "pending open without an error is an interruption", Status.ACTIVE,
                state(CameraState.Type.PENDING_OPEN),
                SessionPausedMessage(reason = interrupted, details = "pendingOpen"),
            ),
            arrayOf(
                "a recoverable error is an interruption, named", Status.ACTIVE,
                CameraState.create(
                    CameraState.Type.PENDING_OPEN,
                    CameraState.StateError.create(CameraState.ERROR_CAMERA_IN_USE),
                ),
                SessionPausedMessage(reason = interrupted, details = "ERROR_CAMERA_IN_USE"),
            ),
            arrayOf(
                "a critical error is a failure, named", Status.ACTIVE,
                CameraState.create(
                    CameraState.Type.CLOSED,
                    CameraState.StateError.create(CameraState.ERROR_CAMERA_FATAL_ERROR),
                ),
                SessionFailedMessage(details = "ERROR_CAMERA_FATAL_ERROR"),
            ),
        )

        private fun open(): CameraState = state(CameraState.Type.OPEN)

        private fun state(type: CameraState.Type): CameraState = CameraState.create(type)
    }
}
