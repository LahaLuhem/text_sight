package com.lahaluhem.text_sight

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

/**
 * Drives the Android camera-permission flow with built-in Kotlin + AndroidX only — no third-party
 * permission library — mapping the outcome onto [CameraPermissionStatusMessage].
 *
 * A runtime request needs a foreground [Activity], which the plugin feeds in via [activity] across
 * the `ActivityAware` lifecycle. As a [RequestPermissionsResultListener] this receives the system
 * result on the main thread and resolves the pending callback there — off the capture pipeline.
 *
 * `denied` vs `permanentlyDenied` is the standard heuristic: after a refusal, if the system would no
 * longer show a rationale the user chose "don't ask again" (or policy blocks it), so only the OS
 * settings can change it.
 */
internal class CameraPermissionRequester(
    private val appContext: Context,
) : RequestPermissionsResultListener {
    /** The current foreground Activity, maintained by the plugin across the `ActivityAware` lifecycle. */
    var activity: Activity? = null

    private var pending: ((Result<CameraPermissionStatusMessage>) -> Unit)? = null

    /** The current status without prompting — needs no Activity. */
    fun check(): CameraPermissionStatusMessage =
        if (isGranted()) CameraPermissionStatusMessage.GRANTED else CameraPermissionStatusMessage.DENIED

    /** Prompts when not yet granted, resolving [callback] with the resulting status. */
    fun request(callback: (Result<CameraPermissionStatusMessage>) -> Unit) {
        val currentActivity = activity
        when {
            isGranted() -> callback(Result.success(CameraPermissionStatusMessage.GRANTED))
            currentActivity == null ->
                callback(Result.failure(FlutterError("no-activity", NO_ACTIVITY_MESSAGE)))
            pending != null ->
                callback(Result.failure(FlutterError("already-requesting", ALREADY_REQUESTING_MESSAGE)))
            else -> {
                pending = callback
                ActivityCompat.requestPermissions(
                    currentActivity,
                    arrayOf(Manifest.permission.CAMERA),
                    REQUEST_CODE,
                )
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        val callback = pending
        if (requestCode != REQUEST_CODE || callback == null) return false

        pending = null
        val status = when {
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED ->
                CameraPermissionStatusMessage.GRANTED
            shouldShowRationale() -> CameraPermissionStatusMessage.DENIED
            else -> CameraPermissionStatusMessage.PERMANENTLY_DENIED
        }
        callback(Result.success(status))
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
