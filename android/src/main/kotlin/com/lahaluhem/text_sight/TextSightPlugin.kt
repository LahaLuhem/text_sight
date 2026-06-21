package com.lahaluhem.text_sight

import io.flutter.embedding.engine.plugins.FlutterPlugin
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
    TextSightHostApi {
    private var camera: TextSightCamera? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        TextSightHostApi.setUp(binding.binaryMessenger, this)

        val capturesChannel = EventChannel(binding.binaryMessenger, CAPTURES_CHANNEL_NAME)
        camera = TextSightCamera(binding.applicationContext, binding.textureRegistry, capturesChannel)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        TextSightHostApi.setUp(binding.binaryMessenger, null)

        camera?.dispose()
        camera = null
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

    private companion object {
        const val CAPTURES_CHANNEL_NAME = "com.lahaluhem.text_sight/captures"

        fun <T> detached(): Result<T> =
            Result.failure(FlutterError("detached", "The plugin is not attached to a Flutter engine."))
    }
}
