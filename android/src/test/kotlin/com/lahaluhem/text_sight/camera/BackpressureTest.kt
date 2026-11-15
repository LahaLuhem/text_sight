package com.lahaluhem.text_sight.camera

import android.os.Looper
import androidx.camera.core.ImageProxy
import com.google.android.gms.tasks.Tasks
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/** Parking the main looper makes a hop onto main show up as a close that never lands. */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class BackpressureTest {
    @Test
    fun `close lands while the main looper is parked`() {
        val imageProxy = mock<ImageProxy>()
        shadowOf(Looper.getMainLooper()).pause()

        Tasks.forResult(Unit).closeWhenSettled(imageProxy)

        verify(imageProxy).close()
    }

    @Test
    fun `close lands on a failed recognition too`() {
        val imageProxy = mock<ImageProxy>()
        shadowOf(Looper.getMainLooper()).pause()

        Tasks.forException<Unit>(IllegalStateException("recognition failed"))
            .closeWhenSettled(imageProxy)

        verify(imageProxy).close()
    }

    @Test
    fun `a part copied out of the frame is freed with it`() {
        val cutOut = mock<AutoCloseable>()
        shadowOf(Looper.getMainLooper()).pause()

        Tasks.forResult(Unit).closeWhenSettled(mock<ImageProxy>(), cutOut)

        verify(cutOut).close()
    }
}
