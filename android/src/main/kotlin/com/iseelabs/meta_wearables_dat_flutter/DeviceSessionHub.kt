// Owns the single DeviceSession the plugin keeps open.
//
// DAT 1.0 allows one session per app and device, and Meta's samples attach
// every capability to that one session. Components `acquire` it under an
// owner name and `release` it when they stop; the session stops when the
// last owner releases it. A terminal STOPPED (hinges closed, device gone)
// notifies every owner.

package com.iseelabs.meta_wearables_dat_flutter

import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.SpecificDeviceSelector
import com.meta.wearable.dat.core.session.DeviceSession
import com.meta.wearable.dat.core.session.DeviceSessionState
import com.meta.wearable.dat.core.types.Device
import com.meta.wearable.dat.core.types.DeviceIdentifier
import com.meta.wearable.dat.core.types.DeviceSessionError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

class DeviceSessionHub(private val scope: CoroutineScope) {
    companion object {
        const val START_TIMEOUT_MS = 45_000L
        const val STOP_TIMEOUT_MS = 3_000L
    }

    var session: DeviceSession? = null
        private set
    var deviceId: String? = null
        private set

    private val owners = linkedMapOf<String, () -> Unit>()
    private val jobs = mutableListOf<Job>()
    private var lastError: DeviceSessionError? = null
    private var starting = false

    val stateSink = EventSinkHandler().apply {
        onSinkChange = { sink ->
            sink?.success(WireCodec.state(session?.state?.value ?: DeviceSessionState.IDLE))
        }
    }
    val errorSink = EventSinkHandler()

    fun sessionDevice(): Map<String, Any?>? {
        val s = session ?: return null
        val id = deviceId ?: return null
        return WireCodec.device(id, s.deviceInfo.value)
    }

    suspend fun acquire(
        owner: String,
        deviceUuid: String?,
        deviceKinds: Set<String>? = null,
        requireDisplay: Boolean = false,
        onTerminated: () -> Unit,
    ): DeviceSession {
        val existing = session
        if (existing != null && existing.state.value != DeviceSessionState.STOPPED) {
            if (deviceUuid != null && deviceUuid != deviceId) {
                throw WireError(
                    WireCategory.DEVICE_SESSION, "sessionAlreadyExists",
                    "A session is already open for device $deviceId. Stop it before targeting $deviceUuid.",
                )
            }
            if (requireDisplay && existing.deviceInfo.value.isDisplayCapable().not()) {
                throw WireError(
                    WireCategory.DEVICE_SESSION, "noEligibleDevice",
                    "The open session's device does not support Display.",
                )
            }
            waitForStarted(existing)
            owners[owner] = onTerminated
            return existing
        }
        if (starting) {
            throw WireError(
                WireCategory.DEVICE_SESSION, "sessionAlreadyExists",
                "A device session is already starting.",
            )
        }
        starting = true
        try {
            val id = DeviceRanking.resolve(deviceUuid, deviceKinds, requireDisplay)
            val created = Wearables.createSession(SpecificDeviceSelector(DeviceIdentifier(id)))
            val newSession = created.getOrNull()
                ?: throw WireCodec.from(created.errorOrNull(), WireCategory.DEVICE_SESSION)
            session = newSession
            deviceId = id
            lastError = null
            ResourceLedger.acquire(ResourceLedger.Kind.DEVICE_SESSIONS)
            observe(newSession)
            try {
                newSession.start()
                waitForStarted(newSession)
            } catch (e: Throwable) {
                teardown(newSession, notifyOwners = false)
                throw e
            }
            owners[owner] = onTerminated
            return newSession
        } finally {
            starting = false
        }
    }

    suspend fun release(owner: String) {
        owners.remove(owner)
        val s = session ?: return
        if (owners.isEmpty()) teardown(s, notifyOwners = false)
    }

    suspend fun stopAll() {
        val s = session ?: return
        teardown(s, notifyOwners = true)
    }

