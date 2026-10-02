// Camera streaming bridge (DAT 1.0 consolidated Camera capability).
//
// start: hub.acquire (shared session, STARTED) -> SurfaceProducer texture
//        -> session.addCamera(StreamConfiguration) -> collect camera /
//        stream flows (before start) -> stream.start() -> wait STREAMING
// stop:  cancel collectors -> camera.stop() -> session.removeCamera()
//        -> hub.release -> release texture
//
// Frames: raw I420 is converted to ARGB and drawn on the texture Surface;
// hvc1 is decoded by MediaCodec straight into the Surface. The opt-in
// `video_frames` payload is built only while a Dart listener is attached.

package com.iseelabs.meta_wearables_dat_flutter

import android.graphics.Bitmap
import android.graphics.Bitmap.CompressFormat
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.util.Log
import com.meta.wearable.dat.camera.Camera
import com.meta.wearable.dat.camera.Stream
import com.meta.wearable.dat.camera.addCamera
import com.meta.wearable.dat.camera.photo.Photo
import com.meta.wearable.dat.camera.photo.types.PhotoCaptureData
import com.meta.wearable.dat.camera.photo.types.PhotoQuality
import com.meta.wearable.dat.camera.photo.types.PhotoResolution
import com.meta.wearable.dat.camera.photo.types.PhotoState
import com.meta.wearable.dat.camera.removeCamera
import com.meta.wearable.dat.camera.types.AudioCodec
import com.meta.wearable.dat.camera.types.AudioFrame
import com.meta.wearable.dat.camera.types.AudioSampleRate
import com.meta.wearable.dat.camera.types.PhotoData
import com.meta.wearable.dat.camera.types.StreamConfiguration
import com.meta.wearable.dat.camera.types.StreamState
import com.meta.wearable.dat.camera.types.VideoFrame
import com.meta.wearable.dat.camera.types.VideoQuality
import io.flutter.view.TextureRegistry
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.selects.select
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

