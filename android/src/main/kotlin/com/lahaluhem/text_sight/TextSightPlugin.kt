package com.lahaluhem.text_sight

import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.lahaluhem.text_sight.camera.CameraPermission
import com.lahaluhem.text_sight.camera.TextSightCamera
import com.lahaluhem.text_sight.recognition.StillRecognizer
import com.lahaluhem.text_sight.recognition.TextSightModelReadiness
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Wires up the Pigeon channel, the captures [EventChannel] and the preview texture, then hands the
 * work to [TextSightCamera] (live) and [StillRecognizer] (one-shot). ML Kit and CameraX come in
 * through build.gradle.kts only, never the Dart pubspec.
 */
// Flutter's generated registrant builds it by reflection (it's `pluginClass` in pubspec.yaml), so
// the IDE's "never used" is wrong.
@Suppress("unused")
class TextSightPlugin :
    FlutterPlugin,
    ActivityAware,
    TextSightHostApi {
    private val engine = EngineScope()

    // One ML Kit client and analysis thread for both drivers.
    private var recognizer: TextRecognizer? = null
    private var analysisExecutor: ExecutorService? = null
    private var camera: TextSightCamera? = null
    private var stills: StillRecognizer? = null
    private var modelReadiness: TextSightModelReadiness? = null
    private var permissions: CameraPermission? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        TextSightHostApi.setUp(binding.binaryMessenger, this)

        val flutterApi = TextSightFlutterApi(binding.binaryMessenger)
        val capturesChannel = EventChannel(binding.binaryMessenger, CAPTURES_CHANNEL_NAME)
        val client = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            .also { recognizer = it }
        val executor = Executors.newSingleThreadExecutor().also { analysisExecutor = it }
        camera = TextSightCamera(
            binding.applicationContext,
            binding.textureRegistry,
            capturesChannel,
            client,
            executor,
            onSessionState = { state -> notifyDart { flutterApi.onSessionStateChanged(state) } },
            onPreview = { preview -> notifyDart { flutterApi.onPreviewChanged(preview) } },
        )
        stills = StillRecognizer(client, executor)

        val readinessChannel = EventChannel(binding.binaryMessenger, READINESS_CHANNEL_NAME)
        modelReadiness = TextSightModelReadiness(binding.applicationContext, readinessChannel)

        permissions = CameraPermission(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        TextSightHostApi.setUp(binding.binaryMessenger, null)
        // Cancel before the release below: it reports idle, and a cancelled scope drops the send.
        engine.cancel()

        camera?.dispose()
        recognizer?.close()
        analysisExecutor?.shutdown()
        camera = null
        stills = null
        recognizer = null
        analysisExecutor = null
        modelReadiness = null
        permissions = null
    }

    override suspend fun initialize(
        options: TextSightOptionsMessage,
        resolution: CaptureResolutionMessage,
    ): Long {
        val activeCamera = camera ?: throw detachedError()

        return engine.run { activeCamera.initialize(options, resolution) }
    }

    override fun start() {
        val activeCamera = camera ?: throw detachedError()

        activeCamera.start()
    }

    override fun pauseRecognition() {
        val activeCamera = camera ?: throw detachedError()

        activeCamera.pauseRecognition()
    }

    override suspend fun dispose() {
        val activeCamera = camera ?: throw detachedError()

        engine.run { activeCamera.disposeSession() }
    }

    override fun checkCameraPermission(): CameraPermissionStatusMessage {
        val activePermissions = permissions ?: throw detachedError()

        return activePermissions.check()
    }

    override suspend fun requestCameraPermission(): CameraPermissionStatusMessage {
        val activePermissions = permissions ?: throw detachedError()

        return engine.run { activePermissions.request() }
    }

    override fun setOptions(options: TextSightOptionsMessage) {
        camera?.setOptions(options)
    }

    override fun confidenceScale(): ConfidenceScaleMessage = ConfidenceScaleMessage.ML_KIT

    override fun setTorchEnabled(enabled: Boolean) {
        camera?.setTorchEnabled(enabled)
    }

    override suspend fun ensureModelReady(): Map<String, Any?> {
        val activeReadiness = modelReadiness ?: throw detachedError()

        return engine.run { activeReadiness.ensureModelReady() }
    }

    override suspend fun recognizeImage(
        bytes: ByteArray,
        options: TextSightOptionsMessage,
    ): Map<String, Any?> {
        val activeStills = stills ?: throw detachedError()

        return engine.run { activeStills.recognizeImage(bytes, options) }
    }

    override suspend fun recognizePath(
        path: String,
        options: TextSightOptionsMessage,
    ): Map<String, Any?> {
        val activeStills = stills ?: throw detachedError()

        return engine.run { activeStills.recognizePath(path, options) }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        bindActivity(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        bindActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        unbindActivity()
    }

    override fun onDetachedFromActivity() {
        unbindActivity()
    }

    private fun notifyDart(send: suspend () -> Unit) = engine.launch {
        try {
            send()
        } catch (ignored: FlutterError) {
            // No Dart handler attached (hot restart in progress, or detached).
        }
    }

    // Asking for permission needs a foreground Activity and a result listener, which come and go
    // with it. The camera binds to its own LifecycleOwner, so Activity changes don't touch it.
    private fun bindActivity(binding: ActivityPluginBinding) {
        val activePermissions = permissions ?: return

        binding.addRequestPermissionsResultListener(activePermissions)
        activePermissions.activity = binding.activity
        activityBinding = binding
    }

    private fun unbindActivity() {
        permissions?.let { activePermissions ->
            activityBinding?.removeRequestPermissionsResultListener(activePermissions)
            activePermissions.activity = null
        }
        activityBinding = null
    }

    private companion object {
        const val CAPTURES_CHANNEL_NAME = "${BuildConfig.LIBRARY_PACKAGE_NAME}/captures"
        const val READINESS_CHANNEL_NAME = "${BuildConfig.LIBRARY_PACKAGE_NAME}/readiness"

        fun detachedError(): FlutterError =
            FlutterError("detached", "The plugin is not attached to a Flutter engine.")
    }
}
