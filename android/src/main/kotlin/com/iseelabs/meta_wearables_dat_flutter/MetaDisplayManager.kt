// Display bridge (DAT 1.0 mwdat-display).
//
// start: hub.acquire(requireDisplay) -> session.addDisplay() -> collect
//        display.state -> wait STARTED (Android displays start on add)
// send:  JSON -> DisplayNodeBuilder -> display.sendContent { } (replaces
//        the whole view and every tap handler)
// stop:  cancel collectors -> display.stop() -> session.removeDisplay()
//        -> hub.release

package com.iseelabs.meta_wearables_dat_flutter

import com.meta.wearable.dat.display.Display
import com.meta.wearable.dat.display.addDisplay
import com.meta.wearable.dat.display.removeDisplay
import com.meta.wearable.dat.display.types.DisplayConfiguration
import com.meta.wearable.dat.display.types.DisplayState
import com.meta.wearable.dat.display.types.VideoCodec
import com.meta.wearable.dat.display.types.VideoSource
import com.meta.wearable.dat.display.views.VideoPlayer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

class MetaDisplayManager(
    private val hub: DeviceSessionHub,
    private val scope: CoroutineScope,
) {
    companion object {
        const val OWNER = "display"
        const val START_TIMEOUT_MS = 10_000L
    }

    val stateSink = EventSinkHandler()
    val eventsSink = EventSinkHandler()
    val errorSink = EventSinkHandler()

    private var display: Display? = null
    private var stateJob: Job? = null
    private var player: VideoPlayer? = null
    private val playerJobs = mutableListOf<Job>()
    private var lastState: DisplayState = DisplayState.STOPPED

    init {
        stateSink.onSinkChange = { sink -> sink?.success(WireCodec.displayState(lastState)) }
    }

    val isActive: Boolean get() = display != null

    suspend fun startDisplaySession(deviceUuid: String?) {
        if (display != null) return
        val session = hub.acquire(OWNER, deviceUuid, requireDisplay = true, onTerminated = {
            scope.launch { clear(releaseHub = false) }
        })
        val added = session.addDisplay(DisplayConfiguration())
        val newDisplay = added.getOrNull()
        if (newDisplay == null) {
            hub.release(OWNER)
            throw WireCodec.from(added.errorOrNull(), WireCategory.DEVICE_SESSION)
        }
        display = newDisplay
        ResourceLedger.acquire(ResourceLedger.Kind.DISPLAYS)
        stateJob = scope.launch {
            newDisplay.state.collect { state ->
                lastState = state
                stateSink.send(WireCodec.displayState(state))
                // Back (two-finger temple tap) or the device ended the display.
                if ((state == DisplayState.STOPPED || state == DisplayState.CLOSED) && display === newDisplay) {
                    clear(releaseHub = true)
                }
            }
        }
        ResourceLedger.acquire(ResourceLedger.Kind.LISTENERS)
        val started = withTimeoutOrNull(START_TIMEOUT_MS) {
            newDisplay.state.first { it == DisplayState.STARTED }
        }
        if (started == null) {
            clear(releaseHub = true)
            throw WireError(
                WireCategory.DISPLAY, "timeout",
                "The display did not start within ${START_TIMEOUT_MS / 1000} s.",
            )
        }
    }

    /** Returns build warnings (unsupported values that were substituted). */
    suspend fun sendView(json: Map<*, *>): List<String> {
        val d = display ?: throw WireError(
            WireCategory.DISPLAY, "notStarted", "No display session. Call startDisplaySession first.",
        )
        stopPlayer()
        val builder = DisplayNodeBuilder { id, type ->
            eventsSink.send(mapOf("callbackId" to id, "type" to type))
        }
        val result = if (json["type"] == "videoPlayer") {
            val codec = json["codec"] as? String ?: "mp4"
            if (codec != "mp4") {
                throw WireError(WireCategory.DISPLAY, "unsupportedCodec", "VideoPlayer only supports mp4 (got $codec).")
            }
            val newPlayer = VideoPlayer(VideoSource.Url(json["uri"] as? String ?: ""), VideoCodec.MP4)
            player = newPlayer
            watchPlayer(newPlayer, json["onPlaybackEventId"] as? String)
            d.sendContent { video(newPlayer) }.also { if (it.isSuccess) newPlayer.play() }
        } else {
            d.sendContent { builder.buildRoot(this, json) }
        }
        if (result.isFailure) throw WireCodec.from(result.errorOrNull(), WireCategory.DISPLAY)
        for (warning in builder.warnings) eventsSink.send(mapOf("type" to "warning", "message" to warning))
        return builder.warnings
    }

    suspend fun clearDisplay() {
        val d = display ?: return
        stopPlayer()
        val result = d.clearDisplay()
        if (result.isFailure) throw WireCodec.from(result.errorOrNull(), WireCategory.DISPLAY)
    }

    fun stopVideo() = stopPlayer()

    suspend fun stopDisplaySession() = clear(releaseHub = true)

    private fun watchPlayer(p: VideoPlayer, callbackId: String?) {
        playerJobs += scope.launch {
            p.state.collect { state ->
                val name = WireCodec.playbackEvent(state) ?: return@collect
                callbackId?.let { eventsSink.send(mapOf("callbackId" to it, "type" to "playback", "event" to name)) }
            }
        }
        playerJobs += scope.launch {
            p.error.collect { error ->
                if (error == null) return@collect
                errorSink.send(
                    WireError(
                        WireCategory.DISPLAY, "videoPlaybackFailed", error.description, error.name,
                        mapOf("videoErrorType" to WireCodec.canonical(error.name)),
                    ).eventPayload,
                )
                callbackId?.let { eventsSink.send(mapOf("callbackId" to it, "type" to "playback", "event" to "error")) }
            }
        }
    }

    private fun stopPlayer() {
        playerJobs.forEach { it.cancel() }
        playerJobs.clear()
        player?.close()
        player = null
    }

    private suspend fun clear(releaseHub: Boolean) {
        val d = display
        if (d == null) {
            if (releaseHub) hub.release(OWNER)
            return
        }
        display = null
        stopPlayer()
        stateJob?.cancel()
        stateJob = null
        ResourceLedger.release(ResourceLedger.Kind.LISTENERS)
        try {
            d.stop()
        } catch (_: Throwable) {
        }
        hub.session?.removeDisplay()
        ResourceLedger.release(ResourceLedger.Kind.DISPLAYS)
        if (lastState != DisplayState.STOPPED) {
            lastState = DisplayState.STOPPED
            stateSink.send("stopped")
        }
        if (releaseHub) hub.release(OWNER)
    }
}
