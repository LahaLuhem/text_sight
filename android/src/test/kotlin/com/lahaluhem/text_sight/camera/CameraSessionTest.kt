package com.lahaluhem.text_sight.camera

import android.Manifest
import androidx.camera.core.ImageAnalysis
import com.lahaluhem.text_sight.CaptureResolutionMessage
import com.lahaluhem.text_sight.FlutterError
import io.flutter.view.TextureRegistry
import java.util.concurrent.Executor
import kotlin.coroutines.CoroutineContext
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.doAnswer
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config

/**
 * The main-thread and producer-lifetime contracts on [CameraSession]. CameraX's `LiveData`
 * observers and the lifecycle registry reject other threads, and the injected dispatcher is the
 * single place that guarantees it, so a regression is someone dropping the `withContext`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class CameraSessionTest {
    private val direct = Executor { it.run() }

    @Test
    fun `open does its work on the injected main dispatcher`() = runTest {
        grantCamera()
        val recording = RecordingDispatcher(StandardTestDispatcher(testScheduler))
        var claimedOnMain = false
        val registry = mock<TextureRegistry> {
            on { createSurfaceProducer() } doAnswer {
                claimedOnMain = recording.isRunning
                mock<TextureRegistry.SurfaceProducer>()
            }
        }

        // CameraX cannot start under Robolectric, so open() fails once past the producer.
        assertFailsWith<FlutterError> {
            newSession(recording, registry).open(CaptureResolutionMessage.MEDIUM)
        }

        assertTrue(claimedOnMain, "open() claimed the producer off mainDispatcher")
    }

    @Test
    fun `open reports permission-denied when the camera permission is missing`() = runTest {
        val error = assertFailsWith<FlutterError> {
            newSession(StandardTestDispatcher(testScheduler)).open(CaptureResolutionMessage.MEDIUM)
        }

        assertEquals("permission-denied", error.code)
    }

    @Test
    fun `a failed open releases the producer it claimed`() = runTest {
        grantCamera()
        val producer = mock<TextureRegistry.SurfaceProducer>()
        val registry = mock<TextureRegistry> { on { createSurfaceProducer() }.thenReturn(producer) }

        // CameraX cannot start under Robolectric, so open() always fails once past the producer.
        assertFailsWith<FlutterError> {
            newSession(StandardTestDispatcher(testScheduler), registry).open(CaptureResolutionMessage.MEDIUM)
        }

        verify(producer).release()
    }

    private fun grantCamera() = Shadows.shadowOf(RuntimeEnvironment.getApplication())
        .grantPermissions(Manifest.permission.CAMERA)

    private fun newSession(
        dispatcher: CoroutineDispatcher,
        registry: TextureRegistry = mock(),
    ) = CameraSession(
        RuntimeEnvironment.getApplication(),
        registry,
        direct,
        ImageAnalysis.Analyzer { _ -> },
        mainExecutor = direct,
        mainDispatcher = dispatcher,
    )

    /** Knows whether work it dispatched is running right now. */
    private class RecordingDispatcher(
        private val delegate: CoroutineDispatcher,
    ) : CoroutineDispatcher() {
        var isRunning = false
            private set

        override fun dispatch(context: CoroutineContext, block: Runnable) {
            delegate.dispatch(context) {
                isRunning = true
                try {
                    block.run()
                } finally {
                    isRunning = false
                }
            }
        }
    }
}
