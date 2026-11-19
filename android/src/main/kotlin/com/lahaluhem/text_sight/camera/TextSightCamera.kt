package com.lahaluhem.text_sight.camera

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognizer
import com.lahaluhem.text_sight.CaptureResolutionMessage
import com.lahaluhem.text_sight.PreviewMessage
import com.lahaluhem.text_sight.RegionOfInterestMessage
import com.lahaluhem.text_sight.SessionStateMessage
import com.lahaluhem.text_sight.TextSightOptionsMessage
import com.lahaluhem.text_sight.frames.closeWhenSettled
import com.lahaluhem.text_sight.region.FrameRegion
import com.lahaluhem.text_sight.region.ShownLines
import com.lahaluhem.text_sight.region.cropToNv21
import com.lahaluhem.text_sight.results.encodeFrame
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.ExecutorService

/** The live driver: ML Kit recognition for camera frames. The camera itself is [CameraSession]. */
internal class TextSightCamera(
    context: Context,
    textureRegistry: TextureRegistry,
    capturesChannel: EventChannel,
    private val recognizer: TextRecognizer,
    private val analysisExecutor: ExecutorService,
    onSessionState: (SessionStateMessage) -> Unit,
    onPreview: (PreviewMessage) -> Unit,
) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
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
        // ML Kit has no level, language or text-height settings, so only the box applies.
        regionOfInterest = options.roi
    }

    fun setTorchEnabled(enabled: Boolean) = session.setTorchEnabled(enabled)

    /** Called when the plugin detaches from the engine. */
    fun dispose() = session.dispose()

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
