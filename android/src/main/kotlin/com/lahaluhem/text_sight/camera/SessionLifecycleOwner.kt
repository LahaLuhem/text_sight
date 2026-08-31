package com.lahaluhem.text_sight.camera

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry

/** A [LifecycleOwner] driven manually so CameraX can bind without an Activity. */
internal class SessionLifecycleOwner : LifecycleOwner {
    // Born CREATED, not the default INITIALIZED. androidx has no way down from INITIALIZED,
    // so destroy() on a never-resumed owner would crash the engine detach (#40).
    private val registry =
        LifecycleRegistry(this).apply { currentState = Lifecycle.State.CREATED }

    override val lifecycle: Lifecycle get() = registry

    fun resume() {
        registry.currentState = Lifecycle.State.RESUMED
    }

    fun destroy() {
        registry.currentState = Lifecycle.State.DESTROYED
    }
}
