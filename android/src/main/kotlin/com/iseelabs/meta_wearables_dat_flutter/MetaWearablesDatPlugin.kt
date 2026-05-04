// `meta_wearables_dat_flutter` Android plugin.
//
// Slice 4: implements `requestAndroidPermissions` end-to-end. The plugin
// becomes `ActivityAware` so it can call `ActivityCompat.requestPermissions`
// against the host `Activity`, and registers a
// `PluginRegistry.RequestPermissionsResultListener` so the system callback
// can resolve the pending Flutter Result.
//
// Meta's `Wearables.initialize(activity)` is called exactly once, only
// after `BLUETOOTH_CONNECT` is granted - calling it earlier silently breaks
// device discovery (the bug rodcone burned a release on, see plan risk 2).

package com.iseelabs.meta_wearables_dat_flutter

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import com.meta.wearable.dat.core.Wearables
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

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
    private var activityBinding: ActivityPluginBinding? = null
    private var activity: Activity? = null

    private var pendingPermissionResult: Result? = null

    // Gated initialisation: `Wearables.initialize` must run exactly once and
    // only after `BLUETOOTH_CONNECT` has been granted.
    private var wearablesInitialised: Boolean = false

    // --- FlutterPlugin --------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "meta_wearables_dat_flutter")
        channel.setMethodCallHandler(this)
        // Force-link Meta's SDK so missing-dependency errors surface here at
        // attach time rather than later when a real method is invoked.
        @Suppress("UNUSED_VARIABLE")
        val wearablesClass = Wearables::class.java
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // --- ActivityAware --------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    // --- MethodCallHandler ----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
            "requestAndroidPermissions" -> requestAndroidPermissions(result)
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

        // Reject any concurrent request: the system dialog is modal and we
        // only track one pending Result.
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
     * has been granted. See plan risk 2 for the rationale - calling
     * `Wearables.initialize` before BT permissions silently breaks device
     * discovery.
     */
    private fun ensureWearablesInitialised() {
        if (wearablesInitialised) return
        val act = activity ?: return
        Wearables.initialize(act)
        wearablesInitialised = true
    }

    private fun requiredPermissions(): List<String> {
        val perms = mutableListOf(Manifest.permission.INTERNET)
        // BLUETOOTH_CONNECT exists from API 31; minSdk is 31 so it's always
        // present, but guard anyway for forward compatibility.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            perms += Manifest.permission.BLUETOOTH_CONNECT
        }
        return perms
    }
}
