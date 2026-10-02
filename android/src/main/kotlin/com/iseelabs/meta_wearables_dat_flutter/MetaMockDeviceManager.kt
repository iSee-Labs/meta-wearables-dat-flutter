// Mock Device Kit bridge (DAT 1.0 mwdat-mockdevice).
//
// Simulates glasses so host apps can develop and test without hardware.
// Mock devices appear in `devices` only after powerOn() + unfold().
// Camera feed files must be H.265; the phone-camera feed needs the host's
// runtime CAMERA permission.

package com.iseelabs.meta_wearables_dat_flutter

import android.content.Context
import android.net.Uri
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.types.ChargingState
import com.meta.wearable.dat.core.types.DeviceIdentifier
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import com.meta.wearable.dat.core.types.ThermalLevel
import com.meta.wearable.dat.mockdevice.MockDeviceKit
import com.meta.wearable.dat.mockdevice.api.GlassesModel
import com.meta.wearable.dat.mockdevice.api.MockDeviceKitConfig
import com.meta.wearable.dat.mockdevice.api.MockDeviceKitInterface
import com.meta.wearable.dat.mockdevice.api.MockGlasses
import com.meta.wearable.dat.mockdevice.api.camera.CameraFacing
import java.io.File

class MetaMockDeviceManager(context: Context, private val experimental: ExperimentalCapabilities) {
    private val kit: MockDeviceKitInterface = MockDeviceKit.getInstance(context)
    private var config = MockDeviceKitConfig()
    private val models = mutableMapOf<String, GlassesModel>()

    val devicesSink = EventSinkHandler().apply {
        onSinkChange = { sink -> sink?.success(pairedDevices()) }
    }

    val isEnabled: Boolean get() = kit.isEnabled

    fun enable(initiallyRegistered: Boolean, initialPermissionsGranted: Boolean) {
        config = MockDeviceKitConfig(initiallyRegistered, initialPermissionsGranted)
        if (kit.isEnabled) kit.disable()
        kit.enable(config)
        models.clear()
        syncLedger()
        emit()
    }

    fun disable() {
        if (kit.isEnabled) kit.disable()
        models.clear()
        syncLedger()
        emit()
    }

    fun pair(modelName: String?): Map<String, Any?> {
        val model = WireCodec.parse<GlassesModel>(
            modelName ?: "rayBanMeta",
            "rayBanMeta" to GlassesModel.RAYBAN_META,
            "rayBanMetaOptics" to GlassesModel.RAYBAN_META_OPTICS,
            "metaRayBanDisplay" to GlassesModel.META_RAYBAN_DISPLAY,
            "oakleyMetaHSTN" to GlassesModel.OAKLEY_META_HSTN,
            "oakleyMetaHstn" to GlassesModel.OAKLEY_META_HSTN,
        ) ?: throw WireError.invalidArgument("Unknown glasses model '$modelName'.")
        if (!kit.isEnabled) kit.enable(config)
        val result = kit.pairGlasses(model)
        val glasses = result.getOrNull() ?: throw WireCodec.from(result.errorOrNull(), WireCategory.MOCK)
        models[glasses.deviceIdentifier.identifier] = model
        syncLedger()
        emit()
        return encode(glasses)
    }

    fun unpair(uuid: String) {
        kit.unpairDevice(glasses(uuid))
        models.remove(uuid)
        syncLedger()
        emit()
    }

    fun pairedDevices(): List<Map<String, Any?>> =
        if (kit.isEnabled) kit.pairedDevices.filterIsInstance<MockGlasses>().map { encode(it) } else emptyList()

    fun perform(action: String, uuid: String) {
        val g = glasses(uuid)
        when (action) {
            "mockPowerOn" -> g.powerOn()
            "mockPowerOff" -> g.powerOff()
            "mockDon" -> g.don()
            "mockDoff" -> g.doff()
            "mockFold" -> g.fold()
            "mockUnfold" -> g.unfold()
            "mockCaptouchTap" -> g.services.captouch.tap()
            "mockCaptouchTapAndHold" -> g.services.captouch.tapAndHold()
            else -> throw WireError.invalidArgument("Unknown mock action $action.")
        }
        emit()
    }

    fun setBatteryLevel(uuid: String, level: Int?) {
        if (level != null && level !in 0..100) {
            throw WireError.invalidArgument("Battery level must be between 0 and 100 (got $level).")
        }
        // Android uses 0 for "unknown".
        glasses(uuid).setBatteryLevel(level ?: 0)
    }

    fun setChargingState(uuid: String, raw: String?) {
        val state = WireCodec.parse<ChargingState>(raw)
            ?: throw WireError.invalidArgument("Unknown charging state '$raw'.")
        glasses(uuid).setChargingState(state)
    }

    fun setThermalLevel(uuid: String, raw: String?) {
        val level = WireCodec.parse<ThermalLevel>(raw)
            ?: throw WireError.invalidArgument("Unknown thermal level '$raw'.")
        glasses(uuid).setThermalLevel(level)
    }

