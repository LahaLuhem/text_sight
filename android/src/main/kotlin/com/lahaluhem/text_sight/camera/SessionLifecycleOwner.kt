package com.lahaluhem.text_sight.camera

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ProcessLifecycleOwner

/**
 * A [LifecycleOwner] driven manually so CameraX can bind without an Activity.
 *
 * Its state is the session's intent capped by the app's foreground state: backgrounding drops a
 * resumed session to CREATED (CameraX closes the camera), foregrounding lifts it back. Every real
 * change of [status] is reported through [onStatusChanged].
 */
internal class SessionLifecycleOwner(
    private val processLifecycle: Lifecycle = ProcessLifecycleOwner.get().lifecycle,
    private val onStatusChanged: (Status) -> Unit = {},
) : LifecycleOwner {
    /** The owner's standing from the session's point of view. */
    enum class Status {
        /** Nothing wants the session: never resumed, released, or parked by a failure. */
        PARKED,

        /** Wanted, but the app left the foreground and CameraX has closed the camera. */
        CAPPED,

        /** Wanted and allowed to run. */
        ACTIVE,
    }

    // Born CREATED: androidx has no way down from INITIALIZED, so destroy() on a never-resumed
    // owner would crash the engine detach.
    private val registry =
        LifecycleRegistry(this).apply { currentState = Lifecycle.State.CREATED }

    /** What the session wants: CREATED until [resume], RESUMED after, CREATED again after [park]. */
    private var wanted = Lifecycle.State.CREATED

    private var lastStatus = Status.PARKED

    private val foregroundObserver = object : DefaultLifecycleObserver {
        override fun onCreate(owner: LifecycleOwner) = sync()

        override fun onStart(owner: LifecycleOwner) = sync()

        override fun onResume(owner: LifecycleOwner) = sync()

        override fun onPause(owner: LifecycleOwner) = sync()

        override fun onStop(owner: LifecycleOwner) = sync()
    }

    init {
        processLifecycle.addObserver(foregroundObserver)
    }

    override val lifecycle: Lifecycle get() = registry

    // The cap bites at CREATED, where CameraX closes the camera. STARTED (an onPause without an
    // onStop) keeps frames flowing, so it is not a pause.
    val status: Status
        get() = when {
            wanted < Lifecycle.State.RESUMED -> Status.PARKED
            registry.currentState < Lifecycle.State.STARTED -> Status.CAPPED
            else -> Status.ACTIVE
        }

    fun resume() {
        wanted = Lifecycle.State.RESUMED
        sync()
    }

    /** Stops wanting the session. Only [resume] brings it back. */
    fun park() {
        wanted = Lifecycle.State.CREATED
        sync()
    }

    fun destroy() {
        processLifecycle.removeObserver(foregroundObserver)
        wanted = Lifecycle.State.CREATED
        registry.currentState = Lifecycle.State.DESTROYED
    }

    // The CREATED floor keeps a cold process lifecycle from dragging the registry into
    // INITIALIZED, the one state with no way down.
    private fun sync() {
        registry.currentState =
            minOf(wanted, processLifecycle.currentState).coerceAtLeast(Lifecycle.State.CREATED)

        val now = status
        if (now != lastStatus) {
            lastStatus = now
            onStatusChanged(now)
        }
    }
}
