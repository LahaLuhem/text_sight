package com.lahaluhem.text_sight.recognition

import android.graphics.Bitmap
import android.graphics.Matrix

/** This bitmap rotated clockwise [rotationDegrees]° to upright; the same instance when 0. */
internal fun Bitmap.uprightBy(rotationDegrees: Int): Bitmap {
    if (rotationDegrees == 0) return this

    val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }

    return Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
}
