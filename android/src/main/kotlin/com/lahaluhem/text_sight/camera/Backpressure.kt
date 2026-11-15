package com.lahaluhem.text_sight.camera

import androidx.camera.core.ImageProxy
import com.google.android.gms.tasks.Task

/**
 * Closes [imageProxy] and [cutOut] on whichever thread settles the task. CameraX holds the next
 * frame until the proxy closes, and the no-Executor overload would park every frame behind the UI.
 */
internal fun <T> Task<T>.closeWhenSettled(imageProxy: ImageProxy, cutOut: AutoCloseable? = null): Task<T> =
    addOnCompleteListener(Runnable::run) {
        cutOut?.close()
        imageProxy.close()
    }
