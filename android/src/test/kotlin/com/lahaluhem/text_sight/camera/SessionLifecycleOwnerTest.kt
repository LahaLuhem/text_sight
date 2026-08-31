package com.lahaluhem.text_sight.camera

import androidx.lifecycle.Lifecycle
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The headless owner must land in DESTROYED whether a session ever ran or not. Attach then
 * detach with no session in between is the path that used to crash the engine teardown (#40).
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class SessionLifecycleOwnerTest {
    @Test
    fun `destroy with no session ever started lands in DESTROYED`() {
        val owner = SessionLifecycleOwner()

        owner.destroy()

        assertEquals(Lifecycle.State.DESTROYED, owner.lifecycle.currentState)
    }

    @Test
    fun `destroy after a resumed session lands in DESTROYED`() {
        val owner = SessionLifecycleOwner()
        owner.resume()

        owner.destroy()

        assertEquals(Lifecycle.State.DESTROYED, owner.lifecycle.currentState)
    }
}
