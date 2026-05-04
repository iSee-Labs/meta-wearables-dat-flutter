// CPU-side I420 -> ARGB conversion.
//
// Used only by [MetaSessionManager]. Single-threaded; perf is fine for
// 720p@30fps on every Android device that meets minSdk 31. Uses BT.601
// limited-range coefficients which match what Meta's helpers in the
// official sample app emit. GPU-accelerated rendering will replace this in
// v0.2.

package com.iseelabs.meta_wearables_dat_flutter

import android.graphics.Bitmap
import java.nio.ByteBuffer

internal object YuvToArgb {
    fun convert(
        yPlane: ByteBuffer,
        uPlane: ByteBuffer,
        vPlane: ByteBuffer,
        yStride: Int,
        uStride: Int,
        vStride: Int,
        width: Int,
        height: Int,
        output: Bitmap,
    ) {
        val pixels = IntArray(width * height)
        val yArr = byteArrayFor(yPlane)
        val uArr = byteArrayFor(uPlane)
        val vArr = byteArrayFor(vPlane)

        var i = 0
        for (row in 0 until height) {
            val yRow = row * yStride
            val uvRow = (row shr 1) * uStride
            val vUvRow = (row shr 1) * vStride
            for (col in 0 until width) {
                val y = (yArr[yRow + col].toInt() and 0xff) - 16
                val u = (uArr[uvRow + (col shr 1)].toInt() and 0xff) - 128
                val v = (vArr[vUvRow + (col shr 1)].toInt() and 0xff) - 128

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

    private fun byteArrayFor(buffer: ByteBuffer): ByteArray {
        val rewound = buffer.duplicate()
        rewound.position(0)
        val bytes = ByteArray(rewound.remaining())
        rewound.get(bytes)
        return bytes
    }
}