    private fun observe(s: DeviceSession) {
        jobs += scope.launch {
            s.state.collect { state ->
                stateSink.send(WireCodec.state(state))
                if (state == DeviceSessionState.STOPPED && session === s && !starting) {
                    teardown(s, notifyOwners = true)
                }
            }
        }
        jobs += scope.launch {
            s.errors.collect { error ->
                lastError = error
                errorSink.send(WireCodec.error(WireCategory.DEVICE_SESSION, error).eventPayload)
            }
        }
        ResourceLedger.acquire(ResourceLedger.Kind.LISTENERS, 2)
    }

    private suspend fun waitForStarted(s: DeviceSession) {
        val state = withTimeoutOrNull(START_TIMEOUT_MS) {
            s.state.first {
                it == DeviceSessionState.STARTED || it == DeviceSessionState.STOPPED
            }
        }
        when (state) {
            DeviceSessionState.STARTED -> return
            DeviceSessionState.STOPPED -> {
                lastError?.let { throw WireCodec.error(WireCategory.DEVICE_SESSION, it) }
                throw WireError(
                    WireCategory.DEVICE_SESSION, "stoppedBeforeStart",
                    "The device session stopped before it started.",
                )
            }
            else -> throw WireError(
                WireCategory.DEVICE_SESSION, "startTimeout",
                "The glasses did not connect within ${START_TIMEOUT_MS / 1000} s. " +
                    "Take them out of the case, put them on and try again.",
            )
        }
    }

    private suspend fun teardown(s: DeviceSession, notifyOwners: Boolean) {
        if (session !== s) return
        val callbacks = if (notifyOwners) owners.values.toList() else emptyList()
        owners.clear()
        session = null
        deviceId = null
        callbacks.forEach { it() }

        if (s.state.value != DeviceSessionState.STOPPED) {
            s.stop()
            withTimeoutOrNull(STOP_TIMEOUT_MS) {
                s.state.first { it == DeviceSessionState.STOPPED }
            }
        }
        val running = jobs.toList()
        jobs.clear()
        running.forEach { it.cancel() }
        ResourceLedger.release(ResourceLedger.Kind.LISTENERS, 2)
        ResourceLedger.release(ResourceLedger.Kind.DEVICE_SESSIONS)
        stateSink.send("stopped")
    }
}

/** Picks the device a session should target. */
object DeviceRanking {
    fun metadata(id: String): Device? =
        Wearables.devicesMetadata[DeviceIdentifier(id)]?.value

    fun pairedIds(): List<String> = Wearables.devices.value.map { it.identifier }

    suspend fun resolve(requested: String?, kinds: Set<String>?, requireDisplay: Boolean): String {
        val ids = pairedIds()
        if (requested != null && requested in ids && metadata(requested) == null) {
            // Metadata can lag the device list briefly after pairing.
            withTimeoutOrNull(2_000) {
                while (metadata(requested) == null) delay(50)
            }
        }
        val candidates = ids.filter { id ->
            val device = metadata(id)
            val kindOk = kinds.isNullOrEmpty() || WireCodec.deviceKind(device?.deviceType) in kinds
            val displayOk = !requireDisplay || device?.isDisplayCapable() == true
            kindOk && displayOk
        }
        if (requested != null) {
            if (requested in candidates) return requested
            throw WireError(
                WireCategory.DEVICE_SESSION, "noEligibleDevice",
                "Device $requested is not paired or does not match the request.",
            )
        }
        return candidates.minByOrNull { rank(it) } ?: throw WireError(
            WireCategory.DEVICE_SESSION, "noEligibleDevice",
            if (requireDisplay) {
                "No display-capable glasses are paired. Pair Meta Ray-Ban Display glasses in the Meta AI app."
            } else {
                "No glasses are paired. Pair your glasses in the Meta AI app, then try again."
            },
        )
    }

    /** Connected and worn first, then connected, then compatible, then any. */
    fun rank(id: String): Int {
        val device = metadata(id) ?: return 4
        val connected = device.linkState.name == "CONNECTED"
        return when {
            connected && device.donState.name == "DONNED" -> 0
            connected -> 1
            device.compatibility.name == "COMPATIBLE" -> 2
            else -> 3
        }
    }
}
