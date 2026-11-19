package com.lahaluhem.text_sight.region

import android.graphics.Rect
import android.media.Image
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Frames keep brightness per pixel and colour per 2x2 block, the colour in separate planes or
 * interleaved in pairs. libyuv's copy itself only runs on a device.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class FrameCropTest {
    private val crop = Rect(10, 6, 30, 20)

    @Test
    fun `the copy starts on the crop's corner in the brightness plane`() {
        val y = brightnessPlane(width = 64, height = 48)

        assertEquals(luma(crop.left, crop.top), y.buffer.get(y.cornerOffset(crop, 1)))
    }

    @Test
    fun `the copy starts on the crop's corner in each colour plane, separate or interleaved`() {
        for (layout in Layout.entries) {
            val (u, v) = layout.colourPlanes(width = 32, height = 24)

            assertEquals("$layout", blue(crop.left / 2, crop.top / 2), u.buffer.get(u.cornerOffset(crop, 2)))
            assertEquals("$layout", red(crop.left / 2, crop.top / 2), v.buffer.get(v.cornerOffset(crop, 2)))
        }
    }

    /** How a camera might hand the colour over, padded rows included. */
    private enum class Layout {
        // Separate planes, as the emulator sends.
        PLANAR,

        // Interleaved in pairs, red first, as most phones send. Blue first has the same strides.
        NV21,
        ;

        fun colourPlanes(width: Int, height: Int): List<Image.Plane> {
            if (this == PLANAR) {
                val stride = width + 8
                val blue = ByteBuffer.allocateDirect(stride * height)
                val red = ByteBuffer.allocateDirect(stride * height)
                for (row in 0 until height) {
                    for (col in 0 until width) {
                        blue.put(row * stride + col, blue(col, row))
                        red.put(row * stride + col, red(col, row))
                    }
                }

                return listOf(plane(blue, stride, 1), plane(red, stride, 1))
            }

            val stride = width * 2 + 16
            val pairs = ByteBuffer.allocateDirect(stride * height)
            for (row in 0 until height) {
                for (col in 0 until width) {
                    pairs.put(row * stride + col * 2, red(col, row))
                    pairs.put(row * stride + col * 2 + 1, blue(col, row))
                }
            }
            // Each colour plane starts on its own first sample, one byte apart.
            val bluePlane = plane(pairs.duplicate().apply { position(1) }.slice(), stride, 2)

            return listOf(bluePlane, plane(pairs.duplicate(), stride, 2))
        }
    }
}

private fun brightnessPlane(width: Int, height: Int): Image.Plane {
    val stride = width + 16
    val luma = ByteBuffer.allocateDirect(stride * height)
    for (row in 0 until height) {
        for (col in 0 until width) luma.put(row * stride + col, luma(col, row))
    }

    return plane(luma, stride, 1)
}

// Sample values that differ from their neighbours', so a copy starting off by a step reads wrong.
private fun luma(x: Int, y: Int) = (x + 7 * y).toByte()

private fun blue(x: Int, y: Int) = (3 * x + 11 * y + 1).toByte()

private fun red(x: Int, y: Int) = (5 * x + 13 * y + 2).toByte()

private fun plane(buffer: ByteBuffer, rowStride: Int, pixelStride: Int): Image.Plane {
    val plane = mock<Image.Plane>()
    whenever(plane.buffer).thenReturn(buffer)
    whenever(plane.rowStride).thenReturn(rowStride)
    whenever(plane.pixelStride).thenReturn(pixelStride)

    return plane
}
