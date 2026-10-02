// Wire encoding shared by every Android bridge component.
//
// Mirrors ios/.../WireCodec.swift: enum values travel as lowerCamelCase
// strings matching the iOS SDK case names, and errors travel as
//   * method calls: result.error(<CATEGORY>, <description>,
//     {case, description, platformCase, platform, ...extras})
//   * events: {code: <case>, category, message, platformCase, platform, ...}
//
// Android SDK enums are SCREAMING_SNAKE_CASE. They are converted with
// `canonical()`, which applies an alias table where the two SDKs name the
// same case differently (for example HINGE_CLOSED -> hingesClosed).

package com.iseelabs.meta_wearables_dat_flutter

import com.meta.wearable.dat.core.types.DatError
import com.meta.wearable.dat.core.types.Device
import com.meta.wearable.dat.core.types.DeviceType

object WireCategory {
    const val REGISTRATION = "REGISTRATION_ERROR"
    const val UNREGISTRATION = "UNREGISTRATION_ERROR"
    const val HANDLE_URL = "HANDLE_URL_ERROR"
    const val REGISTRATION_REQUEST = "REGISTRATION_REQUEST_ERROR"
    const val PERMISSION = "PERMISSION_ERROR"
    const val NAVIGATION = "NAVIGATION_ERROR"
    const val DEVICE_SESSION = "DEVICE_SESSION_ERROR"
    const val STREAM = "STREAM_ERROR"
    const val CAPTURE = "CAPTURE_ERROR"
    const val PHOTO = "PHOTO_ERROR"
    const val DISPLAY = "DISPLAY_ERROR"
    const val INPUTS = "INPUTS_ERROR"
    const val MOTION = "MOTION_ERROR"
    const val SPEECH = "SPEECH_ERROR"
    const val VOICE_INVOCATION = "VOICE_INVOCATION_ERROR"
    const val MOCK = "MOCK_ERROR"
    const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
    const val NOT_SUPPORTED = "NOT_SUPPORTED"
    const val EXPERIMENTAL_NOT_LINKED = "EXPERIMENTAL_NOT_LINKED"
    const val PLUGIN = "PLUGIN_ERROR"
}

/** A plugin error in wire form. */
class WireError(
    val category: String,
    val caseName: String,
    override val message: String,
    val platformCase: String? = null,
    val extras: Map<String, Any?> = emptyMap(),
) : Exception(message) {

    val details: Map<String, Any?>
        get() = buildMap {
            put("case", caseName)
            put("description", message)
            put("platform", "android")
            platformCase?.let { put("platformCase", it) }
            putAll(extras)
        }

    val eventPayload: Map<String, Any?>
        get() = buildMap {
            put("code", caseName)
            put("category", category)
            put("message", message)
            put("platform", "android")
            platformCase?.let { put("platformCase", it) }
            putAll(extras)
        }

    override fun toString(): String = "$category/$caseName: $message"

    companion object {
        fun invalidArgument(message: String) =
            WireError(WireCategory.INVALID_ARGUMENT, "invalidArgument", message)

        fun plugin(caseName: String, message: String) =
            WireError(WireCategory.PLUGIN, caseName, message)
    }
}

object WireCodec {

    /** Android name -> canonical (iOS) name where a plain camelCase conversion differs. */
    private val aliases = mapOf(
        "META_AI_NOT_INSTALLED" to "metaAINotInstalled",
        "INSUFFICIENT_SDK_VERSION" to "insufficientSDKVersion",
        "HINGE_CLOSED" to "hingesClosed",
        "PERMISSIONS_DENIED" to "permissionDenied",
        "STREAM_ERROR" to "videoStreamingError",
        "CRITICAL_STREAM_ERROR" to "videoStreamingError",
        "CAPABILITY_ALREADY_ADDED" to "capabilityAlreadyActive",
        "SETUP_FAILED" to "sessionSetupFailed",
        "INVALID_URL" to "invalidVideoURL",
        "OAKLEY_META_HSTN" to "oakleyMetaHSTN",
        "RAYBAN_META" to "rayBanMeta",
        "RAYBAN_META_OPTICS" to "rayBanMetaOptics",
        "META_RAYBAN_DISPLAY" to "metaRayBanDisplay",
        "UNDEFINED" to "unknown",
    )

    /** SCREAMING_SNAKE (or PascalCase sealed-class) name -> lowerCamelCase. */
    fun camel(name: String): String {
        if (!name.contains('_') && name.isNotEmpty() && name.any { it.isLowerCase() }) {
            return name.replaceFirstChar { it.lowercaseChar() }
        }
        val parts = name.lowercase().split('_').filter { it.isNotEmpty() }
        if (parts.isEmpty()) return name.lowercase()
        return parts.first() + parts.drop(1).joinToString("") { p ->
            p.replaceFirstChar { it.uppercaseChar() }
        }
    }

    /** Canonical wire name for an enum constant or sealed object name. */
    fun canonical(name: String): String = aliases[name] ?: camel(name)

    fun canonical(value: Enum<*>?): String = value?.let { canonical(it.name) } ?: "unknown"

    /** Canonical name of a sealed error object (`CaptureError.NotStreaming`). */
    fun canonicalSealed(value: Any): String = canonical(value::class.java.simpleName)

    // --- States ----------------------------------------------------------------

