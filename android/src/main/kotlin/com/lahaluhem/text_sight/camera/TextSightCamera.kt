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
import com.lahaluhem.text_sight.recognition.ShownLines
import com.lahaluhem.text_sight.recognition.cropToNv21
import com.lahaluhem.text_sight.recognition.encodeFrame
import com.lahaluhem.text_sight.recognition.linesIn
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry
import java.io.ByteArrayInputStream
import java.io.File
import java.util.concurrent.Executors
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.withContext

/** ML Kit recognition for live frames and one-shot stills. The camera itself is [CameraSession]. */
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

    // Set on main, read on the analysis thread once per frame.
    @Volatile
    private var regionOfInterest: RegionOfInterestMessage? = null

    // No lock, since only the analysis thread touches it, one frame at a time.
    private val shownLines = ShownLines()

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
        // ML Kit's Latin recognizer has no level, language or text-height settings, so only the box applies.
        regionOfInterest = options.roi
    }

    fun setTorchEnabled(enabled: Boolean) = session.setTorchEnabled(enabled)

    // One-shot stills: no camera session, texture or permission.

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

        // ML Kit turned the still upright by its EXIF turn, so the boxes come back upright too.
        return encodeFrame(visionText.linesIn(region), region, quarterTurns = 0)
    }

    private fun decodeFailed(message: String): FlutterError = FlutterError("decode-failed", message)

    /** Called when the plugin detaches from the engine. */
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
        val roi = regionOfInterest
        val region = FrameRegion(mediaImage.width, mediaImage.height, rotationDegrees, roi)
        // ML Kit reads no region of its own, so a box means handing it a smaller image.
        val cutOut = region.crop?.let(mediaImage::cropToNv21)
        val input = if (cutOut == null) {
            InputImage.fromMediaImage(mediaImage, rotationDegrees)
        } else {
            InputImage.fromByteBuffer(
                cutOut.asBuffer(),
                cutOut.width,
                cutOut.height,
                rotationDegrees,
                InputImage.IMAGE_FORMAT_NV21,
            )
        }

        recognizer.process(input)
            .addOnSuccessListener(analysisExecutor) { visionText ->
                val lines = shownLines.linesIn(visionText, region, roi)
                val frame = encodeFrame(lines, region, rotationDegrees / 90)
                mainHandler.post { eventSink?.success(frame) }
            }
            .closeWhenSettled(imageProxy, cutOut)
    }
}
