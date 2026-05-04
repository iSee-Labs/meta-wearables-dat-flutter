// Slice 2 stub: registers the plugin's MethodChannel and force-links Meta's
// Android DAT SDK (`com.meta.wearable.dat.core.Wearables`) so that the
// GitHub Packages Maven dependency wiring is exercised by the build. Real
// method handlers arrive starting in slice 4.

package com.iseelabs.meta_wearables_dat_flutter

import android.os.Build
import com.meta.wearable.dat.core.Wearables
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MetaWearablesDatPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "meta_wearables_dat_flutter")
        channel.setMethodCallHandler(this)
        // Force-link Meta's SDK so missing-dependency errors surface here at
        // attach time rather than later when a real method is invoked.
        @Suppress("UNUSED_VARIABLE")
        val wearablesClass = Wearables::class.java
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
