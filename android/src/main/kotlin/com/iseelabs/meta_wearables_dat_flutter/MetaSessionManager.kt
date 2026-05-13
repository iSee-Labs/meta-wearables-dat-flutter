// Android streaming bridge.
//
// Owns:
//   - One `Session` (DeviceSession) per active capture - created via
//     `Wearables.createSession(selector)` and started before any stream
//     is added.
//   - One `Stream` (video capability) attached to that Session.
//   - One TextureRegistry SurfaceTextureEntry that backs the Flutter
//     `Texture` widget on the Dart side.
//   - Coroutine jobs collecting the Stream's video / state / error flows
//     plus the DeviceSession's state / error flows.
//
// Lifecycle (matches Meta 0.6 reference sample):
//   1. Wearables.createSession(selector)             // Result<Session>
//   2. session.start()
//   3. session.state.first { STARTED }               // wait
//   4. session.addStream(config)                     // Result<Stream>
//   5. stream.start()
//   6. collect videoStream / state / errorStream
//   ... later ...
//   7. stream.stop(); stream = null
//   8. session.stop(); session = null
//
// Frame pump:
//   videoStream Flow → VideoFrame (I420 planes) → YUV→ARGB conversion
//   → write into the SurfaceTexture's Surface via lockHardwareCanvas
//   → Flutter's TextureRegistry picks up the new contents.

package com.iseelabs.meta_wearables_dat_flutter

