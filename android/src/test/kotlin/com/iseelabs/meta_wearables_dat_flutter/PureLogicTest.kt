package com.iseelabs.meta_wearables_dat_flutter

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class PureLogicTest {
    @Test
    fun streamArgsDefaultsAndValidation() {
        val args = StreamSessionArgs.parse(emptyMap<String, Any?>())
        assertEquals(24, args.frameRate)
        assertEquals("medium", args.quality)
        assertFalse(args.compressVideo)
        assertNull(args.audioSampleRate)

        val full = StreamSessionArgs.parse(
            mapOf("fps" to 30, "quality" to "high", "videoCodec" to "hvc1", "deviceKinds" to listOf("rayBanMeta"),
                "audio" to mapOf("sampleRate" to 48000, "channels" to 1)),
        )
        assertTrue(full.compressVideo)
        assertEquals(48000, full.audioSampleRate)
        assertEquals(setOf("rayBanMeta"), full.deviceKinds)

        for (bad in listOf(mapOf("fps" to 60), mapOf("quality" to "ultra"), mapOf("videoCodec" to "h264"),
            mapOf("audio" to mapOf("sampleRate" to 8000)))) {
            try {
                StreamSessionArgs.parse(bad)
                fail("accepted $bad")
            } catch (e: WireError) {
                assertEquals(WireCategory.INVALID_ARGUMENT, e.category)
            }
        }
    }

    @Test
    fun hevcNalParsing() {
        val vps = byteArrayOf(0, 0, 0, 1, (32 shl 1).toByte(), 1)
        val sps = byteArrayOf(0, 0, 0, 1, (33 shl 1).toByte(), 1)
        val pps = byteArrayOf(0, 0, 1, (34 shl 1).toByte(), 1)
        val idr = byteArrayOf(0, 0, 0, 1, (19 shl 1).toByte(), 1, 2, 3)
        val trail = byteArrayOf(0, 0, 0, 1, (1 shl 1).toByte(), 9)
        val config = vps + sps + pps
        assertEquals(listOf(32, 33, 34), HevcNal.nalTypes(config))
        assertTrue(HevcNal.isParameterSetsOnly(HevcNal.nalTypes(config)))
        assertTrue(HevcNal.hasParameterSets(HevcNal.nalTypes(config + idr)))
        assertTrue(HevcNal.isKeyframe(HevcNal.nalTypes(idr)))
        assertFalse(HevcNal.isKeyframe(HevcNal.nalTypes(trail)))
    }

    @Test
    fun manifestDiagnosticsFlagMissingConfiguration() {
        val missing = ManifestDiagnostics.validate(emptyMap(), emptySet(), emptySet(), isComponentActivity = false, sdkInt = 35)
        val ids = missing.map { it.id }.toSet()
        assertTrue("applicationIdMissing" in ids)
        assertTrue("permission.BLUETOOTH_CONNECT" in ids)
        assertTrue("activityNotComponentActivity" in ids)

        val perms = setOf("android.permission.BLUETOOTH", "android.permission.BLUETOOTH_CONNECT", "android.permission.INTERNET",
            "android.permission.POST_NOTIFICATIONS")
        val ok = ManifestDiagnostics.validate(
            mapOf(ManifestDiagnostics.APPLICATION_ID to "123", ManifestDiagnostics.CLIENT_TOKEN to "abc"),
            perms, perms, isComponentActivity = true, sdkInt = 35,
        )
        assertTrue(ok.toString(), ok.none { it.severity == "error" })
        val dev = ManifestDiagnostics.validate(mapOf(ManifestDiagnostics.APPLICATION_ID to "0"), perms, perms, true, 35)
        assertTrue(dev.any { it.id == "developerModeCredentials" && it.severity == "info" })
    }

    @Test
    fun i420ToArgbUsesBt709LimitedRange() {
        // 2x2 frame: Y = 16 (black), 235 (white); neutral chroma.
        val yuv = byteArrayOf(16, 16, 235.toByte(), 235.toByte(), 128.toByte(), 128.toByte())
        val out = IntArray(4)
        YuvToArgb.convertI420ToArgb(yuv, out, 2, 2)
        // Fixed-point 1.164 * 219 truncates to 254, matching Meta's sample converter.
        assertArrayEquals(intArrayOf(0xFF000000.toInt(), 0xFF000000.toInt(), 0xFFFEFEFE.toInt(), 0xFFFEFEFE.toInt()), out)
    }

    @Test
    fun wireErrorShapes() {
        val e = WireError(WireCategory.STREAM, "hingesClosed", "folded", "HINGE_CLOSED", mapOf("fatal" to true))
        assertEquals(mapOf("case" to "hingesClosed", "description" to "folded", "platform" to "android",
            "platformCase" to "HINGE_CLOSED", "fatal" to true), e.details)
        assertEquals("hingesClosed", e.eventPayload["code"])
        assertEquals(WireCategory.STREAM, e.eventPayload["category"])
    }

    @Test
    fun camelAndScreamingConversions() {
        assertEquals("hingesClosed", WireCodec.canonical("HINGE_CLOSED"))
        assertEquals("notStreaming", WireCodec.canonical("NotStreaming"))
        assertEquals("ARROW_U_LEFT", WireCodec.screaming("arrowULeft"))
        assertEquals("circle8RaysLarge", WireCodec.camel("CIRCLE_8_RAYS_LARGE"))
    }
}
