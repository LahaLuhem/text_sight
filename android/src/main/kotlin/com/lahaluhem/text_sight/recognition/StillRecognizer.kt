package com.lahaluhem.text_sight.recognition

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognizer
import com.lahaluhem.text_sight.FlutterError
import com.lahaluhem.text_sight.RegionOfInterestMessage
import com.lahaluhem.text_sight.TextSightOptionsMessage
import com.lahaluhem.text_sight.await
import com.lahaluhem.text_sight.region.FrameRegion
import com.lahaluhem.text_sight.results.encodeFrame
import java.io.ByteArrayInputStream
import java.io.File
import java.util.concurrent.ExecutorService
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.withContext

/** The one-shot driver: reads a still, with no camera session, texture or permission. */
internal class StillRecognizer(
    private val recognizer: TextRecognizer,
    // The live driver's thread too, so a still waits its turn behind camera frames.
    private val analysisExecutor: ExecutorService,
) {
    private val analysisDispatcher = analysisExecutor.asCoroutineDispatcher()

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
}
