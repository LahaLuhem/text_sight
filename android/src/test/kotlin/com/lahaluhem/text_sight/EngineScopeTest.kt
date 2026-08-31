package com.lahaluhem.text_sight

import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Test

/**
 * Whether detach really reaches work that is already running. The interesting case is the middle
 * one: it hangs, and the test times out, if the scope's job does not parent the work.
 */
class EngineScopeTest {
    @Test
    fun `run returns the value`() = runTest {
        val engine = EngineScope(StandardTestDispatcher(testScheduler))

        assertEquals("ok", engine.run { "ok" })
    }

    @Test
    fun `cancel interrupts work already in flight`() = runTest {
        val engine = EngineScope(StandardTestDispatcher(testScheduler))
        val started = CompletableDeferred<Unit>()
        var interrupted = false

        val call = async {
            engine.run {
                started.complete(Unit)
                try {
                    awaitCancellation()
                } finally {
                    interrupted = true
                }
            }
        }
        started.await()
        engine.cancel()
        call.join()

        assertTrue(interrupted, "the in-flight work was never cancelled")
        assertTrue(call.isCancelled)
    }

    @Test
    fun `run after cancel never reaches the work`() = runTest {
        val engine = EngineScope(StandardTestDispatcher(testScheduler))
        engine.cancel()
        var ran = false

        assertFailsWith<CancellationException> { engine.run { ran = true } }
        assertFalse(ran)
    }
}
