package com.lahaluhem.text_sight

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.withContext

/**
 * Parents in-flight control calls so engine detach cancels them, instead of leaving a camera or
 * recognition call running against a torn-down engine.
 *
 * [SupervisorJob] so one failing call does not kill the scope for the next one.
 */
internal class EngineScope(dispatcher: CoroutineDispatcher = Dispatchers.Main.immediate) {
    private val scope = CoroutineScope(SupervisorJob() + dispatcher)

    /** Runs [work] as a child of this scope. */
    suspend fun <T> run(work: suspend () -> T): T = withContext(scope.coroutineContext) { work() }

    /** Cancels whatever is in flight. Nothing runs on this scope afterwards. */
    fun cancel() = scope.cancel()
}
