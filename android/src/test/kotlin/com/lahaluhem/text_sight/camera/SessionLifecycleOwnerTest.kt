package com.lahaluhem.text_sight.camera

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.MutableLiveData
import com.lahaluhem.text_sight.camera.SessionLifecycleOwner.Status
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

    // region status reporting

    private val statuses = mutableListOf<Status>()
    private val reporting = SessionLifecycleOwner(process.registry) { statuses += it }

    @Test
    fun `parked until resumed, then every real change is reported once`() {
        assertEquals(Status.PARKED, reporting.status)

        reporting.resume()
        process.registry.currentState = Lifecycle.State.CREATED
        process.registry.currentState = Lifecycle.State.STARTED
        process.registry.currentState = Lifecycle.State.RESUMED

        assertEquals(listOf(Status.ACTIVE, Status.CAPPED, Status.ACTIVE), statuses)
    }

    @Test
    fun `an onPause without an onStop is not a cap`() {
        reporting.resume()

        process.registry.currentState = Lifecycle.State.STARTED

        assertEquals(Status.ACTIVE, reporting.status)
        assertEquals(listOf(Status.ACTIVE), statuses)
    }

    @Test
    fun `park reports PARKED, and resume brings ACTIVE back`() {
        reporting.resume()

        reporting.park()
        reporting.resume()

        assertEquals(listOf(Status.ACTIVE, Status.PARKED, Status.ACTIVE), statuses)
    }

    @Test
    fun `a parked owner ignores the foreground`() {
        reporting.resume()
        reporting.park()

        process.registry.currentState = Lifecycle.State.CREATED
        process.registry.currentState = Lifecycle.State.RESUMED

        assertEquals(listOf(Status.ACTIVE, Status.PARKED), statuses)
    }

    @Test
    fun `destroy reports nothing`() {
        reporting.resume()

        reporting.destroy()

        assertEquals(listOf(Status.ACTIVE), statuses)
    }

    // A LiveData observed through the owner is what CameraX's camera state rides, so while the
    // owner is capped that input is blind, and the cap has to be the one that reports the pause.
    @Test
    fun `an observed LiveData is silent while capped and catches up with the latest value`() {
        val seen = mutableListOf<Int>()
        val live = MutableLiveData<Int>()
        owner.resume()
        live.observe(owner) { seen += it }
        live.value = 1

        process.registry.currentState = Lifecycle.State.CREATED
        live.value = 2
        live.value = 3
        assertEquals(listOf(1), seen)

        process.registry.currentState = Lifecycle.State.STARTED
        assertEquals(listOf(1, 3), seen)
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
