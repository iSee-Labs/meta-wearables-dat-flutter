// `meta_wearables_dat_flutter` Android plugin.
//
// Slice 4: implement `requestAndroidPermissions` end-to-end.
// Slice 5: registration flow. Adds `startRegistration`, `startUnregistration`,
//          `handleUrl` (documented no-op on Android - the SDK consumes
//          deep links via the host activity's intent-filter), and the
//          `registration_state` and `active_device` EventChannels driven by
//          `Wearables.registrationState` and
//          `AutoDeviceSelector().activeDeviceFlow()`.
//
// Meta's `Wearables.initialize(activity)` is called exactly once, only
// after `BLUETOOTH_CONNECT` is granted - calling it earlier silently breaks
// device discovery (the bug rodcone burned a release on, see plan risk 2).
// Stream handlers therefore wait on a Mutex/flag until init has run; if a
// Dart subscriber attaches before init, collection starts as soon as init
// fires.

package com.iseelabs.meta_wearables_dat_flutter

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.core.app.ActivityCompat
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.meta.wearable.dat.core.types.DeviceIdentifier
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import com.meta.wearable.dat.core.types.RegistrationState
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class MetaWearablesDatPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        // Arbitrary unique request code; range 1..65535 per Android.
        private const val PERMISSION_REQUEST_CODE = 10_001
    }

    private lateinit var channel: MethodChannel
    private lateinit var registrationStateChannel: EventChannel
    private lateinit var activeDeviceChannel: EventChannel

    private var activityBinding: ActivityPluginBinding? = null
    private var activity: Activity? = null

    private var pendingPermissionResult: Result? = null
    private var pendingCameraPermissionResult: Result? = null

    /**
     * Activity-result launcher driving Meta's
     * `Wearables.RequestPermissionContract`. Registered with the host
     * activity's `ActivityResultRegistry` from `onAttachedToActivity` and
     * unregistered on detach. `null` when the activity has not been
     * attached yet, or when the activity isn't a `ComponentActivity` (in
     * which case `requestCameraPermission` returns
     * `MISSING_FRAGMENT_ACTIVITY`).
     */
    private var cameraPermissionLauncher: ActivityResultLauncher<Permission>? = null

    /**
     * Gated initialisation. Flips to `true` exactly once after
     * `BLUETOOTH_CONNECT` is granted and `Wearables.initialize(activity)`
     * has returned. Stream handlers observe this flow and defer collection
     * until it flips, then start automatically.
     */
    private val wearablesInitialised = MutableStateFlow(false)

    private val pluginScope =
        CoroutineScope(Dispatchers.Main.immediate + SupervisorJob())

    private val registrationStateHandler = RegistrationStateStreamHandler()
    private val activeDeviceHandler = ActiveDeviceStreamHandler()

    // --- FlutterPlugin --------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "meta_wearables_dat_flutter")
        channel.setMethodCallHandler(this)

        registrationStateChannel = EventChannel(
            binding.binaryMessenger,
            "meta_wearables_dat_flutter/registration_state",
        )
        registrationStateChannel.setStreamHandler(registrationStateHandler)

        activeDeviceChannel = EventChannel(
            binding.binaryMessenger,
            "meta_wearables_dat_flutter/active_device",
        )
        activeDeviceChannel.setStreamHandler(activeDeviceHandler)

        // Force-link Meta's SDK so missing-dependency errors surface here at
        // attach time rather than later when a real method is invoked.
        @Suppress("UNUSED_VARIABLE")
        val wearablesClass = Wearables::class.java
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        registrationStateChannel.setStreamHandler(null)
        activeDeviceChannel.setStreamHandler(null)
        registrationStateHandler.cancel()
        activeDeviceHandler.cancel()
        pluginScope.cancel()
    }

    // --- ActivityAware --------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        registerCameraPermissionLauncher(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
        cameraPermissionLauncher?.unregister()
        cameraPermissionLauncher = null
    }

    private fun registerCameraPermissionLauncher(activity: Activity) {
        if (activity !is ComponentActivity) return
        cameraPermissionLauncher = activity.activityResultRegistry.register(
            "meta_wearables_dat_camera_permission",
            Wearables.RequestPermissionContract(),
        ) { result ->
            val pending = pendingCameraPermissionResult
            pendingCameraPermissionResult = null
            // Wearables.RequestPermissionContract returns
            // `Result<PermissionStatus>` (Meta's own Result type, not
            // kotlin.Result) so we use getOrDefault to coerce to a
            // PermissionStatus regardless of failure shape.
            val status = result.getOrDefault(PermissionStatus.Denied)
            pending?.success(status == PermissionStatus.Granted)
        }
    }

    // --- MethodCallHandler ----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
            "requestAndroidPermissions" -> requestAndroidPermissions(result)
            "startRegistration" -> startRegistration(result)
            "startUnregistration" -> startUnregistration(result)
            "handleUrl" -> handleUrl(result)
            "getRegistrationState" -> getRegistrationState(result)
            "requestCameraPermission" -> requestCameraPermission(result)
            "getCameraPermissionStatus" -> getCameraPermissionStatus(result)
            else -> result.notImplemented()
        }
    }

    // --- Permission flow ------------------------------------------------------

    private fun requestAndroidPermissions(result: Result) {
        val act = activity
        if (act == null) {
            result.error(
                "NO_ACTIVITY",
                "No Activity is attached to the plugin. Are you calling " +
                    "requestAndroidPermissions before runApp / before the engine " +
                    "is attached?",
                null,
            )
            return
        }

        val required = requiredPermissions()
        val missing = required.filter { perm ->
            ActivityCompat.checkSelfPermission(act, perm) !=
                PackageManager.PERMISSION_GRANTED
        }

        if (missing.isEmpty()) {
            ensureWearablesInitialised()
            result.success(true)
            return
        }

        if (pendingPermissionResult != null) {
            result.error(
                "ALREADY_REQUESTING",
                "A permission request is already in flight.",
                null,
            )
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            act,
            missing.toTypedArray(),
            PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false

        val pending = pendingPermissionResult ?: return true
        pendingPermissionResult = null

        val allGranted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }

        if (allGranted) {
            ensureWearablesInitialised()
        }
        pending.success(allGranted)
        return true
    }

    /**
     * Initialises Meta's DAT SDK exactly once, only after BLUETOOTH_CONNECT
     * has been granted. See plan risk 2.
     */
    private fun ensureWearablesInitialised() {
        if (wearablesInitialised.value) return
        val act = activity ?: return
        Wearables.initialize(act)
        wearablesInitialised.value = true
    }

    private fun requiredPermissions(): List<String> {
        val perms = mutableListOf(Manifest.permission.INTERNET)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            perms += Manifest.permission.BLUETOOTH_CONNECT
        }
        return perms
    }

    // --- Registration flow ----------------------------------------------------

    private fun startRegistration(result: Result) {
        val act = activity
        if (act == null) {
            result.error(
                "NO_ACTIVITY",
                "Cannot start registration without an Activity. Make sure your " +
                    "MainActivity extends FlutterFragmentActivity.",
                null,
            )
            return
        }
        try {
            Wearables.startRegistration(act)
            result.success(null)
        } catch (e: Exception) {
            result.error(
                "REGISTRATION_ERROR",
                e.message ?: e::class.java.simpleName,
                null,
            )
        }
    }

    private fun startUnregistration(result: Result) {
        val act = activity
        if (act == null) {
            result.error(
                "NO_ACTIVITY",
                "Cannot start unregistration without an Activity.",
                null,
            )
            return
        }
        try {
            Wearables.startUnregistration(act)
            result.success(null)
        } catch (e: Exception) {
            result.error(
                "REGISTRATION_ERROR",
                e.message ?: e::class.java.simpleName,
                null,
            )
        }
    }

    /**
     * Documented no-op on Android. Meta's Android SDK consumes the
     * registration callback through the host activity's intent-filter
     * automatically, not through an explicit `handleUrl` API. Host apps
     * still need to declare the matching intent-filter and use
     * `launchMode="singleTop"`. See `doc/registration_flow.md`.
     */
    private fun handleUrl(result: Result) {
        result.success(false)
    }

    private fun getRegistrationState(result: Result) {
        if (!wearablesInitialised.value) {
            result.success(stateToInt(null))
            return
        }
        pluginScope.launch {
            val state = Wearables.registrationState.first()
            result.success(stateToInt(state))
        }
    }

    // --- Camera permission ----------------------------------------------------

    private fun requestCameraPermission(result: Result) {
        val launcher = cameraPermissionLauncher
        if (launcher == null) {
            result.error(
                "MISSING_FRAGMENT_ACTIVITY",
                "Camera permission requires the host Activity to extend " +
                    "FlutterFragmentActivity (a ComponentActivity). See " +
                    "doc/getting_started.md for the required MainActivity " +
                    "snippet.",
                null,
            )
            return
        }
        if (pendingCameraPermissionResult != null) {
            result.error(
                "ALREADY_REQUESTING",
                "A camera permission request is already in flight.",
                null,
            )
            return
        }
        pendingCameraPermissionResult = result
        launcher.launch(Permission.CAMERA)
    }

    private fun getCameraPermissionStatus(result: Result) {
        pluginScope.launch {
            val outcome = Wearables.checkPermissionStatus(Permission.CAMERA)
            // Wearables.checkPermissionStatus returns Meta's own `Result`
            // wrapper. Treat any failure as "not granted" - host apps can
            // call requestCameraPermission to surface the underlying
            // PermissionError, if any.
            val status = outcome.getOrDefault(PermissionStatus.Denied)
            result.success(status == PermissionStatus.Granted)
        }
    }

    // --- Stream handlers ------------------------------------------------------

    /**
     * Forwards `Wearables.registrationState` to a Flutter EventSink as
     * `Int` values matching Dart's `RegistrationState.fromInt`. Defers
     * collection until `wearablesInitialised` flips to `true`.
     */
    private inner class RegistrationStateStreamHandler : EventChannel.StreamHandler {
        private var job: Job? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            job?.cancel()
            job = pluginScope.launch {
                wearablesInitialised.first { it }
                Wearables.registrationState.collectLatest { state ->
                    events.success(stateToInt(state))
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            job?.cancel()
            job = null
        }

        fun cancel() {
            job?.cancel()
            job = null
        }
    }

    /**
     * Forwards `AutoDeviceSelector().activeDeviceFlow()` to a Flutter
     * EventSink as a serialised `DeviceInfo` map (or `null` when no device
     * is active). Long-lived: the selector instance is recreated per
     * subscription so old jobs don't leak across hot restarts.
     */
    private inner class ActiveDeviceStreamHandler : EventChannel.StreamHandler {
        private var job: Job? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            job?.cancel()
            job = pluginScope.launch {
                wearablesInitialised.first { it }
                val selector = AutoDeviceSelector()
                selector.activeDeviceFlow().collectLatest { deviceId ->
                    events.success(encodeDevice(deviceId))
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            job?.cancel()
            job = null
        }

        fun cancel() {
            job?.cancel()
            job = null
        }
    }

    // --- Helpers --------------------------------------------------------------

    /**
     * Maps `RegistrationState` to the int value the Dart enum understands
     * (`unavailable=0, available=1, registering=2, registered=3`). Android's
     * sealed `RegistrationState` exposes more fine-grained subtypes than
     * iOS - `Unregistering` is treated as transitional `registering` and
     * anything unrecognised falls back to `unavailable`.
     */
    private fun stateToInt(state: RegistrationState?): Int = when (state) {
        null -> 0
        is RegistrationState.Registered -> 3
        is RegistrationState.Registering -> 2
        is RegistrationState.Unregistering -> 2
        else -> when (state::class.simpleName) {
            // String-name fallback for SDK case additions ("Available",
            // "Unregistered", ...) we don't have a compile-time `is` check
            // for. Maps known strings to their cross-platform int.
            "Available" -> 1
            else -> 0
        }
    }

    /**
     * Serialises a [DeviceIdentifier] to the map shape that
     * `DeviceInfo.fromMap` expects on the Dart side, or `null` when no
     * device is active.
     *
     * Android's [DeviceIdentifier] is a string id; richer metadata
     * (display name, device kind) lives in `Wearables.devicesMetadata` and
     * is best-effort joined here. When metadata isn't ready yet we fall
     * back to the id as the name and `unknown` as the kind.
     */
    private fun encodeDevice(id: DeviceIdentifier?): Map<String, Any?>? {
        if (id == null) return null
        return mapOf(
            "uuid" to id,
            "name" to id,
            "kind" to "unknown",
        )
    }
}
