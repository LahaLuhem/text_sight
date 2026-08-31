package com.lahaluhem.text_sight.camera

import androidx.camera.core.ImageAnalysis
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
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The main-thread contract on [CameraSession]. CameraX's `LiveData` observers and the lifecycle
 * registry reject other threads, and the injected dispatcher is the single place that guarantees it,
 * so a regression is someone dropping the `withContext`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class CameraSessionTest {
    private val direct = Executor { it.run() }

    @Test
    fun `open routes through the injected main dispatcher`() = runTest {
        val recording = RecordingDispatcher(StandardTestDispatcher(testScheduler))

        // Robolectric denies the camera permission, so open() fails fast. The dispatch is the point.
        assertFailsWith<FlutterError> { newSession(recording).open() }

        assertTrue(recording.dispatches > 0, "open() never went through mainDispatcher")
    }

    @Test
    fun `open reports permission-denied when the camera permission is missing`() = runTest {
        val error = assertFailsWith<FlutterError> {
            newSession(StandardTestDispatcher(testScheduler)).open()
        }

        assertEquals("permission-denied", error.code)
    }

    private fun newSession(dispatcher: CoroutineDispatcher) = CameraSession(
        RuntimeEnvironment.getApplication(),
        mock<TextureRegistry>(),
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
