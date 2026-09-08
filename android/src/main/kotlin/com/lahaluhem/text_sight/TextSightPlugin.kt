package com.lahaluhem.text_sight

import com.lahaluhem.text_sight.camera.TextSightCamera
import com.lahaluhem.text_sight.permission.CameraPermissionRequester
import com.lahaluhem.text_sight.readiness.TextSightModelReadiness
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel

/**
 * The text_sight Android plugin.
 *
 * Wires the Pigeon control channel ([TextSightHostApi]), the per-frame captures
 * [EventChannel], and the preview texture, delegating capture and recognition to
 * [TextSightCamera]. No recognition library crosses into the Dart pubspec. ML Kit
 * and CameraX are declared only in build.gradle.kts (the no-bundling contract).
 */
// Instantiated reflectively by Flutter's generated registrant (declared as `pluginClass` in
// pubspec.yaml), never referenced from Kotlin, so the IDE's "never used" report is a false positive.
@Suppress("unused")
class TextSightPlugin :
    FlutterPlugin,
    ActivityAware,
    TextSightHostApi {
    private val engine = EngineScope()

    private var camera: TextSightCamera? = null
    private var modelReadiness: TextSightModelReadiness? = null
    private var permissions: CameraPermissionRequester? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        TextSightHostApi.setUp(binding.binaryMessenger, this)

        val stateApi = TextSightFlutterApi(binding.binaryMessenger)
        val capturesChannel = EventChannel(binding.binaryMessenger, CAPTURES_CHANNEL_NAME)
        camera = TextSightCamera(binding.applicationContext, binding.textureRegistry, capturesChannel) { state ->
            engine.launch {
                try {
                    stateApi.onSessionStateChanged(state)
                } catch (ignored: FlutterError) {
                    // No Dart handler attached (hot restart in progress, or detached).
                }
            }
        }

        val readinessChannel = EventChannel(binding.binaryMessenger, READINESS_CHANNEL_NAME)
        modelReadiness = TextSightModelReadiness(binding.applicationContext, readinessChannel)

        permissions = CameraPermissionRequester(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        TextSightHostApi.setUp(binding.binaryMessenger, null)
        // Cancel before the release below: it reports idle, and a cancelled scope drops the send.
        engine.cancel()

        camera?.dispose()
        camera = null
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
        val activeCamera = camera ?: throw detachedError()

        return engine.run { activeCamera.recognizeImage(bytes, options) }
    }

    override suspend fun recognizePath(
        path: String,
        options: TextSightOptionsMessage,
    ): Map<String, Any?> {
        val activeCamera = camera ?: throw detachedError()

        return engine.run { activeCamera.recognizePath(path, options) }
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

    // The runtime permission request needs a foreground Activity and a result listener. Both arrive
    // and depart with the ActivityAware lifecycle. The capture pipeline binds to a headless
    // LifecycleOwner, so the camera is unaffected by Activity attach/detach.
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
