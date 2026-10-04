// Device discovery and live device state.
//
// Collects Wearables.devices and one devicesMetadata[id] StateFlow per
// paired device, and fans snapshots out to the `devices`, `device_state`,
// `compatibility` and `active_device` channels. Collection runs only while
// a channel has a listener and the SDK is initialised.

package com.iseelabs.meta_wearables_dat_flutter

import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class DeviceStateObserver(
    private val scope: CoroutineScope,
    private val initialized: StateFlow<Boolean>,
) {
    val devicesSink = EventSinkHandler()
    val deviceStateSink = EventSinkHandler()
    val compatibilitySink = EventSinkHandler()
    val activeDeviceSink = EventSinkHandler()

    private var devicesJob: Job? = null
    private var activeJob: Job? = null
    private val perDevice = linkedMapOf<String, Job>()
    private val snapshots = linkedMapOf<String, Map<String, Any?>>()

    init {
        devicesSink.onSinkChange = { sink -> changed(); sink?.let { if (devicesJob != null) it.success(allDevices()) } }
        deviceStateSink.onSinkChange = { sink -> changed(); sink?.let { s -> snapshots.values.forEach { s.success(it) } } }
        compatibilitySink.onSinkChange = { sink ->
            changed()
            sink?.let { s ->
                snapshots.forEach { (id, snap) ->
                    s.success(mapOf("deviceUuid" to id, "compatibility" to snap["compatibility"]))
                }
            }
        }
        activeDeviceSink.onSinkChange = { sink -> if (sink != null) startActive() else stopActive() }
    }

    fun allDevices(): List<Map<String, Any?>> {
        if (!initialized.value) return emptyList()
        return DeviceRanking.pairedIds().map { id -> snapshots[id] ?: WireCodec.device(id, DeviceRanking.metadata(id)) }
    }

    fun device(id: String): Map<String, Any?>? {
        if (!initialized.value || id !in DeviceRanking.pairedIds()) return null
        return snapshots[id] ?: WireCodec.device(id, DeviceRanking.metadata(id))
    }

    private val anyListener: Boolean
        get() = devicesSink.hasListener || deviceStateSink.hasListener || compatibilitySink.hasListener

    private fun changed() {
        if (anyListener && devicesJob == null) start()
        if (!anyListener) stop()
    }

    private fun start() {
        devicesJob = scope.launch {
            initialized.first { it }
            Wearables.devices.collect { ids -> sync(ids.map { it.identifier }) }
        }
    }

    private fun stop() {
        devicesJob?.cancel()
        devicesJob = null
        perDevice.values.forEach { it.cancel() }
        ResourceLedger.release(ResourceLedger.Kind.LISTENERS, perDevice.size)
        perDevice.clear()
        snapshots.clear()
    }

    private fun sync(ids: List<String>) {
        val live = ids.toSet()
        perDevice.keys.filter { it !in live }.forEach { id ->
            perDevice.remove(id)?.cancel()
            ResourceLedger.release(ResourceLedger.Kind.LISTENERS)
            snapshots.remove(id)
        }
        for (id in ids) {
            if (perDevice.containsKey(id)) continue
            val flow = Wearables.devicesMetadata.entries.firstOrNull { it.key.identifier == id }?.value
            if (flow == null) {
                snapshots[id] = WireCodec.device(id, null)
                continue
            }
            ResourceLedger.acquire(ResourceLedger.Kind.LISTENERS)
            perDevice[id] = scope.launch {
                flow.collect { device ->
                    val previous = snapshots[id]
                    val snapshot = WireCodec.device(id, device)
                    snapshots[id] = snapshot
                    deviceStateSink.send(snapshot)
                    devicesSink.send(allDevices())
                    if (previous?.get("compatibility") != snapshot["compatibility"]) {
                        compatibilitySink.send(mapOf("deviceUuid" to id, "compatibility" to snapshot["compatibility"]))
                    }
                }
            }
        }
        devicesSink.send(allDevices())
    }

    private fun startActive() {
        stopActive()
        activeJob = scope.launch {
            initialized.first { it }
            AutoDeviceSelector().activeDeviceFlow().collect { id ->
                activeDeviceSink.send(id?.let { device(it.identifier) ?: WireCodec.device(it.identifier, null) })
            }
        }
    }

    private fun stopActive() {
        activeJob?.cancel()
        activeJob = null
    }
}
