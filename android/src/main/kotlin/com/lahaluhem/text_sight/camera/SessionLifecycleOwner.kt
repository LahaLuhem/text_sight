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
 * resumed session to CREATED (CameraX closes the camera), foregrounding lifts it back.
 */
internal class SessionLifecycleOwner(
    private val processLifecycle: Lifecycle = ProcessLifecycleOwner.get().lifecycle,
) : LifecycleOwner {
    // Born CREATED: androidx has no way down from INITIALIZED, so destroy() on a never-resumed
    // owner would crash the engine detach.
    private val registry =
        LifecycleRegistry(this).apply { currentState = Lifecycle.State.CREATED }

    /** What the session wants: CREATED until [resume], RESUMED after. */
    private var wanted = Lifecycle.State.CREATED

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

    fun resume() {
        wanted = Lifecycle.State.RESUMED
        sync()
    }

    fun destroy() {
        processLifecycle.removeObserver(foregroundObserver)
        registry.currentState = Lifecycle.State.DESTROYED
    }

    // The CREATED floor keeps a cold process lifecycle from dragging the registry into
    // INITIALIZED, the one state with no way down.
    private fun sync() {
        registry.currentState =
            minOf(wanted, processLifecycle.currentState).coerceAtLeast(Lifecycle.State.CREATED)
    }
}
