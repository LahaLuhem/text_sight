package com.LahaLuhem.text_sight

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
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
import androidx.exifinterface.media.ExifInterface
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
import java.io.ByteArrayInputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.roundToInt

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

    // Static one-shot recognition — no camera session, texture, or permission. Decoding and
    // recognition run on the analysis executor; the result is marshalled back to the main thread.

    fun recognizeImage(
        bytes: ByteArray,
        options: TextSightOptionsMessage,
        callback: (Result<Map<String, Any?>>) -> Unit,
    ) {
        analysisExecutor.execute {
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            if (bitmap == null) {
                mainHandler.post { callback(decodeFailed("The image bytes could not be decoded.")) }
                return@execute
            }

            val rotation = runCatching {
                ExifInterface(ByteArrayInputStream(bytes)).rotationDegrees
            }.getOrDefault(0)
            recognizeStill(bitmap, rotation, options.roi, callback)
        }
    }

    fun recognizePath(
        path: String,
        options: TextSightOptionsMessage,
        callback: (Result<Map<String, Any?>>) -> Unit,
    ) {
        analysisExecutor.execute {
            if (!File(path).exists()) {
                mainHandler.post {
                    callback(Result.failure(FlutterError("file-not-found", "No file exists at $path.")))
                }
                return@execute
            }

            val bitmap = BitmapFactory.decodeFile(path)
            if (bitmap == null) {
                mainHandler.post { callback(decodeFailed("The image at $path could not be decoded.")) }
                return@execute
            }

            val rotation = runCatching { ExifInterface(path).rotationDegrees }.getOrDefault(0)
            recognizeStill(bitmap, rotation, options.roi, callback)
        }
    }

    /**
     * Recognizes [bitmap], rotated upright by [rotationDegrees] (its EXIF orientation), with a
     * transient pass over the shared recognizer. When [roi] is set, the upright bitmap is cropped
     * to it first so ML Kit reads only that region — a true crop, unlike the live path's
     * center-containment filter. Completes on the main thread with the same per-frame map the live
     * path emits — quarterTurns 0, since a still is already upright.
     */
    private fun recognizeStill(
        bitmap: Bitmap,
        rotationDegrees: Int,
        roi: RegionOfInterestMessage?,
        callback: (Result<Map<String, Any?>>) -> Unit,
    ) {
        val isQuarterTurned = rotationDegrees == 90 || rotationDegrees == 270
        val imageWidth = if (isQuarterTurned) bitmap.height else bitmap.width
        val imageHeight = if (isQuarterTurned) bitmap.width else bitmap.height

        // With an ROI, crop the upright bitmap so ML Kit reads only that region: a true crop that
        // isolates partial-line text (matching iOS Vision) and recognizes fewer pixels — unlike the
        // live path, where cropping every frame would cost too much. The crop's origin offsets the
        // recognized boxes back into full-image coordinates.
        val crop = roi?.toPixelRect(imageWidth, imageHeight)
        val input = if (crop == null) {
            InputImage.fromBitmap(bitmap, rotationDegrees)
        } else {
            val upright = bitmap.uprightBy(rotationDegrees)
            InputImage.fromBitmap(
                Bitmap.createBitmap(upright, crop.left, crop.top, crop.width(), crop.height()),
                0,
            )
        }

        recognizer.process(input)
            .addOnSuccessListener(analysisExecutor) { visionText ->
                val frame = encodeFrame(
                    visionText,
                    imageWidth,
                    imageHeight,
                    0,
                    offsetX = crop?.left ?: 0,
                    offsetY = crop?.top ?: 0,
                )
                mainHandler.post { callback(Result.success(frame)) }
            }
            .addOnFailureListener(analysisExecutor) { error ->
                mainHandler.post { callback(decodeFailed(error.message ?: "Recognition failed.")) }
            }
    }

    private fun decodeFailed(message: String): Result<Map<String, Any?>> =
        Result.failure(FlutterError("decode-failed", message))

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
                val frame =
                    encodeFrame(visionText, imageWidth, imageHeight, rotationDegrees / 90, regionOfInterest)
                mainHandler.post { eventSink?.success(frame) }
            }
            .addOnCompleteListener { imageProxy.close() }
    }

    private fun encodeFrame(
        visionText: Text,
        imageWidth: Int,
        imageHeight: Int,
        quarterTurns: Int,
        roi: RegionOfInterestMessage? = null,
        offsetX: Int = 0,
        offsetY: Int = 0,
    ): Map<String, Any?> {
        val width = imageWidth.toDouble()
        val height = imageHeight.toDouble()

        val lines = visionText.textBlocks
            .flatMap { block -> block.lines }
            .mapNotNull { line ->
                val boundingBox = line.boundingBox ?: return@mapNotNull null
                if (!boundingBox.centerWithin(roi, width, height)) {
                    return@mapNotNull null
                }

                encodeLine(line, boundingBox, width, height, offsetX, offsetY)
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
        offsetX: Int,
        offsetY: Int,
    ): Map<String, Any?> =
        mapOf(
            "text" to line.text,
            // ML Kit v2 supplies a per-line confidence (null for a line that lacks one);
            // forwarded as-is per the RecognizedLine.confidence contract.
            "confidence" to line.confidence?.toDouble(),
            // The crop origin (0 on the live path) maps boxes back into full-image coordinates.
            "left" to (boundingBox.left + offsetX) / imageWidth,
            "top" to (boundingBox.top + offsetY) / imageHeight,
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

/** This bitmap rotated clockwise [rotationDegrees]° to upright; the same instance when 0. */
private fun Bitmap.uprightBy(rotationDegrees: Int): Bitmap {
    if (rotationDegrees == 0) return this

    val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }

    return Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
}

/** [roi] (normalized [0, 1] top-left) as a pixel [Rect] clamped inside the image, never empty. */
private fun RegionOfInterestMessage.toPixelRect(imageWidth: Int, imageHeight: Int): Rect {
    val pixelLeft = (left * imageWidth).roundToInt().coerceIn(0, imageWidth - 1)
    val pixelTop = (top * imageHeight).roundToInt().coerceIn(0, imageHeight - 1)
    val pixelRight = ((left + width) * imageWidth).roundToInt().coerceIn(pixelLeft + 1, imageWidth)
    val pixelBottom = ((top + height) * imageHeight).roundToInt().coerceIn(pixelTop + 1, imageHeight)

    return Rect(pixelLeft, pixelTop, pixelRight, pixelBottom)
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
