package com.LahaLuhem.text_sight

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.Surface
import androidx.annotation.OptIn
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.Executors

/**
 * Owns the CameraX session, the ML Kit recognizer, and the preview texture for one
 * live recognition session.
 *
 * Recognition runs off the platform main thread on [analysisExecutor]; boxes are
 * normalized to top-left [0, 1] here (ML Kit yields pixel rects in the rotated image
 * space) and marshalled back to main before reaching the [EventChannel] sink.
 * Backpressure is [ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST] plus the mandatory
 * [ImageProxy.close] in the completion listener — without it the stream stalls.
 */
internal class TextSightCamera(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    capturesChannel: EventChannel,
) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val recognizer: TextRecognizer =
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    private val lifecycleOwner = SessionLifecycleOwner()

    private var eventSink: EventChannel.EventSink? = null
    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var camera: Camera? = null
    private var regionOfInterest: RegionOfInterestMessage? = null
    private var isRecognizing = false

    /**
     * Keeps [ImageAnalysis]'s target rotation in step with the live display rotation, so the
     * reported quarter-turns ([ImageProxy] rotationDegrees / 90) track the device in every
     * orientation. The headless session has no Activity to do this automatically, so without it
     * the rotation hint is stuck at the bind-time default and only portrait looks right.
     */
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = Unit

        override fun onDisplayRemoved(displayId: Int) = Unit

        override fun onDisplayChanged(displayId: Int) {
            if (displayId == Display.DEFAULT_DISPLAY) {
                imageAnalysis?.targetRotation = currentRotation()
            }
        }
    }

    init {
        capturesChannel.setStreamHandler(this)
        displayManager.registerDisplayListener(displayListener, mainHandler)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun initialize(options: TextSightOptionsMessage, callback: (Result<Long>) -> Unit) {
        // Recognition level and languages have no ML Kit Latin equivalent (see the
        // TextSightOptions docs); only the region-of-interest is honoured here.
        regionOfInterest = options.roi

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            callback(
                Result.failure(
                    FlutterError("permission-denied", "Camera permission has not been granted."),
                ),
            )
            return
        }

        val producer = textureRegistry.createSurfaceProducer()
        producer.setCallback(surfaceCallback)
        surfaceProducer = producer

        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            try {
                cameraProvider = providerFuture.get()
                lifecycleOwner.resume()
                bindUseCases()
                callback(Result.success(producer.id()))
            } catch (error: Exception) {
                callback(Result.failure(FlutterError("initialization-failed", error.message)))
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun start(callback: (Result<Unit>) -> Unit) {
        isRecognizing = true
        imageAnalysis?.setAnalyzer(analysisExecutor, ::analyze)

        callback(Result.success(Unit))
    }

    fun stop(callback: (Result<Unit>) -> Unit) {
        isRecognizing = false
        imageAnalysis?.clearAnalyzer()

        callback(Result.success(Unit))
    }

    fun disposeSession(callback: (Result<Unit>) -> Unit) {
        releaseSession()

        callback(Result.success(Unit))
    }

    fun setRegionOfInterest(roi: RegionOfInterestMessage?) {
        regionOfInterest = roi
    }

    fun setTorchEnabled(enabled: Boolean) {
        camera?.cameraControl?.enableTorch(enabled)
    }

    /** Releases every per-engine resource. Called when the plugin detaches from the engine. */
    fun dispose() {
        displayManager.unregisterDisplayListener(displayListener)
        releaseSession()
        lifecycleOwner.destroy()
        recognizer.close()
        analysisExecutor.shutdown()
    }

    private val surfaceCallback = object : TextureRegistry.SurfaceProducer.Callback {
        override fun onSurfaceAvailable() {
            bindUseCases()
        }

        override fun onSurfaceCleanup() {
            cameraProvider?.unbindAll()
        }
    }

    /** The live display rotation as a `Surface.ROTATION_*`, driving [ImageAnalysis]'s target rotation. */
    private fun currentRotation(): Int =
        displayManager.getDisplay(Display.DEFAULT_DISPLAY)?.rotation ?: Surface.ROTATION_0

    private fun bindUseCases() {
        val provider = cameraProvider ?: return
        val producer = surfaceProducer ?: return

        val preview = Preview.Builder().build().apply {
            setSurfaceProvider(ContextCompat.getMainExecutor(context)) { request ->
                producer.setSize(request.resolution.width, request.resolution.height)
                request.provideSurface(producer.surface, ContextCompat.getMainExecutor(context)) { _ ->
                    // Flutter owns the Surface via the SurfaceProducer; nothing to release here.
                }
            }
        }

        val analysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setTargetRotation(currentRotation())
            .build()
        imageAnalysis = analysis

        provider.unbindAll()
        camera = provider.bindToLifecycle(
            lifecycleOwner,
            CameraSelector.DEFAULT_BACK_CAMERA,
            preview,
            analysis,
        )

        if (isRecognizing) {
            analysis.setAnalyzer(analysisExecutor, ::analyze)
        }
    }

    @OptIn(ExperimentalGetImage::class)
    private fun analyze(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage == null || eventSink == null) {
            imageProxy.close()
            return
        }

        val rotationDegrees = imageProxy.imageInfo.rotationDegrees
        val isQuarterTurned = rotationDegrees == 90 || rotationDegrees == 270
        val imageWidth = if (isQuarterTurned) mediaImage.height else mediaImage.width
        val imageHeight = if (isQuarterTurned) mediaImage.width else mediaImage.height

        recognizer.process(InputImage.fromMediaImage(mediaImage, rotationDegrees))
            .addOnSuccessListener(analysisExecutor) { visionText ->
                val frame = encodeFrame(visionText, imageWidth, imageHeight, rotationDegrees / 90)
                mainHandler.post { eventSink?.success(frame) }
            }
            .addOnCompleteListener { imageProxy.close() }
    }

    private fun encodeFrame(
        visionText: Text,
        imageWidth: Int,
        imageHeight: Int,
        quarterTurns: Int,
    ): Map<String, Any?> {
        val width = imageWidth.toDouble()
        val height = imageHeight.toDouble()

        val lines = visionText.textBlocks
            .flatMap { block -> block.lines }
            .mapNotNull { line ->
                val boundingBox = line.boundingBox ?: return@mapNotNull null
                if (!boundingBox.centerWithin(regionOfInterest, width, height)) {
                    return@mapNotNull null
                }

                encodeLine(line, boundingBox, width, height)
            }

        return mapOf(
            "imageWidth" to width,
            "imageHeight" to height,
            "quarterTurns" to quarterTurns,
            "lines" to lines,
        )
    }

    private fun encodeLine(
        line: Text.Line,
        boundingBox: Rect,
        imageWidth: Double,
        imageHeight: Double,
    ): Map<String, Any?> =
        mapOf(
            "text" to line.text,
            // ML Kit v2 supplies a per-line confidence (null for a line that lacks one);
            // forwarded as-is per the RecognizedLine.confidence contract.
            "confidence" to line.confidence?.toDouble(),
            "left" to boundingBox.left / imageWidth,
            "top" to boundingBox.top / imageHeight,
            "width" to boundingBox.width() / imageWidth,
            "height" to boundingBox.height() / imageHeight,
            // Word-level elements are reserved for a future additive release.
            "elements" to null,
        )

    private fun releaseSession() {
        imageAnalysis?.clearAnalyzer()
        cameraProvider?.unbindAll()
        surfaceProducer?.release()

        isRecognizing = false
        camera = null
        imageAnalysis = null
        cameraProvider = null
        surfaceProducer = null
    }
}

/** Whether the center of this pixel rect falls inside [roi] (normalized [0, 1] top-left). */
private fun Rect.centerWithin(
    roi: RegionOfInterestMessage?,
    imageWidth: Double,
    imageHeight: Double,
): Boolean {
    if (roi == null) return true

    val centerX = exactCenterX() / imageWidth
    val centerY = exactCenterY() / imageHeight

    return centerX >= roi.left &&
        centerX <= roi.left + roi.width &&
        centerY >= roi.top &&
        centerY <= roi.top + roi.height
}

/** A [LifecycleOwner] driven manually so CameraX can bind without an Activity. */
private class SessionLifecycleOwner : LifecycleOwner {
    private val registry =
        LifecycleRegistry(this).apply { currentState = Lifecycle.State.INITIALIZED }

    override val lifecycle: Lifecycle get() = registry

    fun resume() {
        registry.currentState = Lifecycle.State.RESUMED
    }

    fun destroy() {
        registry.currentState = Lifecycle.State.DESTROYED
    }
}
