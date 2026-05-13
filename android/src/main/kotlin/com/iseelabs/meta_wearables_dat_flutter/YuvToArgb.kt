// CPU-side I420 → ARGB conversion.
//
// Used only by [MetaSessionManager]. Single-threaded; perf is fine for
// 720p@30fps on every Android device that meets minSdk 31. Uses BT.601
// limited-range coefficients which match what Meta's helpers in the
// official sample app emit.
//
// In Meta DAT SDK 0.6.x, `VideoFrame` exposes the I420 payload as one
// `ByteBuffer` (Y plane, then U plane, then V plane), with no row-stride
// padding. The convert(...) signature matches that shape so the manager
// can pass `frame.buffer` straight through.

package com.iseelabs.meta_wearables_dat_flutter

import android.graphics.Bitmap
import java.nio.ByteBuffer

internal object YuvToArgb {
    /**
     * Converts an I420 [yuvData] buffer to ARGB pixels written into [output].
     *
     * Layout: `Y (w*h) | U (w/2 * h/2) | V (w/2 * h/2)`, packed, no padding.
     * Returns silently if [yuvData] is too small for the declared dimensions.
     */
    fun convert(
        yuvData: ByteBuffer,
        width: Int,
        height: Int,
        output: Bitmap,
    ) {
        if (width <= 0 || height <= 0) return
        if (width % 2 != 0 || height % 2 != 0) return

        val frameSize = width * height
        val expected = frameSize + (frameSize shr 1)
        if (yuvData.remaining() < expected) return

        val src = yuvData.duplicate().apply { position(yuvData.position()) }
        val bytes = ByteArray(expected)
        src.get(bytes, 0, expected)

        val uOffset = frameSize
        val vOffset = uOffset + (frameSize shr 2)
        val halfWidth = width shr 1
        val pixels = IntArray(frameSize)

        var i = 0
        for (row in 0 until height) {
            val uvRowOffset = (row shr 1) * halfWidth
            for (col in 0 until width) {
                val uvIndex = uvRowOffset + (col shr 1)
                val y = (bytes[i].toInt() and 0xff) - 16
                val u = (bytes[uOffset + uvIndex].toInt() and 0xff) - 128
                val v = (bytes[vOffset + uvIndex].toInt() and 0xff) - 128

                val yScaled = 1192 * y
                var r = (yScaled + 1634 * v) shr 10
                var g = (yScaled - 833 * v - 400 * u) shr 10
                var b = (yScaled + 2066 * u) shr 10

                if (r < 0) r = 0 else if (r > 255) r = 255
                if (g < 0) g = 0 else if (g > 255) g = 255
                if (b < 0) b = 0 else if (b > 255) b = 255

                pixels[i++] = (0xff shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
        output.setPixels(pixels, 0, width, 0, 0, width, height)
    }
}
