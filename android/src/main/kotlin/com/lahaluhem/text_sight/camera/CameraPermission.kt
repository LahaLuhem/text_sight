package com.lahaluhem.text_sight.camera

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.lahaluhem.text_sight.CameraPermissionStatusMessage
import com.lahaluhem.text_sight.FlutterError
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * After a refusal, no rationale means the user picked "don't ask again" (or a policy blocks it).
 * That's `permanentlyDenied`, since only the system settings can change it.
 */
internal class CameraPermission(
    private val appContext: Context,
) : RequestPermissionsResultListener {
    /** The foreground Activity a request needs. The plugin keeps it current. */
    var activity: Activity? = null

    private var pending: CancellableContinuation<CameraPermissionStatusMessage>? = null

    /** The current status without prompting. Needs no Activity. */
    fun check(): CameraPermissionStatusMessage =
        if (isGranted()) CameraPermissionStatusMessage.GRANTED else CameraPermissionStatusMessage.DENIED

    /** Prompts when not yet granted, then reports the resulting status. */
    suspend fun request(): CameraPermissionStatusMessage {
        if (isGranted()) return CameraPermissionStatusMessage.GRANTED

        val currentActivity = activity ?: throw FlutterError("no-activity", NO_ACTIVITY_MESSAGE)
        if (pending != null) throw FlutterError("already-requesting", ALREADY_REQUESTING_MESSAGE)

        return suspendCancellableCoroutine { continuation ->
            pending = continuation
            // A cancelled caller must not leave the slot occupied, or every later request reports
            // already-requesting.
            continuation.invokeOnCancellation { pending = null }

            ActivityCompat.requestPermissions(
                currentActivity,
                arrayOf(Manifest.permission.CAMERA),
                REQUEST_CODE,
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        val continuation = pending
        if (requestCode != REQUEST_CODE || continuation == null) return false

        pending = null
        val status = when {
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED ->
                CameraPermissionStatusMessage.GRANTED
            shouldShowRationale() -> CameraPermissionStatusMessage.DENIED
            else -> CameraPermissionStatusMessage.PERMANENTLY_DENIED
        }
        continuation.resume(status)
        return true
    }

    private fun isGranted(): Boolean =
        ContextCompat.checkSelfPermission(appContext, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED

    private fun shouldShowRationale(): Boolean {
        val currentActivity = activity ?: return false

        return ActivityCompat.shouldShowRequestPermissionRationale(currentActivity, Manifest.permission.CAMERA)
    }

    private companion object {
        const val REQUEST_CODE = 0xCA3
        const val NO_ACTIVITY_MESSAGE = "Camera permission can only be requested with a foreground Activity."
        const val ALREADY_REQUESTING_MESSAGE = "A camera-permission request is already in progress."
    }
}
