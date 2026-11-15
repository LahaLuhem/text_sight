package com.lahaluhem.text_sight.recognition

import android.graphics.Rect
import android.media.Image
import io.github.crow_misia.libyuv.I420Buffer
import io.github.crow_misia.libyuv.Nv21Buffer
import io.github.crow_misia.libyuv.RowStride
import io.github.crow_misia.libyuv.Yuv

/** [crop] of this camera frame as NV21 for ML Kit, whatever its colour layout. Close it after. */
internal fun Image.cropToNv21(crop: Rect): Nv21Buffer {
    val (y, u, v) = planes
    val i420 = I420Buffer.allocate(crop.width(), crop.height())
    try {
        Yuv.rotateAndroid420ToI420Rotate(
            srcY = y.buffer, srcStrideY = RowStride(y.rowStride), srcOffsetY = y.cornerOffset(crop, 1),
            srcU = u.buffer, srcStrideU = RowStride(u.rowStride), srcOffsetU = u.cornerOffset(crop, 2),
            srcV = v.buffer, srcStrideV = RowStride(v.rowStride), srcOffsetV = v.cornerOffset(crop, 2),
            srcPixelStrideUV = u.pixelStride,
            dstY = i420.planeY.buffer, dstStrideY = i420.planeY.rowStride, dstOffsetY = 0,
            dstU = i420.planeU.buffer, dstStrideU = i420.planeU.rowStride, dstOffsetU = 0,
            dstV = i420.planeV.buffer, dstStrideV = i420.planeV.rowStride, dstOffsetV = 0,
            width = crop.width(),
            height = crop.height(),
            rotateMode = 0,
        )
        // Native memory, since ML Kit reads allocateDirect's backing array from 0, a few bytes early.
        return Nv21Buffer.allocate(crop.width(), crop.height()).also { i420.convertTo(it) }
    } finally {
        i420.close()
    }
}

/** Where [crop]'s top-left sample sits in this plane, which keeps one sample per [step] pixels. */
internal fun Image.Plane.cornerOffset(crop: Rect, step: Int): Int =
    crop.top / step * rowStride + crop.left / step * pixelStride
