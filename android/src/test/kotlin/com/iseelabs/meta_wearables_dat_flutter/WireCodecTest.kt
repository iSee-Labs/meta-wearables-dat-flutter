package com.iseelabs.meta_wearables_dat_flutter

import com.meta.wearable.dat.camera.types.StreamError
import com.meta.wearable.dat.camera.types.StreamState
import com.meta.wearable.dat.core.registration.RegistrationRequestError
import com.meta.wearable.dat.core.session.DeviceSessionState
import com.meta.wearable.dat.core.types.ChargingState
import com.meta.wearable.dat.core.types.DeviceCompatibility
import com.meta.wearable.dat.core.types.DeviceSessionError
import com.meta.wearable.dat.core.types.DeviceType
import com.meta.wearable.dat.core.types.DonState
import com.meta.wearable.dat.core.types.HingeState
import com.meta.wearable.dat.core.types.LinkState
import com.meta.wearable.dat.core.types.PermissionError
import com.meta.wearable.dat.core.types.RegistrationError
import com.meta.wearable.dat.core.types.RegistrationState
import com.meta.wearable.dat.core.types.ThermalLevel
import com.meta.wearable.dat.display.types.DisplayError
import com.meta.wearable.dat.display.types.DisplayState
import com.meta.wearable.dat.display.views.IconName
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WireCodecTest {
    // The canonical (iOS) case names, mirrored in lib/src/models/*.dart.
    private val deviceSessionCases = setOf(
        "noEligibleDevice", "sessionAlreadyStopped", "sessionAlreadyExists", "sessionIdle",
        "capabilityAlreadyActive", "capabilityNotFound", "capabilityDenied", "deviceDisconnected",
        "sessionEndedByDevice", "unexpectedError", "thermalCritical", "thermalEmergency",
        "peakPowerShutdown", "batteryCritical", "datAppOnTheGlassesUpdateRequired", "dwaUnavailable",
        "insufficientSDKVersion", "dwaOutOfStuRange",
    )
    private val streamCases = setOf(
        "videoStreamingError", "hingesClosed", "permissionDenied", "thermalHot", "batteryLow",
        "peakPowerLimit", "timeout",
    )

    @Test
    fun everyDeviceSessionErrorHasACanonicalName() {
        for (e in DeviceSessionError.values()) {
            val wire = WireCodec.error(WireCategory.DEVICE_SESSION, e)
            assertTrue("${e.name} -> ${wire.caseName}", wire.caseName in deviceSessionCases)
            assertEquals(e.name, wire.platformCase)
        }
        assertEquals(true, WireCodec.error(WireCategory.DEVICE_SESSION, DeviceSessionError.INSUFFICIENT_SDK_VERSION).extras["terminal"])
        assertEquals("warning", WireCodec.error(WireCategory.DEVICE_SESSION, DeviceSessionError.DWA_OUT_OF_STU_RANGE).extras["severity"])
    }

    @Test
    fun everyStreamErrorHasACanonicalName() {
        for (e in StreamError.values()) {
            assertTrue(e.name, WireCodec.error(WireCategory.STREAM, e).caseName in streamCases)
        }
        assertEquals(true, WireCodec.error(WireCategory.STREAM, StreamError.CRITICAL_STREAM_ERROR).extras["fatal"])
    }

    @Test
    fun registrationAndPermissionErrorsUseIosSpelling() {
        assertEquals("metaAINotInstalled", WireCodec.error(WireCategory.PERMISSION, PermissionError.META_AI_NOT_INSTALLED).caseName)
        assertEquals("alreadyUnregistered", WireCodec.registrationError(RegistrationError.ALREADY_UNREGISTERED, true).caseName)
        assertEquals(WireCategory.UNREGISTRATION, WireCodec.registrationError(RegistrationError.ALREADY_UNREGISTERED, true).category)
        for (e in RegistrationRequestError.values()) {
            assertTrue(WireCodec.error(WireCategory.REGISTRATION_REQUEST, e).caseName.first().isLowerCase())
        }
        for (e in DisplayError.values()) {
            assertTrue(WireCodec.error(WireCategory.DISPLAY, e).caseName.first().isLowerCase())
        }
    }

    @Test
    fun statesMapToTheSharedWireNames() {
        assertEquals(
            listOf("unavailable", "available", "unregistering", "registered", "registering"),
            RegistrationState.values().map { WireCodec.state(it) },
        )
        assertEquals(
            listOf("idle", "starting", "started", "paused", "stopping", "stopped"),
            DeviceSessionState.values().map { WireCodec.state(it) },
        )
        assertEquals("starting", WireCodec.streamState(StreamState.STARTED))
        assertEquals("stopped", WireCodec.streamState(StreamState.CLOSED))
        assertEquals("streaming", WireCodec.streamState(StreamState.STREAMING))
        assertEquals("stopped", WireCodec.displayState(DisplayState.CLOSED))
    }

    @Test
    fun deviceEnumsMatchDart() {
        assertEquals(
            setOf("unknown", "rayBanMeta", "oakleyMetaHSTN", "oakleyMetaVanguard", "metaRayBanDisplay", "rayBanMetaOptics", "metaGlasses"),
            DeviceType.values().map { WireCodec.deviceType(it) }.toSet(),
        )
        assertEquals(setOf("unknown", "compatible", "deviceUpdateRequired", "sdkUpdateRequired"), DeviceCompatibility.values().map { WireCodec.canonical(it) }.toSet())
        assertEquals(setOf("disconnected", "connecting", "connected"), LinkState.values().map { WireCodec.canonical(it) }.toSet())
        assertEquals(setOf("unknown", "charging", "notCharging"), ChargingState.values().map { WireCodec.canonical(it) }.toSet())
        assertEquals(setOf("unknown", "doffed", "donned"), DonState.values().map { WireCodec.canonical(it) }.toSet())
        assertEquals(setOf("unknown", "closed", "open"), HingeState.values().map { WireCodec.canonical(it) }.toSet())
        assertEquals(8, ThermalLevel.values().map { WireCodec.canonical(it) }.toSet().size)
    }

    @Test
    fun parseRoundTripsWireNames() {
        assertEquals(ThermalLevel.SEVERE, WireCodec.parse<ThermalLevel>("severe"))
        assertEquals(ChargingState.NOT_CHARGING, WireCodec.parse<ChargingState>("notCharging"))
        assertEquals(null, WireCodec.parse<ThermalLevel>("bogus"))
    }

    @Test
    fun everyDartIconNameResolvesToAnAndroidIcon() {
        val json = java.io.File("../tool/display_icons.json").readText()
        val names = Regex("\"([a-zA-Z0-9]+)\"").findAll(json.substringAfter("\"icons\"")).map { it.groupValues[1] }.toList()
        assertEquals(116, names.size)
        for (name in names) {
            val match = IconName.values().firstOrNull { it.name == WireCodec.screaming(name) }
                ?: IconName.values().firstOrNull { WireCodec.camel(it.name) == name }
            assertTrue("no Android icon for $name", match != null)
        }
    }
}