import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.view.Surface
import com.meta.wearable.dat.camera.Stream
import com.meta.wearable.dat.camera.addStream
import com.meta.wearable.dat.camera.types.PhotoData
import com.meta.wearable.dat.camera.types.StreamConfiguration
import com.meta.wearable.dat.camera.types.StreamError
import com.meta.wearable.dat.camera.types.StreamSessionState
import com.meta.wearable.dat.camera.types.VideoFrame
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.meta.wearable.dat.core.selectors.SpecificDeviceSelector
import com.meta.wearable.dat.core.session.DeviceSessionState
import com.meta.wearable.dat.core.session.Session
import com.meta.wearable.dat.core.types.DeviceIdentifier
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal class MetaSessionManager(
    private val textureRegistry: TextureRegistry,
) {
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val mainHandler = Handler(Looper.getMainLooper())

    private var session: Session? = null
    private var stream: Stream? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var surface: Surface? = null

    private var deviceStateJob: Job? = null
    private var deviceErrorJob: Job? = null
    private var stateJob: Job? = null
    private var errorJob: Job? = null
    private var frameJob: Job? = null

    private var stateSink: EventChannel.EventSink? = null
    private var errorSink: EventChannel.EventSink? = null
    private var sizeSink: EventChannel.EventSink? = null
    private var deviceStateSink: EventChannel.EventSink? = null
    private var deviceErrorSink: EventChannel.EventSink? = null

    /**
     * Per-frame video payload sink. Gated behind subscriber presence:
     * the I420 payload (width * height * 3 / 2 bytes) is ≈1.3 MB at
     * 720p, so we skip the planes copy entirely when nobody is
     * listening. See `doc/frame_processing.md`.
     */
    private var framesSink: EventChannel.EventSink? = null

    private var streamStartElapsedNs: Long = 0L

    /**
     * Codec the caller asked for in `startStreamSession`. When set to
     * `"hvc1"`, the SDK is expected to emit `VideoFrame`s with the
     * compressed payload accessible via the same flow; the texture
     * preview path is disabled because surfacing compressed Android
     * frames requires a `MediaCodec` decoder that host apps must wire
     * themselves (see `doc/streaming.md`).
     */
    private var activeCodec: String = "raw"

    /**
     * Reused ARGB scratch bitmap. Recreated whenever the source frame
     * dimensions change. Keeping a single bitmap across frames avoids GC
     * pressure at 30fps.
     */
    private var argbBitmap: Bitmap? = null
    private var lastWidth = 0
    private var lastHeight = 0

    fun setStateSink(sink: EventChannel.EventSink?) { stateSink = sink }
    fun setErrorSink(sink: EventChannel.EventSink?) { errorSink = sink }
    fun setSizeSink(sink: EventChannel.EventSink?) { sizeSink = sink }
    fun setDeviceStateSink(sink: EventChannel.EventSink?) { deviceStateSink = sink }
    fun setDeviceErrorSink(sink: EventChannel.EventSink?) { deviceErrorSink = sink }
    fun setFramesSink(sink: EventChannel.EventSink?) { framesSink = sink }

    /**
     * Starts a stream for [deviceUuid] (or the auto-selected active device
     * when null). Returns the Flutter texture id.
     *
     * When [deviceKinds] is non-empty, only devices whose mapped DAT
     * kind (`rayBanMeta` / `rayBanDisplay` / `oakleyMeta` / `unknown`)
     * matches one of the entries is considered by the auto-selector
     * filter or explicit lookup.
     *
     * Mirrors the Meta reference sample lifecycle: create Session, start
     * it, wait for STARTED, add a Stream, then start the Stream.
     */
    suspend fun startSession(
        deviceUuid: String?,
        fps: Int,
        quality: VideoQuality,
        deviceKinds: Set<String>? = null,
        videoCodec: String = "raw",
    ): Long {
        activeCodec = videoCodec
        textureEntry?.let { return it.id() }

        // 1. Resolve the target device.
        val kindsFilter: Set<String>? = deviceKinds?.takeIf { it.isNotEmpty() }
        val selector = if (deviceUuid != null) {
            SpecificDeviceSelector(DeviceIdentifier(deviceUuid))
        } else if (kindsFilter != null) {
            // Enumerate the current device set and pick the first one
            // whose kind matches. Android `AutoDeviceSelector` doesn't
            // expose a public kinds filter on the 0.6.x surface, so we
            // pin the chosen id through `SpecificDeviceSelector`.
            val match = firstDeviceMatchingKinds(kindsFilter)
            if (match != null) {
                SpecificDeviceSelector(match)
            } else {
                AutoDeviceSelector()
            }
        } else {
            AutoDeviceSelector()
        }

        // 2. Create the DeviceSession via Meta's `Result<Session>` API.
        var createError: String? = null
        var created: Session? = null
        Wearables.createSession(selector)
            .onSuccess { created = it }
            .onFailure { error, _ -> createError = error.description }
        val newSession = created
            ?: error("Wearables.createSession failed: ${createError ?: "unknown"}")
        session = newSession

        // Forward DeviceSession-level state / error flows BEFORE start so
        // we capture the initial transitions.
        deviceStateJob = scope.launch {
            newSession.state.collectLatest { state ->
                mainHandler.post {
                    deviceStateSink?.success(encodeDeviceSessionState(state))
                }
            }
        }
        // `Session.errors` is exposed as a Flow; we forward it onto the
        // device_session_errors channel. If the SDK ever stops exposing it
        // we'll catch a NoSuchMethodError and skip — defensive copy.
        deviceErrorJob = scope.launch {
            try {
                @Suppress("UNCHECKED_CAST")
                val errorsField =
                    newSession::class.java.getMethod("getErrors").invoke(newSession)
                if (errorsField is kotlinx.coroutines.flow.Flow<*>) {
                    errorsField.collectLatest { error ->
                        mainHandler.post {
                            deviceErrorSink?.success(encodeDeviceSessionError(error))
                        }
                    }
                }
            } catch (_: Throwable) {
                // Older SDKs without the errors flow: silently ignore.
            }
        }

        // 3. Start and wait until STARTED before adding a stream.
        newSession.start()
        newSession.state.first { it == DeviceSessionState.STARTED }

        // 4. Add the Stream capability. When the caller selected
        // `hvc1`, ask the SDK for compressed HEVC frames via
        // `compressVideo = true`. Texture preview is intentionally
        // disabled in that mode (see frame rendering below).
        val config = buildStreamConfiguration(quality, fps, videoCodec == "hvc1")
        var streamError: String? = null
        var newStream: Stream? = null
        newSession.addStream(config)
            .onSuccess { newStream = it }
            .onFailure { error, _ -> streamError = error.description }
        val resolvedStream = newStream
            ?: run {
                // Rollback the DeviceSession we started above.
                newSession.stop()
                session = null
                deviceStateJob?.cancel(); deviceStateJob = null
                deviceErrorJob?.cancel(); deviceErrorJob = null
                error("addStream failed: ${streamError ?: "unknown"}")
            }
        stream = resolvedStream

        // 5. Allocate the Flutter texture before frames start flowing.
        val entry = textureRegistry.createSurfaceTexture()
        textureEntry = entry
        surface = Surface(entry.surfaceTexture())

        // 6. Wire stream listener jobs (state, error, frames). Frame
        // collection uses collectLatest so that if we ever fall behind on
        // conversion we skip stale frames rather than queuing them up.
        stateJob = scope.launch {
            resolvedStream.state.collectLatest { state -> postState(state) }
        }
        errorJob = scope.launch {
            resolvedStream.errorStream.collectLatest { error -> postError(error) }
        }
        frameJob = scope.launch {
            resolvedStream.videoStream.collectLatest { frame -> renderFrame(frame) }
        }

        // 7. Start the stream.
        streamStartElapsedNs = android.os.SystemClock.elapsedRealtimeNanos()
        resolvedStream.start()
        return entry.id()
    }

    /**
     * Stops the active Stream then the underlying Session. Idempotent.
     * Mirrors the iOS path: stop the stream first so any in-flight frames
     * are drained, then stop the DeviceSession so future
     * `createSession()` calls succeed without `sessionAlreadyExists`.
     */
    suspend fun stopSession() {
        // Cancel listener jobs first so we don't race on shutdown.
        stateJob?.cancel(); stateJob = null
        errorJob?.cancel(); errorJob = null
        frameJob?.cancel(); frameJob = null

        try {
            stream?.stop()
        } catch (_: Throwable) {
            // Stream may already be terminal; ignore.
        }
        stream = null

        deviceStateJob?.cancel(); deviceStateJob = null
        deviceErrorJob?.cancel(); deviceErrorJob = null

        try {
            session?.stop()
        } catch (_: Throwable) {
            // Session may already be terminal; ignore.
        }
        session = null

        withContext(Dispatchers.Main) {
            surface?.release()
            surface = null
            textureEntry?.release()
            textureEntry = null
        }
        argbBitmap?.recycle()
        argbBitmap = null
        lastWidth = 0
        lastHeight = 0
        streamStartElapsedNs = 0L
    }

    /**
     * Captures a still photo mid-stream and returns it as a (bytes, format)
     * pair. The format is determined by the device side: HEIC frames are
     * passed through unchanged; Bitmap frames are encoded to JPEG at
     * quality 95 (a good balance for OCR and ML pipelines).
     */
    suspend fun capturePhoto(): Pair<ByteArray, String> {
        val stream = stream ?: error("No active stream session")
        val outcome = stream.capturePhoto()
        val photo = outcome.getOrNull()
            ?: error("capturePhoto failed: ${outcome.exceptionOrNull()?.message}")
        return when (photo) {
            is PhotoData.Bitmap -> {
                val bos = ByteArrayOutputStream()
                photo.bitmap.compress(Bitmap.CompressFormat.JPEG, 95, bos)
                bos.toByteArray() to "jpeg"
            }
            is PhotoData.HEIC -> {
                val buffer = photo.data.duplicate().apply { position(0) }
                val bytes = ByteArray(buffer.remaining())
                buffer.get(bytes)
                bytes to "heic"
            }
        }
    }

    fun pauseSession() {
        // Pause/resume is driven by the device side (hinges, thermal, ...)
        // rather than an explicit API on the 0.6.x surface. Documented as
        // no-op so host apps can call it unconditionally.
    }

    fun resumeSession() {
        // See pauseSession.
    }

    fun dispose() {
        scope.cancel()
        argbBitmap?.recycle()
        argbBitmap = null
    }

    // --- Frame rendering -----------------------------------------------------

    private fun renderFrame(frame: VideoFrame) {
        val width = frame.width
        val height = frame.height

        // hvc1 path: forward compressed bytes when subscribers exist
        // and bail out — no texture preview is rendered for hvc1 on
        // Android (see doc/streaming.md).
        if (activeCodec == "hvc1") {
            val sink = framesSink
            if (sink != null) {
                emitCompressedFrame(frame, width, height, sink)
            }
            if (lastWidth != width || lastHeight != height) {
                lastWidth = width
                lastHeight = height
                mainHandler.post {
                    sizeSink?.success(mapOf("width" to width, "height" to height))
                }
            }
            return
        }

        val surface = surface ?: return

        // Forward raw I420 to the videoFramesStream sink before we
        // start mutating the bitmap. Gated on subscriber presence to
        // keep per-frame cost free when nobody is listening.
        val sink = framesSink
        if (sink != null) {
            emitVideoFrame(frame, width, height, sink)
        }

        val bitmap = ensureBitmap(width, height)
        // SDK 0.6.x: `VideoFrame.buffer` is a single I420 ByteBuffer
        // laid out as Y | U | V (no row-stride padding). Forward it
        // straight to YuvToArgb which expects that exact layout.
        YuvToArgb.convert(
            yuvData = frame.buffer,
            width = width,
            height = height,
            output = bitmap,
        )

        try {
            val canvas = surface.lockHardwareCanvas() ?: return
            try {
                canvas.drawColor(android.graphics.Color.BLACK)
                val matrix = Matrix().apply {
                    val sx = canvas.width / width.toFloat()
                    val sy = canvas.height / height.toFloat()
                    val s = minOf(sx, sy)
                    postScale(s, s)
                    postTranslate(
                        (canvas.width - width * s) / 2f,
                        (canvas.height - height * s) / 2f,
                    )
                }
                canvas.drawBitmap(bitmap, matrix, framePaint)
            } finally {
                surface.unlockCanvasAndPost(canvas)
            }
        } catch (_: IllegalStateException) {
            // Surface released between check and lock - ignore.
        }

        if (lastWidth != width || lastHeight != height) {
            lastWidth = width
            lastHeight = height
            mainHandler.post {
                sizeSink?.success(mapOf("width" to width, "height" to height))
            }
        }
    }

    /**
     * Serialises a single I420 [VideoFrame] into the Flutter platform-channel
     * payload consumed by [`videoFramesStream`]. The three planes are
     * concatenated as `Y | U | V` to `width * height * 3/2` bytes
     * (Android I420 is always 8-bit, packed; no row stride padding for the
     * common SDK shape — if the underlying planes have stride > width we
     * strip the padding here so Dart callers see a tightly-packed buffer).
     *
     * The payload shape matches `VideoFrame.fromMap` on Dart:
     *   `{ codec, bytes, width, height, ptsUs, isKeyframe, bytesPerRow=null }`.
     */
    private fun emitVideoFrame(
        frame: VideoFrame,
        width: Int,
        height: Int,
        sink: EventChannel.EventSink,
    ) {
        val ySize = width * height
        val uvSize = (width / 2) * (height / 2)
        val total = ySize + 2 * uvSize
        // SDK 0.6.x: `VideoFrame.buffer` already contains I420 as
        // Y | U | V with no row-stride padding. Single bulk copy.
        val out = ByteArray(total)
        val src = frame.buffer.duplicate().apply { position(frame.buffer.position()) }
        val available = minOf(total, src.remaining())
        src.get(out, 0, available)

        val ptsUs = frame.presentationTimeUs

        mainHandler.post {
            sink.success(
                mapOf(
                    "codec" to "raw",
                    "bytes" to out,
                    "width" to width,
                    "height" to height,
                    "ptsUs" to ptsUs,
                    "isKeyframe" to true,
                    "bytesPerRow" to null,
                ),
            )
        }
    }

    /**
     * Serialises a compressed (hvc1) [VideoFrame] payload to the
     * `videoFramesStream` map shape.
     *
     * The Meta DAT 0.6.x [VideoFrame] type exposes the compressed bytes
     * via a `compressedData: ByteBuffer?` (or similar) field depending
     * on the SDK build. We use reflection so we don't break compilation
     * across SDK revisions, and gracefully fall back to skipping the
     * frame if the field cannot be resolved.
     */
    private fun emitCompressedFrame(
        frame: VideoFrame,
        width: Int,
        height: Int,
        sink: EventChannel.EventSink,
    ) {
        val payload = extractCompressedBytes(frame) ?: return
        val isKeyframe = extractIsKeyframe(frame)
        val nowNs = android.os.SystemClock.elapsedRealtimeNanos()
        val ptsUs = if (streamStartElapsedNs == 0L) 0L
        else (nowNs - streamStartElapsedNs) / 1_000L
        mainHandler.post {
            sink.success(
                mapOf(
                    "codec" to "hvc1",
                    "bytes" to payload,
                    "width" to width,
                    "height" to height,
                    "ptsUs" to ptsUs,
                    "isKeyframe" to isKeyframe,
                    "bytesPerRow" to null,
                ),
            )
        }
    }

    /**
     * Reads the compressed-payload bytes from a [VideoFrame] using
     * reflection. Tries the common field names that have appeared
     * across DAT SDK 0.6.x builds (`compressedData`, `compressed`,
     * `compressedBytes`). Returns `null` when no matching field is
     * present.
     */
    private fun extractCompressedBytes(frame: VideoFrame): ByteArray? {
        val candidates = listOf(
            "getCompressedData",
            "getCompressed",
            "getCompressedBytes",
            "getEncoded",
        )
        for (name in candidates) {
            val method = try {
                frame::class.java.getMethod(name)
            } catch (_: Throwable) {
                continue
            }
            val value = try { method.invoke(frame) } catch (_: Throwable) { null }
            when (value) {
                is ByteArray -> return value
                is java.nio.ByteBuffer -> {
                    val dup = value.duplicate()
                    dup.position(0)
                    val out = ByteArray(dup.remaining())
                    dup.get(out)
                    return out
                }
                else -> Unit
            }
        }
        return null
    }

    /**
     * Reads `isKeyframe` / `isKey` / `keyframe` from a [VideoFrame] via
     * reflection, defaulting to `true` when no matching getter is
     * present (single-NAL CMSampleBuffers).
     */
    private fun extractIsKeyframe(frame: VideoFrame): Boolean {
        val names = listOf("isKeyframe", "isKey", "getKeyframe", "isCompressedKey")
        for (name in names) {
            val method = try {
                frame::class.java.getMethod(name)
            } catch (_: Throwable) {
                continue
            }
            val value = try { method.invoke(frame) } catch (_: Throwable) { null }
            if (value is Boolean) return value
        }
        return true
    }

    private fun ensureBitmap(width: Int, height: Int): Bitmap {
        val existing = argbBitmap
        if (existing != null && existing.width == width && existing.height == height) {
            return existing
        }
        existing?.recycle()
        val created = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        argbBitmap = created
        return created
    }

    // --- State / error encoding ---------------------------------------------

    private fun postState(state: StreamSessionState) {
        val encoded = when (state::class.simpleName) {
            "Stopped" -> 0
            "WaitingForDevice" -> 1
            "Starting" -> 2
            "Streaming" -> 3
            "Paused" -> 4
            "Stopping" -> 5
            else -> 0
        }
        mainHandler.post { stateSink?.success(encoded) }
    }

    private fun postError(error: StreamError) {
        // SDK 0.6.x: `StreamError` is a sealed class whose human-readable
        // text lives on `.description` (not `.message`).
        val message = runCatching { error.description }
            .getOrNull()
            ?.takeIf { it.isNotEmpty() }
            ?: error::class.java.simpleName
        // Match Dart's `StreamSessionError` code shape: typed codes
        // for the cases the Dart facade flips into `is*` getters.
        val code = when (error::class.simpleName) {
            "PermissionDenied" -> "permissionDenied"
            "ThermalCritical" -> "thermalCritical"
            "HingesClosed", "HingeClosed" -> "hingesClosed"
            "DeviceDisconnected", "DeviceNotConnected" -> "deviceDisconnected"
            "DeviceNotFound" -> "deviceNotFound"
            "Timeout" -> "timeout"
            "VideoStreamingError" -> "videoStreamingError"
            "InternalError" -> "internalError"
            else -> "sessionError"
        }
        mainHandler.post {
            errorSink?.success(mapOf("code" to code, "message" to message))
        }
    }

    private fun encodeDeviceSessionState(state: DeviceSessionState): Int =
        // Map by name so we don't break compilation if Meta adds enum cases.
        when (state.name.uppercase()) {
            "IDLE" -> 0
            "STARTING" -> 1
            "STARTED", "RUNNING" -> 2
            "PAUSED" -> 3
            "STOPPING" -> 4
            "STOPPED", "CLOSED" -> 5
            else -> 0
        }

    private fun encodeDeviceSessionError(error: Any?): Map<String, Any?> {
        val message = error?.toString() ?: "unknown"
        val name = error?.let { it::class.java.simpleName } ?: ""
        val code = when (name) {
            "NoEligibleDevice" -> "noEligibleDevice"
            "SessionAlreadyStopped" -> "sessionAlreadyStopped"
            "SessionAlreadyExists" -> "sessionAlreadyExists"
            "SessionIdle" -> "sessionIdle"
            "CapabilityAlreadyActive" -> "capabilityAlreadyActive"
            "CapabilityNotFound" -> "capabilityNotFound"
            else -> "unexpectedError"
        }
        return mapOf("code" to code, "message" to message)
    }

    /**
     * Builds a [StreamConfiguration] respecting [compressVideo]. The
     * SDK 0.6.x [StreamConfiguration] type only adds the
     * `compressVideo` knob in some shipping flavours, so we use
     * reflection to set it when present and fall back to the legacy
     * two-arg constructor otherwise. This avoids breaking compilation
     * if Meta changes the constructor surface.
     */
    private fun buildStreamConfiguration(
        quality: VideoQuality,
        fps: Int,
        compressVideo: Boolean,
    ): StreamConfiguration {
        if (!compressVideo) {
            return StreamConfiguration(videoQuality = quality, frameRate = fps)
        }
        // Try the three-arg constructor first via reflection.
        try {
            val ctor = StreamConfiguration::class.java
                .declaredConstructors
                .firstOrNull { it.parameterCount == 3 }
            if (ctor != null) {
                @Suppress("UNCHECKED_CAST")
                val instance = ctor.newInstance(quality, fps, compressVideo)
                    as StreamConfiguration
                return instance
            }
        } catch (_: Throwable) {
            // fall through
        }
        // Fall back to the two-arg constructor and try setting
        // `compressVideo` via reflection on the instance afterwards.
        val cfg = StreamConfiguration(videoQuality = quality, frameRate = fps)
        try {
            val field = cfg::class.java.declaredFields.firstOrNull {
                it.name == "compressVideo"
            }
            if (field != null) {
                field.isAccessible = true
                field.setBoolean(cfg, true)
            }
        } catch (_: Throwable) {
            android.util.Log.w(
                "MetaSessionManager",
                "Requested compressVideo=true but this Meta DAT SDK does " +
                    "not expose the field; falling back to raw frames. " +
                    "Update the dependency or report a bug.",
            )
        }
        return cfg
    }

    /**
     * Returns the first paired-device identifier whose mapped wire-kind
     * is contained in [kinds]. Uses reflection to read the per-device
     * metadata so we don't depend on a specific shape of
     * `DeviceMetadata`.
     */
    private suspend fun firstDeviceMatchingKinds(
        kinds: Set<String>,
    ): DeviceIdentifier? {
        val ids = try {
            Wearables.devices.first()
        } catch (_: Throwable) {
            return null
        }
        return ids.firstOrNull { id ->
            kinds.contains(MetaWearablesDatPlugin.wireKindForDevice(id))
        }
    }

    private companion object {
        val framePaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    }
}
