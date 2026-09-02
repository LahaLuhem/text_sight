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

/**
 * The frame release must not wait on the main looper. CameraX withholds the next analysis frame
 * until the close lands, so a main-thread hop ties the recognition rate to whatever the UI is
 * doing. Parking the looper is how that regression shows up here.
 */
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
}