class MetaSessionManager(
    private val textures: TextureRegistry,
    private val hub: DeviceSessionHub,
    private val scope: CoroutineScope,
) {
    companion object {
        private const val TAG = "MetaWearablesDat"
        const val OWNER = "camera"
        const val STREAMING_TIMEOUT_MS = 30_000L
        const val PHOTO_TIMEOUT_MS = 15_000L
        const val HQ_PHOTO_TIMEOUT_MS = 45_000L
    }

    val stateSink = EventSinkHandler()
    val errorSink = EventSinkHandler()
    val cameraStateSink = EventSinkHandler()
    val sizeSink = EventSinkHandler()
    val framesSink = EventSinkHandler()
    val audioSink = EventSinkHandler()
    val photoStateSink = EventSinkHandler()
    val photoProgressSink = EventSinkHandler()
    val photoErrorSink = EventSinkHandler()

    private val frameExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "MetaWearablesDatFrames").apply { priority = Thread.MAX_PRIORITY - 1 }
    }
    private val frameDispatcher = frameExecutor.asCoroutineDispatcher()

    private var camera: Camera? = null
    private var stream: Stream? = null
    private var producer: TextureRegistry.SurfaceProducer? = null
    private var decoder: HevcSurfaceDecoder? = null
    private var codec = "raw"
    private val jobs = mutableListOf<Job>()
    private var photoJobs = mutableListOf<Job>()
    private var lastState: StreamState = StreamState.STOPPED
    private var hasBeenActive = false
    private var captureInFlight = false
    private var hqCaptureInFlight = false

    @Volatile private var lastWidth = 0
    @Volatile private var lastHeight = 0
    private var bitmap: Bitmap? = null
    private val paint = Paint(Paint.FILTER_BITMAP_FLAG)

    init {
        stateSink.onSinkChange = { sink -> sink?.success(WireCodec.streamState(lastState)) }
        sizeSink.onSinkChange = { sink ->
            if (sink != null && lastWidth > 0) {
                sink.success(mapOf("width" to lastWidth, "height" to lastHeight))
            }
        }
    }

    val isStreaming: Boolean get() = camera != null
    val activeCodec: String? get() = if (camera != null) codec else null

    // --- Lifecycle ---------------------------------------------------------------

    suspend fun startSession(args: StreamSessionArgs): Long {
        producer?.let { if (camera != null) return it.id() }

        val session = hub.acquire(OWNER, args.deviceUuid, args.deviceKinds, onTerminated = {
            scope.launch { clearStreamResources(releaseHub = false) }
        })

        codec = args.videoCodec
        val texture = textures.createSurfaceProducer()
        producer = texture
        texture.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                // The surface was recreated (e.g. after the app resumed):
                // rebuild the decoder on the new surface.
                if (codec == "hvc1") frameExecutor.execute { rebuildDecoder() }
            }

            override fun onSurfaceCleanup() {
                frameExecutor.execute {
                    decoder?.stop()
                    decoder = null
                }
            }
        })
        ResourceLedger.acquire(ResourceLedger.Kind.TEXTURES)
        if (codec == "hvc1") {
            if (!HevcSurfaceDecoder.isSupported()) {
                errorSink.send(
                    WireError(
                        WireCategory.STREAM, "hevcDecoderUnavailable",
                        "This device has no HEVC decoder; the hvc1 preview texture stays empty. " +
                            "Use videoCodec raw for a preview.",
                        extras = mapOf("severity" to "warning"),
                    ).eventPayload,
                )
            }
            ResourceLedger.acquire(ResourceLedger.Kind.DECODERS)
        }

        val config = StreamConfiguration(
            args.audioSampleRate?.let { rate ->
                AudioCodec.PCM(
                    when (rate) {
                        44100 -> AudioSampleRate.RATE_44100
                        48000 -> AudioSampleRate.RATE_48000
                        else -> AudioSampleRate.RATE_16000
                    },
                    args.audioChannels,
                )
            },
            when (args.quality) {
                "low" -> VideoQuality.LOW
                "high" -> VideoQuality.HIGH
                else -> VideoQuality.MEDIUM
            },
            args.frameRate,
            args.compressVideo,
        )

        val added = session.addCamera(config)
        val newCamera = added.getOrNull()
        if (newCamera == null) {
            clearStreamResources(releaseHub = true)
            throw WireCodec.from(added.errorOrNull(), WireCategory.DEVICE_SESSION)
        }
        camera = newCamera
        stream = newCamera.stream
        ResourceLedger.acquire(ResourceLedger.Kind.CAMERAS)
        hasBeenActive = false
        subscribe(newCamera, newCamera.stream)

        val started = newCamera.stream.start()
        if (started.isFailure) {
            val error = WireCodec.from(started.errorOrNull(), WireCategory.STREAM)
            clearStreamResources(releaseHub = true)
            throw error
        }
        waitForStreaming(newCamera.stream)
        return texture.id()
    }

    suspend fun stopSession() = clearStreamResources(releaseHub = true)

    private fun subscribe(camera: Camera, stream: Stream) {
        jobs += scope.launch {
            camera.state.collect { cameraStateSink.send(WireCodec.state(it)) }
        }
        jobs += scope.launch {
            stream.state.collect { handleState(it) }
        }
        jobs += scope.launch {
            stream.errorStream.collect { error ->
                errorSink.send(WireCodec.error(WireCategory.STREAM, error).eventPayload)
            }
        }
        jobs += scope.launch(frameDispatcher) {
            stream.videoStream.collect { renderFrame(it) }
        }
        jobs += scope.launch(frameDispatcher) {
            stream.audioStream.collect { frame ->
                if (audioSink.hasListener) audioSink.send(audioPayload(frame))
            }
        }
        ResourceLedger.acquire(ResourceLedger.Kind.LISTENERS, 5)
    }

    private fun handleState(state: StreamState) {
        lastState = state
        stateSink.send(WireCodec.streamState(state))
        when (state) {
            StreamState.STARTING, StreamState.STARTED, StreamState.STREAMING, StreamState.PAUSED ->
                hasBeenActive = true
            StreamState.STOPPED, StreamState.CLOSED ->
                // A stream that stops on its own still detaches the camera so a
                // later start works (Android streams cannot be restarted).
                if (hasBeenActive && camera != null) {
                    scope.launch { clearStreamResources(releaseHub = true) }
                }
            else -> Unit
        }
    }

    private suspend fun waitForStreaming(s: Stream) {
        val reached = withTimeoutOrNull(STREAMING_TIMEOUT_MS) {
            s.state.first {
                it == StreamState.STREAMING || it == StreamState.PAUSED ||
                    (hasBeenActive && (it == StreamState.STOPPED || it == StreamState.CLOSED))
            }
        }
        when (reached) {
            StreamState.STREAMING, StreamState.PAUSED -> return
            null -> errorSink.send(
                WireError(
                    WireCategory.STREAM, "timeout",
                    "The stream did not start within ${STREAMING_TIMEOUT_MS / 1000} s; still waiting for the device.",
                ).eventPayload,
            )
            else -> throw WireError(
                WireCategory.STREAM, "stoppedBeforeStart", "The stream stopped before it started.",
            )
        }
    }

    /** Single teardown convergence point. Idempotent. */
    suspend fun clearStreamResources(releaseHub: Boolean) {
        val oldCamera = camera
        val hadTexture = producer != null
        camera = null
        stream = null
        val running = jobs.toList() + photoJobs
        jobs.clear()
        photoJobs = mutableListOf()
        running.forEach { it.cancel() }
        if (running.isNotEmpty()) ResourceLedger.release(ResourceLedger.Kind.LISTENERS, running.size)
        captureInFlight = false
        hqCaptureInFlight = false

        if (oldCamera != null) {
            try {
                oldCamera.stop()
            } catch (e: Throwable) {
                Log.w(TAG, "camera.stop failed: ${e.message}")
            }
            hub.session?.removeCamera()
            ResourceLedger.release(ResourceLedger.Kind.CAMERAS)
        }

        // Wait for any frame being drawn before releasing the surface.
        val wasHevc = codec == "hvc1"
        withContext(frameDispatcher) {
            decoder?.stop()
            decoder = null
        }
        if (hadTexture) {
            producer?.release()
            producer = null
            ResourceLedger.release(ResourceLedger.Kind.TEXTURES)
            if (wasHevc) ResourceLedger.release(ResourceLedger.Kind.DECODERS)
        }
        lastWidth = 0
        lastHeight = 0
        if (lastState != StreamState.STOPPED) {
            lastState = StreamState.STOPPED
            stateSink.send("stopped")
        }
        if (releaseHub) hub.release(OWNER)
    }

    fun dispose() {
        frameExecutor.shutdown()
        bitmap?.recycle()
        bitmap = null
    }

    // --- Frames --------------------------------------------------------------------

    /** Runs on the frame thread. */
    private fun renderFrame(frame: VideoFrame) {
        val texture = producer ?: return
        val width = frame.width
        val height = frame.height
        if (width != lastWidth || height != lastHeight) {
            lastWidth = width
            lastHeight = height
            texture.setSize(width, height)
            sizeSink.send(mapOf("width" to width, "height" to height))
            if (codec == "hvc1") rebuildDecoder()
        }

        val wantsFrames = framesSink.hasListener
        if (frame.isCompressed) {
            val bytes = ByteArray(frame.buffer.remaining())
            frame.buffer.duplicate().get(bytes)
            val types = HevcNal.nalTypes(bytes)
            if (wantsFrames) {
                framesSink.send(
                    mapOf(
                        "codec" to "hvc1",
                        "bytes" to bytes,
                        "width" to width,
                        "height" to height,
                        "ptsUs" to frame.presentationTimeUs,
                        "isKeyframe" to HevcNal.isKeyframe(types),
                        "isCodecConfig" to frame.isCodecConfig,
                    ),
                )
            }
            if (decoder == null) rebuildDecoder()
            decoder?.submit(bytes, frame.presentationTimeUs, frame.isCodecConfig, width, height)
            return
        }

        if (wantsFrames) {
            val size = width * height * 3 / 2
            val bytes = ByteArray(minOf(size, frame.buffer.remaining()))
            frame.buffer.duplicate().get(bytes)
            framesSink.send(
                mapOf(
                    "codec" to "raw",
                    "pixelFormat" to "i420",
                    "bytes" to bytes,
                    "width" to width,
                    "height" to height,
                    "bytesPerRow" to width,
                    "ptsUs" to frame.presentationTimeUs,
                    "isKeyframe" to true,
                    "isCodecConfig" to false,
                ),
            )
        }

        val target = ensureBitmap(width, height)
        YuvToArgb.convert(frame.buffer, width, height, target)
        val surface = texture.surface ?: return
        try {
            val canvas = surface.lockHardwareCanvas() ?: return
            try {
                canvas.drawColor(Color.BLACK)
                val scale = minOf(canvas.width / width.toFloat(), canvas.height / height.toFloat())
                val matrix = Matrix().apply {
                    postScale(scale, scale)
                    postTranslate((canvas.width - width * scale) / 2f, (canvas.height - height * scale) / 2f)
                }
                canvas.drawBitmap(target, matrix, paint)
            } finally {
                surface.unlockCanvasAndPost(canvas)
            }
        } catch (_: IllegalStateException) {
            // The surface was released between the check and the lock.
        } catch (_: IllegalArgumentException) {
        }
    }

    /** Runs on the frame thread. */
    private fun rebuildDecoder() {
        decoder?.stop()
        decoder = null
        val surface = producer?.surface ?: return
        decoder = HevcSurfaceDecoder(surface)
    }

    private fun ensureBitmap(width: Int, height: Int): Bitmap {
        val current = bitmap
        if (current != null && current.width == width && current.height == height) return current
        current?.recycle()
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bitmap = it }
    }

    private fun audioPayload(frame: AudioFrame): Map<String, Any?> {
        val bytes = ByteArray(frame.buffer.remaining())
        frame.buffer.duplicate().get(bytes)
        return mapOf(
            "bytes" to bytes,
            "ptsUs" to frame.presentationTimeUs,
        )
    }

    // --- Photo from the stream (publishable) ---------------------------------------

    suspend fun capturePhoto(format: String): Pair<ByteArray, String> {
        val s = stream ?: throw WireError(
            WireCategory.CAPTURE, "notStreaming", "No active stream. Call startStreamSession first.",
        )
        if (captureInFlight) {
            throw WireError(WireCategory.CAPTURE, "captureInProgress", "A photo capture is already in progress.")
        }
        captureInFlight = true
        try {
            val result = withTimeoutOrNull(PHOTO_TIMEOUT_MS) { s.capturePhoto() }
                ?: throw WireError(
                    WireCategory.CAPTURE, "timeout",
                    "The glasses did not return a photo within ${PHOTO_TIMEOUT_MS / 1000} s.",
                )
            val photo = result.getOrNull() ?: throw WireCodec.from(result.errorOrNull(), WireCategory.CAPTURE)
            return encodePhoto(photo, format)
        } finally {
            captureInFlight = false
        }
    }

    private fun encodePhoto(photo: PhotoData, format: String): Pair<ByteArray, String> = when (photo) {
        is PhotoData.HEIC -> {
            val bytes = ByteArray(photo.data.remaining()).also { photo.data.duplicate().get(it) }
            if (format == "heic") {
                bytes to "heic"
            } else {
                val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: return bytes to "heic"
                compress(decoded, CompressFormat.JPEG) to "jpeg"
            }
        }
        is PhotoData.Bitmap -> {
            // Android has no HEIC encoder in Bitmap.compress; HEIC requests
            // fall back to JPEG and report the actual format.
            compress(photo.bitmap, CompressFormat.JPEG) to "jpeg"
        }
    }

    private fun compress(bitmap: Bitmap, format: CompressFormat): ByteArray =
        ByteArrayOutputStream().use { out ->
            bitmap.compress(format, 95, out)
            out.toByteArray()
        }

    // --- Experimental high-resolution photo (Camera.photo) --------------------------

    suspend fun captureHqPhoto(resolution: String?, quality: String?): PhotoCaptureData {
        val cam = camera ?: throw WireError(
            WireCategory.PHOTO, "notReady", "No active camera. Call startStreamSession first.",
        )
        if (hqCaptureInFlight) {
            throw WireError(WireCategory.PHOTO, "busy", "A high-resolution capture is already in progress.")
        }
        hqCaptureInFlight = true
        try {
            val photo = cam.photo
            if (photoJobs.isEmpty()) subscribe(photo)
            withTimeoutOrNull(10_000) { photo.state.first { it == PhotoState.STARTED } }
            val res = WireCodec.parse<PhotoResolution>(resolution) ?: PhotoResolution.MEDIUM
            val qual = WireCodec.parse<PhotoQuality>(quality) ?: PhotoQuality.MEDIUM
            return coroutineScope {
                val data = async { photo.photoStream.first() }
                val failure = async { photo.errors.first() }
                photo.capturePhoto(res, qual)
                val outcome = withTimeoutOrNull(HQ_PHOTO_TIMEOUT_MS) {
                    select<Any> {
                        data.onAwait { it }
                        failure.onAwait { it }
                    }
                }
                data.cancel()
                failure.cancel()
                when (outcome) {
                    is PhotoCaptureData -> outcome
                    null -> throw WireError(
                        WireCategory.PHOTO, "timeout",
                        "No photo arrived within ${HQ_PHOTO_TIMEOUT_MS / 1000} s.",
                    )
                    else -> throw WireCodec.from(outcome, WireCategory.PHOTO)
                }
            }
        } finally {
            hqCaptureInFlight = false
        }
    }

    private fun subscribe(photo: Photo) {
        photoJobs += scope.launch { photo.state.collect { photoStateSink.send(WireCodec.state(it)) } }
        photoJobs += scope.launch {
            photo.transferProgressStream.collect {
                photoProgressSink.send(mapOf("bytesReceived" to it.bytesReceived, "totalBytes" to it.totalBytes))
            }
        }
        photoJobs += scope.launch {
            photo.errors.collect { photoErrorSink.send(WireCodec.from(it, WireCategory.PHOTO).eventPayload) }
        }
        ResourceLedger.acquire(ResourceLedger.Kind.LISTENERS, 3)
    }
}
