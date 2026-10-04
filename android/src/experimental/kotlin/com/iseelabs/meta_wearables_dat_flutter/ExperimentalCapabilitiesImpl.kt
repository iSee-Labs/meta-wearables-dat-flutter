// Real bridges for the experimental DAT 1.0 modules. Inputs, Motion and
// Speech attach to the shared DeviceSession through DeviceSessionHub.

package com.iseelabs.meta_wearables_dat_flutter

import android.net.Uri
import com.meta.wearable.dat.inputs.Inputs
import com.meta.wearable.dat.inputs.addInputs
import com.meta.wearable.dat.inputs.removeInputs
import com.meta.wearable.dat.inputs.types.ButtonType
import com.meta.wearable.dat.inputs.types.CapturePressType
import com.meta.wearable.dat.inputs.types.DragAction
import com.meta.wearable.dat.inputs.types.InputEvent
import com.meta.wearable.dat.inputs.types.InputSource
import com.meta.wearable.dat.inputs.types.InputsConfiguration
import com.meta.wearable.dat.mockdevice.api.MockGlasses
import com.meta.wearable.dat.motion.Motion
import com.meta.wearable.dat.motion.addMotion
import com.meta.wearable.dat.motion.removeMotion
import com.meta.wearable.dat.motion.types.MotionConfiguration
import com.meta.wearable.dat.motion.types.MotionSample
import com.meta.wearable.dat.motion.types.MotionSamplingRate
import com.meta.wearable.dat.motion.types.MotionSource
import com.meta.wearable.dat.motion.types.Quaternion
import com.meta.wearable.dat.motion.types.Vector3
import com.meta.wearable.dat.speech.Speech
import com.meta.wearable.dat.speech.SpeechConfiguration
import com.meta.wearable.dat.speech.addSpeech
import com.meta.wearable.dat.speech.removeSpeech
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

fun createExperimentalCapabilities(hub: DeviceSessionHub, scope: CoroutineScope): ExperimentalCapabilities =
    ExperimentalCapabilitiesImpl(hub, scope)

