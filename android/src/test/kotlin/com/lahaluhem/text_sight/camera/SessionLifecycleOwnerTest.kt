package com.lahaluhem.text_sight.camera

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The headless owner must always reach DESTROYED, and its state is the session's intent capped
 * by the app's foreground state.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class SessionLifecycleOwnerTest {
    private val process = FakeProcessLifecycle()
    private val owner = SessionLifecycleOwner(process.registry)

    // region destroy safety

    @Test
    fun `destroy with no session ever started lands in DESTROYED`() {
        owner.destroy()

        assertEquals(Lifecycle.State.DESTROYED, owner.lifecycle.currentState)
    }

    @Test
    fun `destroy after a resumed session lands in DESTROYED`() {
        owner.resume()

        owner.destroy()

        assertEquals(Lifecycle.State.DESTROYED, owner.lifecycle.currentState)
    }

    @Test
    fun `destroy while backgrounded lands in DESTROYED`() {
        owner.resume()
        process.registry.currentState = Lifecycle.State.CREATED

        owner.destroy()

        assertEquals(Lifecycle.State.DESTROYED, owner.lifecycle.currentState)
    }

    // endregion

    // region foreground capping

    @Test
    fun `backgrounding drops a resumed session to CREATED and foregrounding restores it`() {
        owner.resume()

        process.registry.currentState = Lifecycle.State.CREATED
        assertEquals(Lifecycle.State.CREATED, owner.lifecycle.currentState)

        process.registry.currentState = Lifecycle.State.RESUMED
        assertEquals(Lifecycle.State.RESUMED, owner.lifecycle.currentState)
    }

    @Test
    fun `resume while backgrounded waits for the foreground`() {
        process.registry.currentState = Lifecycle.State.CREATED

        owner.resume()
        assertEquals(Lifecycle.State.CREATED, owner.lifecycle.currentState)

        process.registry.currentState = Lifecycle.State.RESUMED
        assertEquals(Lifecycle.State.RESUMED, owner.lifecycle.currentState)
    }

    @Test
    fun `a never-resumed owner ignores foreground flips`() {
        process.registry.currentState = Lifecycle.State.CREATED
        process.registry.currentState = Lifecycle.State.RESUMED

        assertEquals(Lifecycle.State.CREATED, owner.lifecycle.currentState)
    }

    @Test
    fun `a process lifecycle still at INITIALIZED cannot drag the owner below CREATED`() {
        val coldProcess = FakeProcessLifecycle(start = Lifecycle.State.INITIALIZED)
        val coldOwner = SessionLifecycleOwner(coldProcess.registry)

        coldOwner.resume()
        assertEquals(Lifecycle.State.CREATED, coldOwner.lifecycle.currentState)

        coldOwner.destroy()
        assertEquals(Lifecycle.State.DESTROYED, coldOwner.lifecycle.currentState)
    }

    @Test
    fun `process changes after destroy leave the owner DESTROYED`() {
        owner.resume()
        owner.destroy()

        process.registry.currentState = Lifecycle.State.CREATED
        process.registry.currentState = Lifecycle.State.RESUMED

        assertEquals(Lifecycle.State.DESTROYED, owner.lifecycle.currentState)
    }

    // endregion

    /** Stands in for ProcessLifecycleOwner: a registry the test moves by hand. */
    private class FakeProcessLifecycle(
        start: Lifecycle.State = Lifecycle.State.RESUMED,
    ) : LifecycleOwner {
        val registry = LifecycleRegistry(this).apply {
            if (start != Lifecycle.State.INITIALIZED) currentState = start
        }

        override val lifecycle: Lifecycle get() = registry
    }
}
