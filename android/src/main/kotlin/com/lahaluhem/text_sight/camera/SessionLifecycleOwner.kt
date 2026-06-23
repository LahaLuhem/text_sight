package com.lahaluhem.text_sight.camera

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry

/** A [LifecycleOwner] driven manually so CameraX can bind without an Activity. */
internal class SessionLifecycleOwner : LifecycleOwner {
    private val registry =
        LifecycleRegistry(this).apply { currentState = Lifecycle.State.INITIALIZED }

    override val lifecycle: Lifecycle get() = registry

    fun resume() {
        registry.currentState = Lifecycle.State.RESUMED
    }

    fun destroy() {
        registry.currentState = Lifecycle.State.DESTROYED
    }
}
