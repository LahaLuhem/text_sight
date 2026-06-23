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
 * [TextSightCamera]. No recognition library crosses into the Dart pubspec — ML Kit
 * and CameraX are declared only in build.gradle.kts (the no-bundling contract).
 */
// Instantiated reflectively by Flutter's generated registrant (declared as `pluginClass` in
// pubspec.yaml), never referenced from Kotlin — the IDE's "never used" report is a false positive.
@Suppress("unused")
class TextSightPlugin :
    FlutterPlugin,
    ActivityAware,
    TextSightHostApi {
    private var camera: TextSightCamera? = null
    private var modelReadiness: TextSightModelReadiness? = null
    private var permissions: CameraPermissionRequester? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        TextSightHostApi.setUp(binding.binaryMessenger, this)

        val capturesChannel = EventChannel(binding.binaryMessenger, CAPTURES_CHANNEL_NAME)
        camera = TextSightCamera(binding.applicationContext, binding.textureRegistry, capturesChannel)

        val readinessChannel = EventChannel(binding.binaryMessenger, READINESS_CHANNEL_NAME)
        modelReadiness = TextSightModelReadiness(binding.applicationContext, readinessChannel)

        permissions = CameraPermissionRequester(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        TextSightHostApi.setUp(binding.binaryMessenger, null)

        camera?.dispose()
        camera = null
        modelReadiness = null
        permissions = null
    }

    override fun initialize(options: TextSightOptionsMessage, callback: (Result<Long>) -> Unit) {
        val activeCamera = camera ?: return callback(detached())

        activeCamera.initialize(options, callback)
    }

    override fun start(callback: (Result<Unit>) -> Unit) {
        val activeCamera = camera ?: return callback(detached())

        activeCamera.start(callback)
    }

    override fun stop(callback: (Result<Unit>) -> Unit) {
        val activeCamera = camera ?: return callback(detached())

        activeCamera.stop(callback)
    }

    override fun dispose(callback: (Result<Unit>) -> Unit) {
        val activeCamera = camera ?: return callback(detached())

        activeCamera.disposeSession(callback)
    }

    override fun checkCameraPermission(): CameraPermissionStatusMessage {
        val activePermissions = permissions ?: throw detachedError()

        return activePermissions.check()
    }

    override fun requestCameraPermission(callback: (Result<CameraPermissionStatusMessage>) -> Unit) {
        val activePermissions = permissions ?: return callback(detached())

        activePermissions.request(callback)
    }

    override fun setRegionOfInterest(roi: RegionOfInterestMessage?) {
        camera?.setRegionOfInterest(roi)
    }

    override fun setRecognitionLevel(level: RecognitionLevelMessage) {
        // No-op on Android: the ML Kit Latin recognizer exposes no accuracy/latency level.
    }

    override fun setLanguages(languages: List<String>) {
        // No-op on Android: the ML Kit Latin recognizer is not language-selectable.
    }

    override fun setTorchEnabled(enabled: Boolean) {
        camera?.setTorchEnabled(enabled)
    }

    override fun ensureModelReady(callback: (Result<Map<String, Any?>>) -> Unit) {
        val activeReadiness = modelReadiness ?: return callback(detached())

        activeReadiness.ensureModelReady(callback)
    }

    override fun recognizeImage(
        bytes: ByteArray,
        options: TextSightOptionsMessage,
        callback: (Result<Map<String, Any?>>) -> Unit,
    ) {
        val activeCamera = camera ?: return callback(detached())

        activeCamera.recognizeImage(bytes, options, callback)
    }

    override fun recognizePath(
        path: String,
        options: TextSightOptionsMessage,
        callback: (Result<Map<String, Any?>>) -> Unit,
    ) {
        val activeCamera = camera ?: return callback(detached())

        activeCamera.recognizePath(path, options, callback)
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

    // The runtime permission request needs a foreground Activity and a result listener; both arrive
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

        fun <T> detached(): Result<T> = Result.failure(detachedError())
    }
}