    fun setPermission(permission: String?, status: String?, requestResult: Boolean) {
        val perm = WireCodec.parse<Permission>(permission)
            ?: throw WireError.invalidArgument("Unknown permission '$permission'.")
        val st = when (status) {
            "granted" -> PermissionStatus.Granted
            "denied" -> PermissionStatus.Denied
            else -> throw WireError.invalidArgument("Unknown permission status '$status'.")
        }
        if (!kit.isEnabled) kit.enable(config)
        if (requestResult) kit.permissions.setRequestResult(perm, st) else kit.permissions.set(perm, st)
    }

    fun setCameraFacing(uuid: String, facing: String?) {
        glasses(uuid).services.camera.setCameraFeed(if (facing == "front") CameraFacing.FRONT else CameraFacing.BACK)
    }

    fun setCameraFeed(uuid: String, path: String?) = glasses(uuid).services.camera.setCameraFeed(uri(path))

    fun setCapturedImage(uuid: String, path: String?) = glasses(uuid).services.camera.setCapturedImage(uri(path))

    fun setCapturedPhoto(uuid: String, path: String?) =
        glasses(uuid).services.cameraCapture.setCapturedPhoto(uri(path))

    fun simulateCaptureFailure(uuid: String) = glasses(uuid).services.cameraCapture.simulateCaptureFailure()

    fun input(uuid: String, args: Map<*, *>) = experimental.mockInput(glasses(uuid), args)

    fun speech(uuid: String, args: Map<*, *>) {
        val speech = glasses(uuid).services.speech
        when (args["action"]) {
            "source" -> speech.setTranscriptionSource(
                if (args["source"] == "liveDeviceAsr") {
                    com.meta.wearable.dat.mockdevice.api.speech.MockSpeechSource.LIVE_DEVICE_ASR
                } else {
                    com.meta.wearable.dat.mockdevice.api.speech.MockSpeechSource.INJECTED
                },
            )
            "transcription" -> speech.simulateTranscription(
                args["text"] as? String ?: "",
                args["isFinal"] as? Boolean ?: true,
                (args["confidence"] as? Number)?.toFloat() ?: 1f,
            )
            "error" -> speech.simulateError((args["errorCode"] as? Number)?.toInt() ?: 0, args["message"] as? String ?: "")
            "completion" -> speech.simulateCompletion()
            "locale" -> speech.setLocale(args["locale"] as? String ?: "en-US")
            else -> throw WireError.invalidArgument("Unknown speech action '${args["action"]}'.")
        }
    }

    fun setMotionFeed(uuid: String, args: Map<*, *>) = experimental.mockMotionFeed(glasses(uuid), args, ::uri)

    fun voice(uuid: String, incomplete: Boolean): String? {
        val voice = glasses(uuid).services.voiceInvocation
        return if (incomplete) voice.simulateIncompleteAction() else voice.simulateLaunchAppAction()
    }

    fun sendDisplayClick(uuid: String, identifier: String): Boolean =
        glasses(uuid).services.display.sendClick(identifier)

    fun startTestServer(port: Int): Int {
        if (!kit.isEnabled) kit.enable(config)
        val result = kit.startTestServer(port)
        return result.getOrNull() ?: throw WireCodec.from(result.errorOrNull(), WireCategory.MOCK)
    }

    fun stopTestServer() = kit.stopTestServer()

    // --- Helpers -------------------------------------------------------------------

    private fun glasses(uuid: String): MockGlasses {
        if (!kit.isEnabled) {
            throw WireError(WireCategory.MOCK, "notEnabled", "Mock Device Kit is not enabled.")
        }
        val device = kit.pairedDevices.firstOrNull { it.deviceIdentifier.identifier == uuid }
            ?: throw WireError(WireCategory.MOCK, "deviceNotFound", "No paired mock device $uuid.")
        return device as? MockGlasses
            ?: throw WireError(WireCategory.MOCK, "wrongDeviceKind", "Mock device $uuid is not a pair of glasses.")
    }

    private fun uri(path: String?): Uri {
        if (path.isNullOrEmpty()) throw WireError.invalidArgument("filePath is required.")
        val file = File(path)
        if (!file.exists()) throw WireError.invalidArgument("File not found: $path")
        return Uri.fromFile(file)
    }

    private fun encode(glasses: MockGlasses): Map<String, Any?> {
        val id = glasses.deviceIdentifier.identifier
        val metadata = Wearables.devicesMetadata[DeviceIdentifier(id)]?.value
        val map = WireCodec.device(id, metadata).toMutableMap()
        models[id]?.let { model ->
            map["model"] = WireCodec.canonical(model)
            if (map["deviceType"] == "unknown") map["deviceType"] = WireCodec.canonical(model)
        }
        map["isMock"] = true
        return map
    }

    private fun emit() = devicesSink.send(pairedDevices())

    private fun syncLedger() =
        ResourceLedger.set(ResourceLedger.Kind.MOCK_DEVICES, if (kit.isEnabled) kit.pairedDevices.size else 0)
}
