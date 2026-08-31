package com.lahaluhem.text_sight

import com.google.android.gms.tasks.Task
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.CancellationException
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executor
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Suspends until this [Task] settles, delivering on [executor].
 *
 * [executor] is required because the no-executor overload delivers on the main looper. A cancelled
 * task throws [CancellationException] instead of cancelling the caller's job.
 */
internal suspend fun <T : Any> Task<T>.await(executor: Executor): T =
    suspendCancellableCoroutine { continuation ->
        addOnCompleteListener(executor) { settled ->
            val error = settled.exception
            when {
                error != null -> continuation.resumeWithException(error)
                settled.isCanceled ->
                    continuation.resumeWithException(CancellationException("Task was cancelled."))
                else -> continuation.resume(settled.result)
            }
        }
    }

/**
 * Suspends until this [ListenableFuture] settles, delivering on [executor].
 *
 * Cancelling the coroutine cancels the future. Same cancellation contract as [Task.await].
 */
internal suspend fun <T : Any> ListenableFuture<T>.await(executor: Executor): T =
    suspendCancellableCoroutine { continuation ->
        addListener(
            {
                try {
                    continuation.resume(get())
                } catch (error: ExecutionException) {
                    // The cause, not the future's wrapper.
                    continuation.resumeWithException(error.cause ?: error)
                } catch (error: CancellationException) {
                    continuation.resumeWithException(error)
                }
            },
            executor,
        )
        continuation.invokeOnCancellation { this@await.cancel(false) }
    }
