package com.lahaluhem.text_sight

import android.graphics.Rect
import android.media.Image
import com.lahaluhem.text_sight.recognition.cornerOffset
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Frames keep brightness per pixel and colour per 2x2 block, in one of three layouts. libyuv's copy
 * itself only runs on a device.
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class FrameCropTest(private val layout: Layout) {
    @Test
    fun `the copy starts on the crop's corner in every plane`() {
        val crop = Rect(10, 6, 30, 20)
        val (y, u, v) = layout.planes(width = 64, height = 48)

        assertEquals(luma(crop.left, crop.top), y.buffer.get(y.cornerOffset(crop, 1)))
        assertEquals(blue(crop.left / 2, crop.top / 2), u.buffer.get(u.cornerOffset(crop, 2)))
        assertEquals(red(crop.left / 2, crop.top / 2), v.buffer.get(v.cornerOffset(crop, 2)))
    }

    /** How a camera might hand the frame over, padded rows included. */
    enum class Layout {
        // Separate colour planes, as the emulator sends.
        PLANAR,

        // Colour interleaved in pairs, red first as most phones send, or blue first.
        NV21,
        NV12,
        ;

        fun planes(width: Int, height: Int): Array<Image.Plane> {
            val lumaStride = width + 16
            val luma = ByteBuffer.allocateDirect(lumaStride * height)
            for (row in 0 until height) {
                for (col in 0 until width) luma.put(row * lumaStride + col, luma(col, row))
            }

            return arrayOf(plane(luma, lumaStride, 1)) + colourPlanes(width / 2, height / 2)
        }

        private fun colourPlanes(width: Int, height: Int): List<Image.Plane> {
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
            val redFirst = this == NV21
            for (row in 0 until height) {
                for (col in 0 until width) {
                    pairs.put(row * stride + col * 2, if (redFirst) red(col, row) else blue(col, row))
                    pairs.put(row * stride + col * 2 + 1, if (redFirst) blue(col, row) else red(col, row))
                }
            }
            // Each colour plane starts on its own first sample, one byte apart.
            val firstPlane = plane(pairs.duplicate(), stride, 2)
            val secondPlane = plane(pairs.duplicate().apply { position(1) }.slice(), stride, 2)

            return if (redFirst) listOf(secondPlane, firstPlane) else listOf(firstPlane, secondPlane)
        }
    }

    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun layouts(): Collection<Array<Any>> = Layout.entries.map { arrayOf<Any>(it) }
    }
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
