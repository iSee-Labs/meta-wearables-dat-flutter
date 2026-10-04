// Decodes the DAT `hvc1` stream (Annex-B HEVC access units) straight into
// the Flutter texture's Surface with MediaCodec, so the GPU does the
// YUV -> RGB conversion. Mirrors the decoder in Meta's CameraAccess
// sample: a software decoder is preferred (it keeps running while the app
// is backgrounded) and known-bad vendor decoders are skipped.
//
// Input is gated until parameter sets and a keyframe have been seen; a
// codec error restarts the decoder and waits for the next keyframe.

package com.iseelabs.meta_wearables_dat_flutter

import android.media.MediaCodec
import android.media.MediaCodecList
import android.media.MediaFormat
import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import android.util.Log
import android.view.Surface
import java.util.ArrayDeque

class HevcSurfaceDecoder(private val surface: Surface) {
    companion object {
        private const val TAG = "MetaWearablesDat"
        private const val MAX_PENDING = 30
        private val BLOCKED_DECODERS = setOf("OMX.Exynos.hevc.dec", "c2.mtk.hevc.decoder")

        /** True when the device can decode HEVC at all. */
        fun isSupported(): Boolean = MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos.any { info ->
            !info.isEncoder && info.supportedTypes.any {
                it.equals(MediaFormat.MIMETYPE_VIDEO_HEVC, ignoreCase = true)
            }
        }
    }

    private class Unit(val data: ByteArray, val ptsUs: Long, val flags: Int)

    private val lock = Object()
    private val pending = ArrayDeque<Unit>()
    private val freeInputs = ArrayDeque<Int>()
    private var thread: HandlerThread? = null
    private var codec: MediaCodec? = null
    private var width = 0
    private var height = 0
    private var parameterSets: ByteArray? = null
    private var awaitingKeyframe = true
    @Volatile private var running = false

    /** Feeds one access unit. Safe to call from the frame thread. */
    fun submit(data: ByteArray, ptsUs: Long, isCodecConfig: Boolean, frameWidth: Int, frameHeight: Int) {
        val types = HevcNal.nalTypes(data)
        if (isCodecConfig || HevcNal.isParameterSetsOnly(types)) {
            parameterSets = data
            return
        }
        if (HevcNal.hasParameterSets(types)) parameterSets = null

        if (codec == null || frameWidth != width || frameHeight != height) {
            restart(frameWidth, frameHeight)
        }
        synchronized(lock) {
            if (awaitingKeyframe) {
                if (!HevcNal.isKeyframe(types)) return
                awaitingKeyframe = false
                parameterSets?.let {
                    pending.addLast(Unit(it, ptsUs, MediaCodec.BUFFER_FLAG_CODEC_CONFIG))
                }
            }
            if (pending.size >= MAX_PENDING) {
                // The decoder fell behind; drop the backlog and resync on the next keyframe.
                pending.clear()
                awaitingKeyframe = true
                return
            }
            val flags = if (HevcNal.isKeyframe(types)) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
            pending.addLast(Unit(data, ptsUs, flags))
        }
        drain()
    }

    fun stop() {
        running = false
        synchronized(lock) {
            pending.clear()
            freeInputs.clear()
        }
        try {
            codec?.stop()
        } catch (_: Throwable) {
        }
        try {
            codec?.release()
        } catch (_: Throwable) {
        }
        codec = null
        thread?.quitSafely()
        thread = null
        width = 0
        height = 0
        awaitingKeyframe = true
    }

    private fun restart(frameWidth: Int, frameHeight: Int) {
        stop()
        width = frameWidth
        height = frameHeight
        val handlerThread = HandlerThread("MetaWearablesDatHevc", Process.THREAD_PRIORITY_VIDEO).also { it.start() }
        thread = handlerThread
        try {
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_HEVC, frameWidth, frameHeight)
            val decoder = createDecoder()
            decoder.setCallback(callback, Handler(handlerThread.looper))
            decoder.configure(format, surface, null, 0)
            decoder.start()
            codec = decoder
            running = true
        } catch (e: Throwable) {
            Log.e(TAG, "HEVC decoder start failed: ${e.message}", e)
            stop()
        }
    }

    private fun createDecoder(): MediaCodec {
        val mime = MediaFormat.MIMETYPE_VIDEO_HEVC
        val software = MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos.firstOrNull { info ->
            !info.isEncoder && info.isSoftwareOnly && info.name !in BLOCKED_DECODERS &&
                info.supportedTypes.any { it.equals(mime, ignoreCase = true) }
        }
        return if (software != null) {
            MediaCodec.createByCodecName(software.name)
        } else {
            MediaCodec.createDecoderByType(mime)
        }
    }

    private fun drain() {
        val decoder = codec ?: return
        while (running) {
            val unit: Unit
            val index: Int
            synchronized(lock) {
                if (pending.isEmpty() || freeInputs.isEmpty()) return
                unit = pending.removeFirst()
                index = freeInputs.removeFirst()
            }
            try {
                val buffer = decoder.getInputBuffer(index) ?: continue
                buffer.clear()
                if (unit.data.size > buffer.capacity()) {
                    decoder.queueInputBuffer(index, 0, 0, unit.ptsUs, 0)
                    continue
                }
                buffer.put(unit.data)
                decoder.queueInputBuffer(index, 0, unit.data.size, unit.ptsUs, unit.flags)
            } catch (e: Throwable) {
                Log.w(TAG, "HEVC queueInputBuffer failed: ${e.message}")
                synchronized(lock) { awaitingKeyframe = true }
                return
            }
        }
    }

    private val callback = object : MediaCodec.Callback() {
        override fun onInputBufferAvailable(codec: MediaCodec, index: Int) {
            synchronized(lock) { freeInputs.addLast(index) }
            drain()
        }

        override fun onOutputBufferAvailable(codec: MediaCodec, index: Int, info: MediaCodec.BufferInfo) {
            try {
                codec.releaseOutputBuffer(index, running && info.size > 0)
            } catch (_: Throwable) {
            }
        }

        override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
            Log.w(TAG, "HEVC decoder error (recoverable=${e.isRecoverable}): ${e.message}")
            // Force a rebuild on the next access unit.
            width = -1
            height = -1
            synchronized(lock) {
                pending.clear()
                awaitingKeyframe = true
            }
        }

        override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) = Unit
    }
}