private class ExperimentalCapabilitiesImpl(
    private val hub: DeviceSessionHub,
    private val scope: CoroutineScope,
) : ExperimentalCapabilities {
    override val linked = true
    override val inputsState = EventSinkHandler(replaysLast = true)
    override val inputsEvents = EventSinkHandler()
    override val inputsErrors = EventSinkHandler()
    override val motionState = EventSinkHandler(replaysLast = true)
    override val motionSamples = EventSinkHandler()
    override val motionErrors = EventSinkHandler()
    override val speechState = EventSinkHandler(replaysLast = true)
    override val speechTranscriptions = EventSinkHandler()
    override val speechErrors = EventSinkHandler()

    private var inputs: Inputs? = null
    private var motion: Motion? = null
    private var speech: Speech? = null
    private val inputJobs = mutableListOf<Job>()
    private val motionJobs = mutableListOf<Job>()
    private val speechJobs = mutableListOf<Job>()

    // --- Inputs ------------------------------------------------------------------

    override suspend fun startInputs(args: Map<*, *>) {
        if (inputs != null) return
        val session = hub.acquire(OWNER_INPUTS, args["deviceUuid"] as? String, onTerminated = {
            scope.launch { clearInputs(release = false) }
        })
        val sources = (args["sources"] as? List<*>)?.mapNotNull { WireCodec.parse<InputSource>(it as? String) }
            ?.toSet()
        val consumeBack = args["consumeBack"] as? Boolean ?: true
        val config = if (sources.isNullOrEmpty()) {
            InputsConfiguration(InputsConfiguration().sources, consumeBack)
        } else {
            InputsConfiguration(sources, consumeBack)
        }
        val added = session.addInputs(config)
        val capability = added.getOrNull()
        if (capability == null) {
            hub.release(OWNER_INPUTS)
            throw WireCodec.from(added.errorOrNull(), WireCategory.INPUTS)
        }
        inputs = capability
        ResourceLedger.acquire(ResourceLedger.Kind.CAPABILITIES)
        inputJobs += scope.launch { capability.state.collect { inputsState.send(WireCodec.state(it)) } }
        inputJobs += scope.launch {
            capability.errors.collect { error ->
                if (error != null) inputsErrors.send(WireCodec.error(WireCategory.INPUTS, error).eventPayload)
            }
        }
        inputJobs += scope.launch { capability.events.collect { inputsEvents.send(encode(it)) } }
    }

    override suspend fun stopInputs() = clearInputs(release = true)

    private suspend fun clearInputs(release: Boolean) {
        if (inputs == null) return
        inputs = null
        inputJobs.forEach { it.cancel() }
        inputJobs.clear()
        hub.session?.removeInputs()
        ResourceLedger.release(ResourceLedger.Kind.CAPABILITIES)
        inputsState.send("inactive")
        if (release) hub.release(OWNER_INPUTS)
    }

    private fun encode(event: InputEvent): Map<String, Any?> = when (event) {
        is InputEvent.Nav -> base("nav", event.source, event.timestampMs) +
            ("direction" to WireCodec.canonical(event.direction))
        is InputEvent.Select -> base("select", event.source, event.timestampMs)
        is InputEvent.Back -> base("back", event.source, event.timestampMs)
        is InputEvent.Button -> base("button", event.source, event.timestampMs) +
            ("buttonType" to WireCodec.canonical(event.button))
        is InputEvent.Capture -> base("capture", event.source, event.timestampMs) +
            ("pressType" to WireCodec.canonical(event.pressType))
        is InputEvent.Drag -> base("drag", event.source, event.timestampMs) + mapOf(
            "dragAction" to WireCodec.canonical(event.action),
            "x" to event.x.toDouble(),
            "y" to event.y.toDouble(),
            "dx" to event.dx.toDouble(),
            "dy" to event.dy.toDouble(),
        )
    }

    private fun base(type: String, source: InputSource, timestampMs: Long): Map<String, Any?> =
        mapOf("type" to type, "source" to WireCodec.canonical(source), "timestampMs" to timestampMs)

    // --- Motion ------------------------------------------------------------------

    override suspend fun startMotion(args: Map<*, *>) {
        if (motion != null) return
        val session = hub.acquire(OWNER_MOTION, args["deviceUuid"] as? String, onTerminated = {
            scope.launch { clearMotion(release = false) }
        })
        val rate = when ((args["samplingRate"] as? Number)?.toInt()) {
            5 -> MotionSamplingRate.HZ_5
            15 -> MotionSamplingRate.HZ_15
            24 -> MotionSamplingRate.HZ_24
            30 -> MotionSamplingRate.HZ_30
            60 -> MotionSamplingRate.HZ_60
            else -> MotionSamplingRate.HZ_10
        }
        val added = session.addMotion(MotionConfiguration(rate))
        val capability = added.getOrNull()
        if (capability == null) {
            hub.release(OWNER_MOTION)
            throw WireCodec.from(added.errorOrNull(), WireCategory.MOTION)
        }
        motion = capability
        ResourceLedger.acquire(ResourceLedger.Kind.CAPABILITIES)
        motionJobs += scope.launch { capability.state.collect { motionState.send(WireCodec.state(it)) } }
        motionJobs += scope.launch {
            capability.errors.collect { error ->
                if (error != null) motionErrors.send(WireCodec.error(WireCategory.MOTION, error).eventPayload)
            }
        }
        motionJobs += scope.launch {
            capability.samples.collect { if (motionSamples.hasListener) motionSamples.send(encode(it)) }
        }
        capability.start()
    }

    override suspend fun stopMotion() = clearMotion(release = true)

    private suspend fun clearMotion(release: Boolean) {
        val m = motion ?: return
        motion = null
        motionJobs.forEach { it.cancel() }
        motionJobs.clear()
        m.stop()
        hub.session?.removeMotion()
        ResourceLedger.release(ResourceLedger.Kind.CAPABILITIES)
        motionState.send("stopped")
        if (release) hub.release(OWNER_MOTION)
    }

    private fun encode(sample: MotionSample): Map<String, Any?> = buildMap {
        put("timestampNs", sample.timestampNs)
        sample.accelerometer?.let { put("accelerometer", vec(it)) }
        sample.gyroscope?.let { put("gyroscope", vec(it)) }
        sample.magnetometer?.let { put("magnetometer", vec(it)) }
        sample.orientation?.let {
            put("orientation", mapOf("x" to it.x.toDouble(), "y" to it.y.toDouble(), "z" to it.z.toDouble(), "w" to it.w.toDouble()))
        }
        put("source", WireCodec.canonical(sample.source))
    }

    private fun vec(v: Vector3) = mapOf("x" to v.x.toDouble(), "y" to v.y.toDouble(), "z" to v.z.toDouble())

    // --- Speech ------------------------------------------------------------------

    override suspend fun startSpeech(args: Map<*, *>) {
        if (speech != null) return
        val session = hub.acquire(OWNER_SPEECH, args["deviceUuid"] as? String, onTerminated = {
            scope.launch { clearSpeech(release = false) }
        })
        val added = session.addSpeech(SpeechConfiguration())
        val capability = added.getOrNull()
        if (capability == null) {
            hub.release(OWNER_SPEECH)
            throw WireCodec.from(added.errorOrNull(), WireCategory.SPEECH)
        }
        speech = capability
        ResourceLedger.acquire(ResourceLedger.Kind.CAPABILITIES)
        speechJobs += scope.launch { capability.state.collect { speechState.send(WireCodec.state(it)) } }
        speechJobs += scope.launch {
            capability.errors.collect { error ->
                if (error != null) speechErrors.send(WireCodec.error(WireCategory.SPEECH, error).eventPayload)
            }
        }
        speechJobs += scope.launch {
            capability.transcriptions.collect { result ->
                if (result != null) {
                    speechTranscriptions.send(
                        mapOf("text" to result.text, "isFinal" to result.isFinal, "confidence" to result.confidence.toDouble()),
                    )
                }
            }
        }
        val started = capability.start()
        if (started.isFailure) {
            val error = WireCodec.from(started.errorOrNull(), WireCategory.SPEECH)
            clearSpeech(release = true)
            throw error
        }
    }

    override suspend fun stopSpeech() = clearSpeech(release = true)

    private suspend fun clearSpeech(release: Boolean) {
        val s = speech ?: return
        speech = null
        speechJobs.forEach { it.cancel() }
        speechJobs.clear()
        s.stop()
        hub.session?.removeSpeech()
        ResourceLedger.release(ResourceLedger.Kind.CAPABILITIES)
        speechState.send("stopped")
        if (release) hub.release(OWNER_SPEECH)
    }

    // --- Mock services -------------------------------------------------------------

    override fun mockInput(glasses: MockGlasses, args: Map<*, *>) {
        val input = glasses.services.input
        val source = WireCodec.parse<InputSource>(args["source"] as? String) ?: InputSource.CAPTOUCH
        when (args["action"]) {
            "navUp" -> input.navUp(source)
            "navDown" -> input.navDown(source)
            "navLeft" -> input.navLeft(source)
            "navRight" -> input.navRight(source)
            "select" -> input.select(source)
            "back" -> input.back(source)
            "capture" -> input.capture(WireCodec.parse<CapturePressType>(args["pressType"] as? String) ?: CapturePressType.SHORT_PRESS)
            "button" -> input.button(ButtonType.ACTION)
            "drag" -> input.drag(
                WireCodec.parse<DragAction>(args["dragAction"] as? String) ?: DragAction.MOVE,
                (args["x"] as? Number)?.toFloat() ?: 0f,
                (args["y"] as? Number)?.toFloat() ?: 0f,
                (args["dx"] as? Number)?.toFloat() ?: 0f,
                (args["dy"] as? Number)?.toFloat() ?: 0f,
            )
            else -> throw WireError.invalidArgument("Unknown input action '${args["action"]}'.")
        }
    }

    override fun mockMotionFeed(glasses: MockGlasses, args: Map<*, *>, uri: (String?) -> Uri) {
        val motion = glasses.services.motion
        val path = args["filePath"] as? String
        if (path != null) {
            motion.setMotionFeed(uri(path))
            return
        }
        val samples = (args["samples"] as? List<*> ?: emptyList<Any>()).mapNotNull { raw ->
            val map = raw as? Map<*, *> ?: return@mapNotNull null
            MotionSample(
                (map["timestampNs"] as? Number)?.toLong() ?: 0L,
                vector(map["accelerometer"]),
                vector(map["gyroscope"]),
                vector(map["magnetometer"]),
                quaternion(map["orientation"]),
                if (map["source"] == "neuralBand") MotionSource.NEURAL_BAND else MotionSource.GLASSES,
            )
        }
        motion.setMotionFeed(samples, args["loop"] as? Boolean ?: true)
    }

    private fun vector(value: Any?): Vector3? {
        val m = value as? Map<*, *> ?: return null
        return Vector3(f(m["x"]), f(m["y"]), f(m["z"]))
    }

    private fun quaternion(value: Any?): Quaternion? {
        val m = value as? Map<*, *> ?: return null
        return Quaternion(f(m["x"]), f(m["y"]), f(m["z"]), (m["w"] as? Number)?.toFloat() ?: 1f)
    }

    private fun f(value: Any?): Float = (value as? Number)?.toFloat() ?: 0f

    companion object {
        const val OWNER_INPUTS = "inputs"
        const val OWNER_MOTION = "motion"
        const val OWNER_SPEECH = "speech"
    }
}