    /** Every state enum maps through `canonical`, with a few explicit cases. */
    fun state(value: Enum<*>?): String = canonical(value)

    /**
     * Android's StreamState has STARTED (iOS: no equivalent) and CLOSED
     * (terminal). STARTED is reported as `starting`, CLOSED as `stopped`.
     */
    fun streamState(value: Enum<*>?): String = when (value?.name) {
        "STARTED" -> "starting"
        "CLOSED" -> "stopped"
        else -> canonical(value)
    }

    /** Android DisplayState adds a terminal CLOSED, reported as `stopped`. */
    fun displayState(value: Enum<*>?): String = when (value?.name) {
        "CLOSED" -> "stopped"
        else -> canonical(value)
    }

    /**
     * Android VideoPlayerState -> the iOS playback event names
     * (`started`, `paused`, `ended`). IDLE / STARTING produce no event.
     */
    fun playbackEvent(value: Enum<*>?): String? = when (value?.name) {
        "PLAYING" -> "started"
        "PAUSE" -> "paused"
        "ENDED" -> "ended"
        else -> null
    }

    // --- Device ----------------------------------------------------------------

    fun deviceType(type: DeviceType?): String = canonical(type)

    fun deviceKind(type: DeviceType?): String = when (type?.name) {
        "RAYBAN_META", "RAYBAN_META_OPTICS" -> "rayBanMeta"
        "META_RAYBAN_DISPLAY" -> "rayBanDisplay"
        "OAKLEY_META_HSTN", "OAKLEY_META_VANGUARD" -> "oakleyMeta"
        "META_GLASSES" -> "metaGlasses"
        else -> "unknown"
    }

    fun device(id: String, device: Device?): Map<String, Any?> {
        if (device == null) {
            return mapOf(
                "uuid" to id,
                "name" to id,
                "kind" to "unknown",
                "deviceType" to "unknown",
                "linkState" to "unknown",
                "compatibility" to "unknown",
                "chargingState" to "unknown",
                "donState" to "unknown",
                "hingeState" to "unknown",
                "thermalLevel" to "unknown",
                "supportsDisplay" to false,
            )
        }
        return buildMap {
            put("uuid", id)
            put("name", device.name.ifEmpty { id })
            put("kind", deviceKind(device.deviceType))
            put("deviceType", deviceType(device.deviceType))
            put("linkState", canonical(device.linkState))
            put("compatibility", canonical(device.compatibility))
            put("chargingState", canonical(device.chargingState))
            put("donState", canonical(device.donState))
            put("hingeState", canonical(device.hingeState))
            put("thermalLevel", canonical(device.thermalLevel))
            put("supportsDisplay", device.isDisplayCapable())
            // Android reports 0 when the level is unknown.
            if (device.batteryLevel > 0) put("batteryLevel", device.batteryLevel)
        }
    }

    // --- Errors ----------------------------------------------------------------

    private fun describe(error: Any): String =
        (error as? DatError)?.description ?: error.toString()

    /** Error from an enum-based SDK error type. */
    fun error(category: String, error: Enum<*>): WireError {
        val extras = mutableMapOf<String, Any?>()
        val name = canonical(error.name)
        if (category == WireCategory.DEVICE_SESSION) {
            extras["terminal"] = error.name == "INSUFFICIENT_SDK_VERSION"
            extras["severity"] = if (error.name == "DWA_OUT_OF_STU_RANGE") "warning" else "error"
        }
        if (error.name == "CRITICAL_STREAM_ERROR") extras["fatal"] = true
        return WireError(category, name, describe(error), error.name, extras)
    }

    /** Error from a sealed-class SDK error (CaptureError, MockDeviceKitError). */
    fun sealedError(category: String, error: Any): WireError =
        WireError(category, canonicalSealed(error), describe(error), error::class.java.simpleName)

    /** Registration errors share one Android enum for both directions. */
    fun registrationError(error: Enum<*>, unregistering: Boolean): WireError {
        val category = if (unregistering) WireCategory.UNREGISTRATION else WireCategory.REGISTRATION
        return WireError(category, canonical(error.name), describe(error), error.name)
    }

    /** Wraps an arbitrary failure that crossed a DatResult or a throw. */
    fun from(error: Any?, category: String): WireError = when (error) {
        null -> WireError(category, "unknown", "Unknown error")
        is WireError -> error
        is Enum<*> -> error(category, error)
        is DatError -> sealedError(category, error)
        is Throwable -> WireError(category, "unknown", error.message ?: error.javaClass.simpleName,
            error.javaClass.simpleName)
        else -> WireError(category, "unknown", error.toString())
    }

    // --- Parsers -----------------------------------------------------------------

    /** Wire (lowerCamel) name -> Android SCREAMING_SNAKE for `valueOf`. */
    fun screaming(wire: String): String =
        wire.replace(Regex("([a-z0-9])([A-Z])"), "$1_$2")
            .replace(Regex("([A-Z])([A-Z][a-z])"), "$1_$2")
            .uppercase()

    inline fun <reified T : Enum<T>> parse(wire: String?, vararg extra: Pair<String, T>): T? {
        if (wire == null) return null
        extra.firstOrNull { it.first == wire }?.let { return it.second }
        val target = screaming(wire)
        return enumValues<T>().firstOrNull { it.name == target }
            ?: enumValues<T>().firstOrNull { canonical(it.name) == wire }
    }
}
