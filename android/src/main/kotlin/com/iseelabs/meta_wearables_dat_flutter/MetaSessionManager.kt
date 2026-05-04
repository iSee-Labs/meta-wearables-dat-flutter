// Slice 7 - Android streaming bridge.
//
// Owns:
//   - One Stream per active session (only one in v0.1.0).
//   - One TextureRegistry SurfaceTextureEntry that backs the Flutter
//     `Texture` widget on the Dart side.
//   - Coroutine jobs collecting the Stream's video / state / error flows.
//
// Frame pump:
//   videoStream Flow -> VideoFrame (I420 planes) -> YUV->ARGB conversion ->
//   write into the SurfaceTexture's Surface via Canvas / lockHardwareCanvas
//   -> Flutter's TextureRegistry picks up the new contents.
//
// I420->ARGB is done on the CPU for v0.1; this is acceptable because the
// device delivers up to 30fps at 720p, which a single CPU thread can keep
// up with on every shipping Android device that meets minSdk 31.
// GPU-accelerated rendering ships in v0.2.

package com.iseelabs.meta_wearables_dat_flutter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.view.Surface
import com.meta.wearable.dat.camera.Stream
import com.meta.wearable.dat.camera.StreamConfiguration
import com.meta.wearable.dat.camera.StreamError
import com.meta.wearable.dat.camera.StreamSessionState
import com.meta.wearable.dat.camera.VideoFrame
import com.meta.wearable.dat.camera.VideoQuality
import com.meta.wearable.dat.camera.addStream
import com.meta.wearable.dat.camera.types.PhotoData
import java.io.ByteArrayOutputStream
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.meta.wearable.dat.core.selectors.SpecificDeviceSelector
import com.meta.wearable.dat.core.types.DeviceIdentifier
import io.flutter.plugin.common.EventChannel
import io.flutter.view.TextureRegistry
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

    private var stream: Stream? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var surface: Surface? = null

    private var stateJob: Job? = null
    private var errorJob: Job? = null
    private var frameJob: Job? = null

    private var stateSink: EventChannel.EventSink? = null
    private var errorSink: EventChannel.EventSink? = null
    private var sizeSink: EventChannel.EventSink? = null

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

    /**
     * Starts a stream for [deviceUuid] (or the auto-selected active device
     * when null). Returns the Flutter texture id.
     *
     * This call suspends only briefly - it creates the texture entry and
     * Stream, wires the listener jobs, and triggers `start()` - then
     * returns. Frames begin arriving on the videoStream Flow shortly after.
     */
    suspend fun startSession(
        deviceUuid: String?,
        fps: Int,
        quality: VideoQuality,
    ): Long {
        textureEntry?.let { return it.id() }

        // Resolve the target device. AutoDeviceSelector is the simpler path
        // for v0.1 - host apps that need to drive a specific device pass
        // its uuid through and we wrap it in a SpecificDeviceSelector.
        val session = if (deviceUuid != null) {
            val selector = SpecificDeviceSelector(DeviceIdentifier(deviceUuid))
            Wearables.createSession(selector)
        } else {
            Wearables.createSession(AutoDeviceSelector())
        } ?: error("Wearables.createSession returned null")

        val config = StreamConfiguration(
            videoQuality = quality,
            frameRate = fps,
        )
        val newStream = session.addStream(config)
            ?: error("addStream returned null")
        stream = newStream

        // Allocate the Flutter texture before frames start flowing.
        val entry = textureRegistry.createSurfaceTexture()
        textureEntry = entry
        surface = Surface(entry.surfaceTexture())

        // Listener jobs - state, error, frames. Frame collection uses
        // collectLatest so that if we ever fall behind on conversion we
        // skip stale frames rather than queuing them up.
        stateJob = scope.launch {
            newStream.state.collectLatest { state ->
                postState(state)
            }
        }
        errorJob = scope.launch {
            newStream.errorStream.collectLatest { error ->
                postError(error)
            }
        }
        frameJob = scope.launch {
            newStream.videoStream.collectLatest { frame ->
                renderFrame(frame)
            }
        }

        newStream.start()
        return entry.id()
    }

    suspend fun stopSession() {
        stream?.stop()
        stream = null
        stateJob?.cancel()
        errorJob?.cancel()
        frameJob?.cancel()
        stateJob = null
        errorJob = null
        frameJob = null

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
        // Meta's `Result` exposes onSuccess / onFailure rather than
        // kotlin.Result.fold; we read it via getOrThrow() if available, else
        // unwrap onSuccess into a CompletableDeferred-like flow. The
        // simplest portable route is the `getOrNull` accessor.
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
        // Mirrors the iOS behaviour: pause is driven by the device side
        // (hinges, thermal, ...) rather than an explicit API on the SDK
        // surface in 0.6.x. Documented as no-op so host apps can call it
        // unconditionally.
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
        val surface = surface ?: return

        val bitmap = ensureBitmap(width, height)
        // I420 -> ARGB conversion. The exact field names on Meta's
        // VideoFrame in 0.6.x are yPlane / uPlane / vPlane (ByteBuffer)
        // with strides yStride / uStride / vStride. If the API exposes a
        // pre-decoded ARGB buffer in a future release we should prefer it.
        YuvToArgb.convert(
            yPlane = frame.yPlane,
            uPlane = frame.uPlane,
            vPlane = frame.vPlane,
            yStride = frame.yStride,
            uStride = frame.uStride,
            vStride = frame.vStride,
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
        val message = error.message ?: error::class.java.simpleName
        val code = when (error::class.simpleName) {
            "PermissionDenied" -> "PERMISSION_ERROR"
            else -> "SESSION_ERROR"
        }
        mainHandler.post {
            errorSink?.success(mapOf("code" to code, "message" to message))
        }
    }

    private companion object {
        val framePaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    }
}
