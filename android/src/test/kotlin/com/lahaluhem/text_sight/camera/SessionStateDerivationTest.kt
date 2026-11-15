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
        // The details are only log text, so the type and the reason are what gets compared.
        assertEquals(expected, deriveSessionState(status, camera)?.withoutDetails())
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
                state(CameraState.Type.PENDING_OPEN), SessionPausedMessage(reason = interrupted),
            ),
            // Opening, where CameraX reports this error, would otherwise be transient.
            arrayOf(
                "a recoverable error is an interruption", Status.ACTIVE,
                CameraState.create(
                    CameraState.Type.OPENING,
                    CameraState.StateError.create(CameraState.ERROR_OTHER_RECOVERABLE_ERROR),
                ),
                SessionPausedMessage(reason = interrupted),
            ),
            arrayOf(
                "a critical error is a failure", Status.ACTIVE,
                CameraState.create(
                    CameraState.Type.CLOSED,
                    CameraState.StateError.create(CameraState.ERROR_CAMERA_FATAL_ERROR),
                ),
                SessionFailedMessage(),
            ),
        )

        private fun open(): CameraState = state(CameraState.Type.OPEN)

        private fun state(type: CameraState.Type): CameraState = CameraState.create(type)
    }
}

private fun SessionStateMessage.withoutDetails(): SessionStateMessage = when (this) {
    is SessionPausedMessage -> SessionPausedMessage(reason = reason)
    is SessionFailedMessage -> SessionFailedMessage()
    else -> this
}
