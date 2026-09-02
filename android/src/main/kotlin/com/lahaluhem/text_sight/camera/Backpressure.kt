package com.lahaluhem.text_sight.camera

import androidx.camera.core.ImageProxy
import com.google.android.gms.tasks.Task

/**
 * Closes [imageProxy] as soon as this task settles, on whatever thread settled it.
 *
 * CameraX holds the next frame back until this close lands, so it sets the recognition rate. The
 * no-Executor overload would post to the main looper and park every frame behind the UI.
 */
internal fun <T> Task<T>.closeWhenSettled(imageProxy: ImageProxy): Task<T> =
    addOnCompleteListener(Runnable::run) { imageProxy.close() }
