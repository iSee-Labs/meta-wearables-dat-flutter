// Annex-B HEVC helpers (pure, unit-testable).

package com.iseelabs.meta_wearables_dat_flutter

object HevcNal {
    const val VPS = 32
    const val SPS = 33
    const val PPS = 34

    /** NAL unit types of every NAL in an Annex-B buffer. */
    fun nalTypes(data: ByteArray, length: Int = data.size): List<Int> {
        val types = mutableListOf<Int>()
        var i = 0
        while (i + 3 <= length) {
            val startCode = when {
                i + 4 <= length && data[i] == 0.toByte() && data[i + 1] == 0.toByte() &&
                    data[i + 2] == 0.toByte() && data[i + 3] == 1.toByte() -> 4
                data[i] == 0.toByte() && data[i + 1] == 0.toByte() && data[i + 2] == 1.toByte() -> 3
                else -> 0
            }
            if (startCode == 0) {
                i++
                continue
            }
            val header = i + startCode
            if (header < length) types += (data[header].toInt() shr 1) and 0x3F
            i = header + 1
        }
        return types
    }

    /** IRAP pictures (BLA, IDR, CRA: NAL types 16..23) are independently decodable. */
    fun isKeyframe(types: List<Int>): Boolean = types.any { it in 16..23 }

    fun hasParameterSets(types: List<Int>): Boolean =
        types.contains(VPS) && types.contains(SPS) && types.contains(PPS)

    fun isParameterSetsOnly(types: List<Int>): Boolean =
        types.isNotEmpty() && types.all { it == VPS || it == SPS || it == PPS }
}
