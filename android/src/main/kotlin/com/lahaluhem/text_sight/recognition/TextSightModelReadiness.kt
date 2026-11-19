package com.lahaluhem.text_sight.recognition

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.common.moduleinstall.InstallStatusListener
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallClient
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate.InstallState
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.lahaluhem.text_sight.BuildConfig
import io.flutter.plugin.common.EventChannel
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Fetches the on-device ML Kit model and reports how that's going.
 *
 * Both drivers read through the same model, so readiness lives here, not on the camera. The bundled
 * model ([BuildConfig.USE_BUNDLED]) ships in the APK and is always ready. The default one downloads
 * through Play Services, where a recognizer doubles as the module to install. A missing Play
 * Services or a failed download is an "unavailable" state, never a crash.
 */
internal class TextSightModelReadiness(
    private val context: Context,
    readinessChannel: EventChannel,
) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    // Replayed to a late listener, like a progress bar opened mid-download, so it never starts
    // blank.
    private var currentState: Map<String, Any?>? = null

    init {
        readinessChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        currentState?.let { events?.success(it) }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /** Downloads the model if it's missing, streams progress, and returns how it ended. */
    suspend fun ensureModelReady(): Map<String, Any?> {
        if (BuildConfig.USE_BUNDLED) {
            return readyState().also { emit(it) }
        }

        return suspendCancellableCoroutine { continuation ->
            // The install listener fires repeatedly but must settle the caller once.
            var settled = false
            checkThenInstall { state ->
                if (!settled) {
                    settled = true
                    emit(state)
                    continuation.resume(state)
                }
            }
        }
    }

    private fun checkThenInstall(finish: (Map<String, Any?>) -> Unit) {
        val client = ModuleInstall.getClient(context)
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

        client.areModulesAvailable(recognizer)
            .addOnSuccessListener { response ->
                if (response.areModulesAvailable()) {
                    recognizer.close()
                    finish(readyState())
                } else {
                    install(client, recognizer, finish)
                }
            }
            .addOnFailureListener { error ->
                recognizer.close()
                finish(unavailableState(REASON_PLAY_SERVICES_UNAVAILABLE, error.message))
            }
    }

    private fun install(
        client: ModuleInstallClient,
        recognizer: TextRecognizer,
        finish: (Map<String, Any?>) -> Unit,
    ) {
        lateinit var listener: InstallStatusListener
        listener = InstallStatusListener { update ->
            when (update.installState) {
                InstallState.STATE_COMPLETED -> {
                    cleanup(client, recognizer, listener)
                    finish(readyState())
                }

                InstallState.STATE_FAILED, InstallState.STATE_CANCELED -> {
                    cleanup(client, recognizer, listener)
                    val detail = "installState=${update.installState}"
                    finish(unavailableState(REASON_DOWNLOAD_FAILED, detail))
                }

                else -> emit(downloadingState(update))
            }
        }

        val request = ModuleInstallRequest.newBuilder()
            .addApi(recognizer)
            .setListener(listener)
            .build()

        client.installModules(request)
            .addOnSuccessListener { response ->
                // Some devices report the module already present without ever firing a status update.
                if (response.areModulesAlreadyInstalled()) {
                    cleanup(client, recognizer, listener)
                    finish(readyState())
                }
            }
            .addOnFailureListener { error ->
                cleanup(client, recognizer, listener)
                finish(unavailableState(REASON_DOWNLOAD_FAILED, error.message))
            }
    }

    private fun cleanup(
        client: ModuleInstallClient,
        recognizer: TextRecognizer,
        listener: InstallStatusListener,
    ) {
        client.unregisterListener(listener)
        recognizer.close()
    }

    private fun emit(state: Map<String, Any?>) {
        currentState = state
        mainHandler.post { eventSink?.success(state) }
    }

    private companion object {
        const val REASON_PLAY_SERVICES_UNAVAILABLE = "playServicesUnavailable"
        const val REASON_DOWNLOAD_FAILED = "downloadFailed"
    }
}

private fun readyState(): Map<String, Any?> = mapOf("state" to "ready")

// Internal so a test can check the fraction, since an emulator can't trigger a real download.
internal fun downloadingState(update: ModuleInstallStatusUpdate): Map<String, Any?> {
    val progress = update.progressInfo?.let { info ->
        val total = info.totalBytesToDownload
        if (total > 0) info.bytesDownloaded.toDouble() / total else null
    }

    return mapOf("state" to "downloading", "progress" to progress)
}

private fun unavailableState(reason: String, details: String?): Map<String, Any?> =
    mapOf("state" to "unavailable", "reason" to reason, "details" to details)
