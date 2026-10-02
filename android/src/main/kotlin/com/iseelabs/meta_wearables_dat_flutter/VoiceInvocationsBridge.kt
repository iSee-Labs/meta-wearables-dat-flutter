// Experimental "Hey Meta" voice invocations (mwdat-core).
//
// Each LaunchApp invocation is parked under an id and surfaced on
// `voice_invocations`; Dart answers it exactly once with
// respondVoiceInvocation. Unanswered invocations are failed on stop so the
// glasses are not left waiting.

package com.iseelabs.meta_wearables_dat_flutter

import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.meta.wearable.dat.core.selectors.DeviceSelector
import com.meta.wearable.dat.core.selectors.SpecificDeviceSelector
import com.meta.wearable.dat.core.types.DeviceIdentifier
import com.meta.wearable.dat.core.voiceinvocations.VoiceInvocationsStream
import com.meta.wearable.dat.core.voiceinvocations.startVoiceInvocationsStream
import com.meta.wearable.dat.core.voiceinvocations.types.actions.LaunchApp
import com.meta.wearable.dat.core.voiceinvocations.types.actions.ResponseHandle
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class VoiceInvocationsBridge(private val scope: CoroutineScope) {
    val invocationsSink = EventSinkHandler()
    val stateSink = EventSinkHandler(replaysLast = true)
    val errorSink = EventSinkHandler()

    private var stream: VoiceInvocationsStream? = null
    private val jobs = mutableListOf<Job>()
    private val pending = linkedMapOf<String, ResponseHandle>()

    fun start(deviceUuid: String?) {
        if (stream != null) return
        val selector: DeviceSelector =
            if (deviceUuid != null) SpecificDeviceSelector(DeviceIdentifier(deviceUuid)) else AutoDeviceSelector()
        val s = Wearables.startVoiceInvocationsStream(selector, Dispatchers.Default)
        stream = s
        ResourceLedger.acquire(ResourceLedger.Kind.CAPABILITIES)
        jobs += scope.launch { s.state.collect { stateSink.send(WireCodec.state(it)) } }
        jobs += scope.launch {
            s.errors.collect { errorSink.send(WireCodec.error(WireCategory.VOICE_INVOCATION, it).eventPayload) }
        }
        jobs += scope.launch {
            s.invocations.collect { invocation ->
                if (invocation is LaunchApp) {
                    val id = UUID.randomUUID().toString()
                    pending[id] = invocation.responseHandle
                    invocationsSink.send(mapOf("invocationId" to id, "type" to "launchApp", "deviceUuid" to deviceUuid))
                }
            }
        }
    }

    suspend fun stop() {
        val s = stream ?: return
        stream = null
        jobs.forEach { it.cancel() }
        jobs.clear()
        val handles = pending.values.toList()
        pending.clear()
        handles.forEach { runCatching { it.sendFailure(null) } }
        s.close()
        ResourceLedger.release(ResourceLedger.Kind.CAPABILITIES)
        stateSink.send("stopped")
    }

    suspend fun respond(invocationId: String, success: Boolean, actionOutput: String?): Boolean {
        val handle = pending.remove(invocationId) ?: throw WireError(
            WireCategory.VOICE_INVOCATION, "alreadyResponded",
            "Voice invocation $invocationId was already answered.",
        )
        val result = if (success) handle.sendSuccess(actionOutput) else handle.sendFailure(actionOutput)
        return result as? Boolean ?: true
    }
}
