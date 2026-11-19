package com.lahaluhem.text_sight.camera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.util.Size
import android.view.Display
import android.view.Surface
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraState
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.lahaluhem.text_sight.CaptureResolutionMessage
import com.lahaluhem.text_sight.FlutterError
import com.lahaluhem.text_sight.PreviewMessage
import com.lahaluhem.text_sight.SessionFailedMessage
import com.lahaluhem.text_sight.SessionIdleMessage
import com.lahaluhem.text_sight.SessionStateMessage
import com.lahaluhem.text_sight.await
import com.lahaluhem.text_sight.frames.analysisResolutionSelector
import com.lahaluhem.text_sight.frames.previewGeometry
import com.lahaluhem.text_sight.frames.previewResolutionSelector
import io.flutter.view.TextureRegistry
import java.util.concurrent.Executor
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * The CameraX half of a live session: binding, preview texture, torch.
 *
 * Main thread only, since CameraX's `LiveData` observers and [SessionLifecycleOwner]'s registry
 * both reject other threads. The suspending calls hop there through [mainDispatcher]. The others
 * come from Flutter's callbacks, which already run on main.
 */
internal class CameraSession(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val analysisExecutor: Executor,
    private val analyzer: ImageAnalysis.Analyzer,
    private val mainExecutor: Executor = ContextCompat.getMainExecutor(context),
    private val mainDispatcher: CoroutineDispatcher = Dispatchers.Main,
    private val onSessionState: (SessionStateMessage) -> Unit = {},
    private val onPreview: (PreviewMessage) -> Unit = {},
) {
    // No hop here, since [mainDispatcher] already puts the work back on main.
    private val directExecutor = Executor(Runnable::run)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val lifecycleOwner = SessionLifecycleOwner(onStatusChanged = ::onOwnerStatus)

    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var camera: Camera? = null
    private var previewResolution: Size? = null
    private var isRecognizing = false

    // Kept because [bindUseCases] also runs from the surface callback, long after open() returned.
    private var captureResolution = CaptureResolutionMessage.MEDIUM
    private var torchEnabled = false

    /**
     * Keeps [ImageAnalysis]'s target rotation in step with the display. There's no Activity to do
     * it, so the hint would stay at its bind-time value and only portrait would come out right.
     */
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = Unit

        override fun onDisplayRemoved(displayId: Int) = Unit

        override fun onDisplayChanged(displayId: Int) {
            if (displayId == Display.DEFAULT_DISPLAY) {
                imageAnalysis?.targetRotation = currentRotation()
                reportPreview()
            }
        }
    }

    private val surfaceCallback = object : TextureRegistry.SurfaceProducer.Callback {
        override fun onSurfaceAvailable() {
            bindUseCases()
        }

        override fun onSurfaceCleanup() {
            cameraProvider?.unbindAll()
        }
    }

    init {
        displayManager.registerDisplayListener(displayListener, mainHandler)
    }

    /** Opens the camera and returns the preview texture id. Reopening an open session is fine. */
    suspend fun open(resolution: CaptureResolutionMessage): Long = withContext(mainDispatcher) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw FlutterError("permission-denied", "Camera permission has not been granted.")
        }

        captureResolution = resolution

        // Hot restart gets here with the camera still up: Dart lost the texture id, we didn't.
        // Nothing else ever releases a producer, so skipping this strands the old one for good.
        releaseNow()

        val producer = textureRegistry.createSurfaceProducer()
        producer.setCallback(surfaceCallback)
        surfaceProducer = producer

        try {
            cameraProvider = ProcessCameraProvider.getInstance(context).await(directExecutor)
            lifecycleOwner.resume()
            bindUseCases()

            producer.id()
        } catch (error: Exception) {
            // We already claimed a producer above, so hand it back rather than strand it.
            releaseNow()
            throw FlutterError("initialization-failed", error.message)
        }
    }

    fun startAnalysis() {
        isRecognizing = true
        // A failure parked the owner, and CameraX reopens nothing on its own, so start() rebinds.
        if (lifecycleOwner.status == SessionLifecycleOwner.Status.PARKED && cameraProvider != null) {
            lifecycleOwner.resume()
            bindUseCases()
        }
        imageAnalysis?.setAnalyzer(analysisExecutor, analyzer)
    }

    fun stopAnalysis() {
        isRecognizing = false
        imageAnalysis?.clearAnalyzer()
    }

    fun setTorchEnabled(enabled: Boolean) {
        torchEnabled = enabled
        camera?.cameraControl?.enableTorch(enabled)
    }

    /** Tears down the session but keeps the owner alive for a later [open]. */
    suspend fun release() = withContext(mainDispatcher) { releaseNow() }

    /** Releases everything, including the lifecycle owner. No [open] after this. Main thread only. */
    fun dispose() {
        displayManager.unregisterDisplayListener(displayListener)
        releaseNow()
        lifecycleOwner.destroy()
    }

    private fun releaseNow() {
        val hadCamera = camera != null
        imageAnalysis?.clearAnalyzer()
        // Observers go before the unbind, so the closing camera reports nothing on the way out.
        camera?.cameraInfo?.cameraState?.removeObservers(lifecycleOwner)
        cameraProvider?.unbindAll()
        surfaceProducer?.release()
        lifecycleOwner.park()

        isRecognizing = false
        camera = null
        previewResolution = null
        imageAnalysis = null
        cameraProvider = null
        surfaceProducer = null
        if (hadCamera) onSessionState(SessionIdleMessage())
    }

    private fun onOwnerStatus(status: SessionLifecycleOwner.Status) {
        // Only the pause comes from here: CameraX's camera state rides a LiveData observed through
        // this owner, which goes quiet while capped. Coming back, the camera's own OPEN says active.
        deriveSessionState(status, camera = null)?.let(onSessionState)
    }

    private fun onCameraState(state: CameraState) {
        val message = deriveSessionState(lifecycleOwner.status, state) ?: return
        // A critical error parks the session. CameraX will not reopen it, start() is the way back.
        if (message is SessionFailedMessage) lifecycleOwner.park()
        onSessionState(message)
    }

    /** The live display rotation as a `Surface.ROTATION_*`, driving [ImageAnalysis]'s target. */
    private fun currentRotation(): Int =
        displayManager.getDisplay(Display.DEFAULT_DISPLAY)?.rotation ?: Surface.ROTATION_0

    /** Tells Dart how to show the preview, once its size, camera and producer are known. */
    private fun reportPreview() {
        val producer = surfaceProducer
        val resolution = previewResolution
        val sensorDegrees = camera?.cameraInfo?.sensorRotationDegrees
        if (producer == null || resolution == null || sensorDegrees == null) return

        onPreview(
            previewGeometry(
                textureId = producer.id(),
                bufferWidth = resolution.width,
                bufferHeight = resolution.height,
                sensorDegrees = sensorDegrees,
                displayRotation = currentRotation(),
                surfaceRotates = producer.handlesCropAndRotation(),
            ),
        )
    }

    private fun bindUseCases() {
        val provider = cameraProvider ?: return
        val producer = surfaceProducer ?: return

        val preview = Preview.Builder()
            .setResolutionSelector(previewResolutionSelector())
            .build()
            .apply {
                setSurfaceProvider(mainExecutor) { request ->
                    producer.setSize(request.resolution.width, request.resolution.height)
                    previewResolution = request.resolution
                    reportPreview()
                    request.provideSurface(producer.surface, mainExecutor) { _ ->
                        // Flutter owns the Surface via the SurfaceProducer, so nothing to release.
                    }
                }
            }

        val analysis = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setTargetRotation(currentRotation())
            .setResolutionSelector(analysisResolutionSelector(captureResolution))
            .build()
        imageAnalysis = analysis

        provider.unbindAll()
        val bound = provider.bindToLifecycle(
            lifecycleOwner,
            CameraSelector.DEFAULT_BACK_CAMERA,
            preview,
            analysis,
        )
        camera = bound

        // The torch goes off whenever the camera closes, backgrounding included, so turn it back on
        // at every OPEN.
        bound.cameraInfo.cameraState.removeObservers(lifecycleOwner)
        bound.cameraInfo.cameraState.observe(lifecycleOwner) { state ->
            if (state.type == CameraState.Type.OPEN && torchEnabled) {
                bound.cameraControl.enableTorch(true)
            }
            onCameraState(state)
        }

        if (isRecognizing) {
            analysis.setAnalyzer(analysisExecutor, analyzer)
        }
    }
}
