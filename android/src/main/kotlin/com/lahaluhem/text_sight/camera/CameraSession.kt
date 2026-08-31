package com.lahaluhem.text_sight.camera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.Surface
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraState
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.lahaluhem.text_sight.FlutterError
import io.flutter.view.TextureRegistry
import java.util.concurrent.Executor

/**
 * The CameraX half of a live session: provider, use-case binding, preview texture, torch.
 *
 * **Main-confined:** CameraX's `LiveData` observers and [SessionLifecycleOwner]'s registry both
 * reject other threads, so [mainExecutor] has to be one. Recognition lives in [TextSightCamera];
 * this class only knows the [analyzer] and the executor to run it on.
 */
internal class CameraSession(
    private val context: Context,
    private val textureRegistry: TextureRegistry,
    private val analysisExecutor: Executor,
    private val analyzer: ImageAnalysis.Analyzer,
    private val mainExecutor: Executor = ContextCompat.getMainExecutor(context),
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val lifecycleOwner = SessionLifecycleOwner()

    private var surfaceProducer: TextureRegistry.SurfaceProducer? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var camera: Camera? = null
    private var isRecognizing = false
    private var torchEnabled = false

    /**
     * Keeps [ImageAnalysis]'s target rotation in-step with the live display rotation, so the
     * reported quarter-turns ([androidx.camera.core.ImageProxy] rotationDegrees / 90) track the
     * device in every orientation. The headless session has no Activity to do this automatically,
     * so without it the rotation hint is stuck at the bind-time default, and only portrait looks
     * right.
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

    /** Opens the camera and returns the preview texture id. */
    fun open(callback: (Result<Long>) -> Unit) {
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
        }, mainExecutor)
    }

    fun startAnalysis() {
        isRecognizing = true
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
    fun release() {
        imageAnalysis?.clearAnalyzer()
        camera?.cameraInfo?.cameraState?.removeObservers(lifecycleOwner)
        cameraProvider?.unbindAll()
        surfaceProducer?.release()

        isRecognizing = false
        camera = null
        imageAnalysis = null
        cameraProvider = null
        surfaceProducer = null
    }

    /** Releases everything, including the lifecycle owner. No [open] after this. */
    fun dispose() {
        displayManager.unregisterDisplayListener(displayListener)
        release()
        lifecycleOwner.destroy()
    }

    /** The live display rotation as a `Surface.ROTATION_*`, driving [ImageAnalysis]'s target. */
    private fun currentRotation(): Int =
        displayManager.getDisplay(Display.DEFAULT_DISPLAY)?.rotation ?: Surface.ROTATION_0

    private fun bindUseCases() {
        val provider = cameraProvider ?: return
        val producer = surfaceProducer ?: return

        val preview = Preview.Builder().build().apply {
            setSurfaceProvider(mainExecutor) { request ->
                producer.setSize(request.resolution.width, request.resolution.height)
                request.provideSurface(producer.surface, mainExecutor) { _ ->
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
        val bound = provider.bindToLifecycle(
            lifecycleOwner,
            CameraSelector.DEFAULT_BACK_CAMERA,
            preview,
            analysis,
        )
        camera = bound

        // The torch resets whenever the camera closes (backgrounding included), so re-assert the
        // stored intent every time this camera reaches OPEN.
        bound.cameraInfo.cameraState.removeObservers(lifecycleOwner)
        bound.cameraInfo.cameraState.observe(lifecycleOwner) { state ->
            if (state.type == CameraState.Type.OPEN && torchEnabled) {
                bound.cameraControl.enableTorch(true)
            }
        }

        if (isRecognizing) {
            analysis.setAnalyzer(analysisExecutor, analyzer)
        }
    }
}
