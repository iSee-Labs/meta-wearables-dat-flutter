// Slice 10 - Android Mock Device Kit bridge.
//
// Owns:
//   - The shared `MockDeviceKit.getInstance(context)` handle.
//   - A `MutableMap<String, MockRaybanMeta>` keyed by Dart-visible UUIDs.
//   - The `mock_devices` EventChannel sink (re-emits the paired set on
//     every change).
//
// Mock devices ship from `mwdat-mockdevice` and are intended for
// hardware-less development. Production builds that do not want mock
// device code in the binary should strip the dependency from `build.gradle`
// instead - the plugin returns MOCK_ERRORs cleanly when the kit is not
// linked.

package com.iseelabs.meta_wearables_dat_flutter

import android.content.Context
import android.net.Uri
import com.meta.wearable.dat.mockdevice.MockDeviceKit
import com.meta.wearable.dat.mockdevice.api.MockRaybanMeta
import com.meta.wearable.dat.mockdevice.api.camera.CameraFacing
import io.flutter.plugin.common.EventChannel
import java.util.UUID

internal class MetaMockDeviceManager(context: Context) {

    private val kit: MockDeviceKit = MockDeviceKit.getInstance(context.applicationContext)
    private val devices = LinkedHashMap<String, MockRaybanMeta>()

    private var sink: EventChannel.EventSink? = null

    fun setMockDevicesSink(sink: EventChannel.EventSink?) {
        this.sink = sink
        emitDevices()
    }

    fun enable() {
        kit.enable()
        emitDevices()
    }

    fun disable() {
        kit.disable()
        devices.clear()
        emitDevices()
    }

    /** Pairs a fresh mock Ray-Ban Meta device and returns its plugin uuid. */
    fun pairRayBanMeta(): String {
        val mock = kit.pairRaybanMeta()
        val uuid = UUID.randomUUID().toString()
        devices[uuid] = mock
        emitDevices()
        return uuid
    }

    fun unpair(uuid: String) {
        val mock = devices.remove(uuid) ?: error("Mock device not found: $uuid")
        kit.unpairDevice(mock)
        emitDevices()
    }

    fun powerOn(uuid: String) {
        device(uuid).powerOn()
    }

    fun don(uuid: String) {
        device(uuid).don()
    }

    fun setCameraFacing(uuid: String, facing: String) {
        val mapped = when (facing.lowercase()) {
            "front" -> CameraFacing.FRONT
            else -> CameraFacing.REAR
        }
        device(uuid).services.camera.setCameraFeed(mapped)
    }

    fun setCameraFeed(uuid: String, filePath: String) {
        device(uuid).services.camera.setCameraFeed(Uri.parse("file://$filePath"))
    }

    fun setCapturedImage(uuid: String, filePath: String) {
        device(uuid).services.camera.setCapturedImage(Uri.parse("file://$filePath"))
    }

    private fun device(uuid: String): MockRaybanMeta {
        return devices[uuid] ?: error("Mock device not found: $uuid")
    }

    private fun emitDevices() {
        val snapshot = devices.keys.map { uuid ->
            mapOf(
                "uuid" to uuid,
                "name" to "Mock Ray-Ban Meta",
                "kind" to "rayBanMeta",
            )
        }
        sink?.success(snapshot)
    }
}
