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
import com.lahaluhem.text_sight.CaptureResolutionMessage
import com.lahaluhem.text_sight.FlutterError
import com.lahaluhem.text_sight.PreviewMessage
import com.lahaluhem.text_sight.RegionOfInterestMessage
import com.lahaluhem.text_sight.SessionStateMessage
import com.lahaluhem.text_sight.TextSightOptionsMessage
import com.lahaluhem.text_sight.await
import com.lahaluhem.text_sight.recognition.FrameRegion
import com.lahaluhem.text_sight.recognition.encodeFrame
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
    onSessionState: (SessionStateMessage) -> Unit,
    onPreview: (PreviewMessage) -> Unit,
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
        onSessionState = onSessionState,
        onPreview = onPreview,
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

    suspend fun initialize(
        options: TextSightOptionsMessage,
        resolution: CaptureResolutionMessage,
    ): Long {
        setOptions(options)

        return session.open(resolution)
    }

    fun start() = session.startAnalysis()

    fun pauseRecognition() = session.stopAnalysis()

    suspend fun disposeSession() = session.release()

    fun setOptions(options: TextSightOptionsMessage) {
        // Level, language correction, languages and the text-height floor have no ML Kit Latin
        // equivalent, so the region-of-interest is the only one that lands anywhere.
        regionOfInterest = options.roi
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
     * Recognizes [bitmap] with a transient pass over the shared recognizer, which turns it upright
     * by [rotationDegrees] (its EXIF orientation). Emits the same per-frame map the live path does,
     * with quarterTurns 0 since the boxes come back upright.
     */
    private suspend fun recognizeStill(
        bitmap: Bitmap,
        rotationDegrees: Int,
        roi: RegionOfInterestMessage?,
    ): Map<String, Any?> {
        val region = FrameRegion(bitmap.width, bitmap.height, rotationDegrees, roi)
        val pixels = region.crop?.let { crop ->
            Bitmap.createBitmap(bitmap, crop.left, crop.top, crop.width(), crop.height())
        } ?: bitmap

        val visionText = try {
            recognizer.process(InputImage.fromBitmap(pixels, rotationDegrees)).await(analysisExecutor)
        } catch (error: Exception) {
            throw decodeFailed(error.message ?: "Recognition failed.")
        }

        return encodeFrame(visionText, region, quarterTurns = 0)
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
        val region = FrameRegion(mediaImage.width, mediaImage.height, rotationDegrees)

        recognizer.process(InputImage.fromMediaImage(mediaImage, rotationDegrees))
            .addOnSuccessListener(analysisExecutor) { visionText ->
                val frame = encodeFrame(visionText, region, rotationDegrees / 90, regionOfInterest)
                mainHandler.post { eventSink?.success(frame) }
            }
            .closeWhenSettled(imageProxy)
    }
}
