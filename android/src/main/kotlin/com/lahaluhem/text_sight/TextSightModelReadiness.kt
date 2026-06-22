package com.lahaluhem.text_sight

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
import io.flutter.plugin.common.EventChannel

/**
 * Owns the model-readiness EventChannel and the app-controlled fetch of the on-device ML Kit model.
 *
 * Mode-agnostic: the live and one-shot drivers recognize through the same model, so readiness lives
 * here rather than on the camera session. With the bundled model ([BuildConfig.USE_BUNDLED]) the
 * model ships in the APK, so readiness is always "ready" and no Google Play Services work happens.
 * With the default unbundled model the recognizer doubles as the `OptionalModuleApi` token:
 * [ModuleInstallClient] reports availability, downloads on request, and streams progress; a missing
 * Play Services or a failed download is reported as a terminal "unavailable" — a real state, never a
 * crash.
 *
 * Every event (and the terminal map [ensureModelReady] returns) is the same self-describing shape
 * the Dart side decodes: `{"state": "ready" | "downloading" | "unavailable", ...}`.
 */
internal class TextSightModelReadiness(
    private val context: Context,
    readinessChannel: EventChannel,
) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    // The last state emitted, replayed to a late subscriber (e.g. a progress UI attached after a
    // fetch began) so it is never left blank. Null until the first emit.
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

    /**
     * Triggers a check-and-fetch of the model and reports the terminal state via [callback];
     * intermediate [ModuleInstallStatusUpdate] progress streams on the readiness channel. Resolves
     * immediately when the model is already present — always so with the bundled model.
     */
    fun ensureModelReady(callback: (Result<Map<String, Any?>>) -> Unit) {
        var settled = false
        val finish = { state: Map<String, Any?> ->
            if (!settled) {
                settled = true
                emit(state)
                callback(Result.success(state))
            }
        }

        if (BuildConfig.USE_BUNDLED) {
            finish(readyState())
            return
        }

        checkThenInstall(finish)
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

        fun readyState(): Map<String, Any?> = mapOf("state" to "ready")

        fun downloadingState(update: ModuleInstallStatusUpdate): Map<String, Any?> {
            val progress = update.progressInfo?.let { info ->
                val total = info.totalBytesToDownload
                if (total > 0) info.bytesDownloaded.toDouble() / total else null
            }

            return mapOf("state" to "downloading", "progress" to progress)
        }

        fun unavailableState(reason: String, details: String?): Map<String, Any?> =
            mapOf("state" to "unavailable", "reason" to reason, "details" to details)
    }
}
