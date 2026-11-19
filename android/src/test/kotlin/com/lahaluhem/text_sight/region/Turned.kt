package com.lahaluhem.text_sight.region

import android.graphics.Rect

/** This rect in a [width] by [height] image, once the image is turned [degrees] clockwise. */
internal fun Rect.turned(degrees: Int, width: Int, height: Int): Rect = when (degrees) {
    90 -> Rect(height - bottom, left, height - top, right)
    180 -> Rect(width - right, height - bottom, width - left, height - top)
    270 -> Rect(top, width - right, bottom, width - left)
    else -> Rect(this)
}
