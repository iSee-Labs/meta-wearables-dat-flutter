// Parses and validates `startStreamSession` arguments. Pure Kotlin so it is
// unit-testable without the SDK runtime.

package com.iseelabs.meta_wearables_dat_flutter

data class StreamSessionArgs(
    val deviceUuid: String?,
    val frameRate: Int,
    /** `low`, `medium` or `high`. */
    val quality: String,
    /** `raw` or `hvc1`. */
    val videoCodec: String,
    val deviceKinds: Set<String>?,
    /** 16000, 44100 or 48000 when in-stream audio is requested. */
    val audioSampleRate: Int?,
    val audioChannels: Int,
) {
    val compressVideo: Boolean get() = videoCodec == "hvc1"

    companion object {
        val allowedFrameRates = setOf(2, 7, 15, 24, 30)
        private val allowedQualities = setOf("low", "medium", "high")
        private val allowedCodecs = setOf("raw", "hvc1")
        private val allowedSampleRates = setOf(16000, 44100, 48000)

        fun parse(arguments: Any?): StreamSessionArgs {
            val args = arguments as? Map<*, *> ?: emptyMap<String, Any?>()
            val fps = (args["fps"] as? Number)?.toInt() ?: 24
            if (fps !in allowedFrameRates) {
                throw WireError.invalidArgument("fps must be one of 2, 7, 15, 24, 30 (got $fps).")
            }
            val quality = args["quality"] as? String ?: "medium"
            if (quality !in allowedQualities) {
                throw WireError.invalidArgument("Unknown quality '$quality'.")
            }
            val codec = args["videoCodec"] as? String ?: "raw"
            if (codec !in allowedCodecs) {
                throw WireError.invalidArgument("Unknown videoCodec '$codec'.")
            }
            val kinds = (args["deviceKinds"] as? List<*>)?.filterIsInstance<String>()?.toSet()
                ?.takeIf { it.isNotEmpty() }
            val audio = args["audio"] as? Map<*, *>
            val sampleRate = audio?.let { (it["sampleRate"] as? Number)?.toInt() ?: 16000 }
            if (sampleRate != null && sampleRate !in allowedSampleRates) {
                throw WireError.invalidArgument(
                    "audio.sampleRate must be 16000, 44100 or 48000 (got $sampleRate).",
                )
            }
            val channels = (audio?.get("channels") as? Number)?.toInt() ?: 1
            return StreamSessionArgs(
                deviceUuid = args["deviceUuid"] as? String,
                frameRate = fps,
                quality = quality,
                videoCodec = codec,
                deviceKinds = kinds,
                audioSampleRate = sampleRate,
                audioChannels = channels,
            )
        }
    }
}
