package com.lahaluhem.text_sight

import androidx.concurrent.futures.ResolvableFuture
import com.google.android.gms.tasks.OnCompleteListener
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.TaskCompletionSource
import java.io.IOException
import java.util.concurrent.CancellationException
import java.util.concurrent.Executor
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The two suspend bridges in `Await.kt`.
 *
 * Robolectric because Play Services static-initializes against the framework. Failures assert on
 * message, not identity: coroutine stack-trace recovery hands the caller a copy.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class AwaitTest {
    private val direct = Executor { it.run() }

    @Test
    fun `task await resolves with the value`() = runTest {
        val source = TaskCompletionSource<String>()
        source.setResult("recognized")

        assertEquals("recognized", source.task.await(direct))
    }

    @Test
    fun `task await rethrows the original failure`() = runTest {
        val source = TaskCompletionSource<String>()
        source.setException(IOException("model download failed"))

        val thrown = assertFailsWith<IOException> { source.task.await(direct) }
        assertEquals("model download failed", thrown.message)
    }

    @Test
    fun `task await surfaces a cancelled task at the call site`() = runTest {
        // Stubbed, not token-driven: Play Services' token never settles the task under Robolectric.
        val cancelled = mock<Task<String>>()
        whenever(cancelled.exception).thenReturn(null)
        whenever(cancelled.isCanceled).thenReturn(true)
        whenever(cancelled.addOnCompleteListener(any<Executor>(), any())).thenAnswer { call ->
            call.getArgument<OnCompleteListener<String>>(1).onComplete(cancelled)
            cancelled
        }

        assertFailsWith<CancellationException> { cancelled.await(direct) }
    }

    @Test
    fun `task await delivers on the supplied executor`() = runTest {
        val source = TaskCompletionSource<String>()
        source.setResult("recognized")
        var dispatches = 0
        val counting = Executor { command ->
            dispatches++
            command.run()
        }

        source.task.await(counting)

        // Guards the no-executor overload creeping back, which delivers on the main looper.
        assertEquals(1, dispatches)
    }

    @Test
    fun `future await resolves with the value`() = runTest {
        val future = ResolvableFuture.create<String>()
        future.set("provider")

        assertEquals("provider", future.await(direct))
    }

    @Test
    fun `future await unwraps the execution exception`() = runTest {
        val future = ResolvableFuture.create<String>()
        future.setException(IOException("no camera"))

        val thrown = assertFailsWith<IOException> { future.await(direct) }
        assertEquals("no camera", thrown.message)
    }

    @Test
    fun `future await cancels when the future is cancelled`() = runTest {
        val future = ResolvableFuture.create<String>()
        future.cancel(false)

        assertFailsWith<CancellationException> { future.await(direct) }
    }

    @Test
    fun `cancelling the coroutine cancels the future`() = runTest {
        val future = ResolvableFuture.create<String>()

        val pending = async { future.await(direct) }
        // Reach the suspension point first, so invokeOnCancellation is registered.
        runCurrent()
        pending.cancel()
        pending.join()

        assertTrue(future.isCancelled)
    }
}
