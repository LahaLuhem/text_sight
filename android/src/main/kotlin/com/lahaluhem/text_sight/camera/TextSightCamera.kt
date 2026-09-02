package com.lahaluhem.text_sight.camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.lahaluhem.text_sight.FlutterError
import com.lahaluhem.text_sight.RegionOfInterestMessage
import com.lahaluhem.text_sight.TextSightOptionsMessage
import com.lahaluhem.text_sight.await
import com.lahaluhem.text_sight.recognition.encodeFrame
import com.lahaluhem.text_sight.recognition.toPixelRect
import com.lahaluhem.text_sight.recognition.uprightBy
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry
import java.io.ByteArrayInputStream
import java.io.File
import java.util.concurrent.Executors
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.withContext

/**
 * Recognition for one live session: the ML Kit recognizer, the per-frame encode, and the one-shot
 * still path. The CameraX side is [CameraSession].
 *
 * Recognition runs off the platform main thread on [analysisExecutor], and results marshal back to
 * main before reaching the [EventChannel] sink. Closing each [ImageProxy] releases backpressure
 * and the stream stalls without it, so it goes through [closeWhenSettled] and stays off main.
 */
internal class TextSightCamera(
    context: Context,
    textureRegistry: TextureRegistry,
    capturesChannel: EventChannel,
) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val analysisDispatcher = analysisExecutor.asCoroutineDispatcher()
    private val recognizer: TextRecognizer =
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    private val session = CameraSession(
        context,
        textureRegistry,
        analysisExecutor,
        ImageAnalysis.Analyzer(::analyze),
    )

    private var eventSink: EventChannel.EventSink? = null
    private var regionOfInterest: RegionOfInterestMessage? = null

    init {
        capturesChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    suspend fun initialize(options: TextSightOptionsMessage): Long {
        // Recognition level and languages have no ML Kit Latin equivalent (see the
        // TextSightOptions docs). Only the region-of-interest is honoured here.
        regionOfInterest = options.roi

        return session.open()
    }

    fun start() = session.startAnalysis()

    fun stop() = session.stopAnalysis()

    suspend fun disposeSession() = session.release()

    fun setRegionOfInterest(roi: RegionOfInterestMessage?) {
        regionOfInterest = roi
    }

    fun setTorchEnabled(enabled: Boolean) = session.setTorchEnabled(enabled)

    // Static one-shot recognition: no camera session, texture, or permission. Decode and
    // recognition both run on the analysis dispatcher.

    suspend fun recognizeImage(
        bytes: ByteArray,
        options: TextSightOptionsMessage,
    ): Map<String, Any?> = withContext(analysisDispatcher) {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw decodeFailed("The image bytes could not be decoded.")
        val rotation = runCatching {
            ExifInterface(ByteArrayInputStream(bytes)).rotationDegrees
        }.getOrDefault(0)

        recognizeStill(bitmap, rotation, options.roi)
    }

    suspend fun recognizePath(
        path: String,
        options: TextSightOptionsMessage,
    ): Map<String, Any?> = withContext(analysisDispatcher) {
        if (!File(path).exists()) {
            throw FlutterError("file-not-found", "No file exists at $path.")
        }

        val bitmap = BitmapFactory.decodeFile(path)
            ?: throw decodeFailed("The image at $path could not be decoded.")
        val rotation = runCatching { ExifInterface(path).rotationDegrees }.getOrDefault(0)

        recognizeStill(bitmap, rotation, options.roi)
    }

    /**
     * Recognizes [bitmap], rotated upright by [rotationDegrees] (its EXIF orientation), with a
     * transient pass over the shared recognizer. When [roi] is set, the upright bitmap is cropped
     * to it first so ML Kit reads only that region: a true crop, unlike the live path's
     * centre-containment filter. Returns the same per-frame map the live path emits, with quarterTurns
     * 0, since a still is already upright.
     */
    private suspend fun recognizeStill(
        bitmap: Bitmap,
        rotationDegrees: Int,
        roi: RegionOfInterestMessage?,
    ): Map<String, Any?> {
        val isQuarterTurned = rotationDegrees == 90 || rotationDegrees == 270
        val imageWidth = if (isQuarterTurned) bitmap.height else bitmap.width
        val imageHeight = if (isQuarterTurned) bitmap.width else bitmap.height

        // With an ROI, crop the upright bitmap so ML Kit reads only that region: a true crop that
        // isolates partial-line text (matching iOS Vision) and recognizes fewer pixels, unlike the
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

        val visionText = try {
            recognizer.process(input).await(analysisExecutor)
        } catch (error: Exception) {
            throw decodeFailed(error.message ?: "Recognition failed.")
        }

        return encodeFrame(
            visionText,
            imageWidth,
            imageHeight,
            0,
            offsetX = crop?.left ?: 0,
            offsetY = crop?.top ?: 0,
        )
    }

    private fun decodeFailed(message: String): FlutterError = FlutterError("decode-failed", message)

    /** Releases every per-engine resource. Called when the plugin detaches from the engine. */
    fun dispose() {
        session.dispose()
        recognizer.close()
        analysisExecutor.shutdown()
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
            .closeWhenSettled(imageProxy)
    }
}
