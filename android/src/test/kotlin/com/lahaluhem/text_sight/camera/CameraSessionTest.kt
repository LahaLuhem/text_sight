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
import org.mockito.kotlin.mock
import org.mockito.kotlin.times
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
    fun `open routes through the injected main dispatcher`() = runTest {
        val recording = RecordingDispatcher(StandardTestDispatcher(testScheduler))

        // Robolectric denies the camera permission, so open() fails fast. The dispatch is the point.
        assertFailsWith<FlutterError> { newSession(recording).open(CaptureResolutionMessage.MEDIUM) }

        assertTrue(recording.dispatches > 0, "open() never went through mainDispatcher")
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

    // A stranded producer never goes away: the engine keeps every one it hands out in a list until
    // release(), so its texture and buffers sit there for the life of the engine.
    @Test
    fun `repeated opens strand no producer`() = runTest {
        grantCamera()
        val first = mock<TextureRegistry.SurfaceProducer>()
        val second = mock<TextureRegistry.SurfaceProducer>()
        val registry = mock<TextureRegistry> {
            on { createSurfaceProducer() }.thenReturn(first, second)
        }
        val session = newSession(StandardTestDispatcher(testScheduler), registry)

        assertFailsWith<FlutterError> { session.open(CaptureResolutionMessage.MEDIUM) }
        assertFailsWith<FlutterError> { session.open(CaptureResolutionMessage.MEDIUM) }

        verify(registry, times(2)).createSurfaceProducer()
        verify(first).release()
        verify(second).release()
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

    private class RecordingDispatcher(
        private val delegate: CoroutineDispatcher,
    ) : CoroutineDispatcher() {
        var dispatches = 0

        override fun dispatch(context: CoroutineContext, block: Runnable) {
            dispatches++
            delegate.dispatch(context, block)
        }
    }
}
