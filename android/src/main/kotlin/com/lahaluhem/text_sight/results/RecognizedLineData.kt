package com.lahaluhem.text_sight.results

import android.graphics.Rect

// Like iOS's, so the encoder never touches an ML Kit type. The box sits on the upright frame.
internal data class RecognizedLineData(val text: String, val confidence: Float, val box: Rect)
