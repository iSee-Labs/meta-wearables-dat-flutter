// Android entry point of the meta_wearables_dat_flutter plugin.
//
// Bridges Meta's Wearables Device Access Toolkit 1.0 to Dart over one
// MethodChannel (`meta_wearables_dat_flutter`) and EventChannels
// (`meta_wearables_dat_flutter/<name>`). Components own their event sinks;
// this class wires channels, routes method calls, initialises the SDK and
// forwards activity intents.
//
// Wearables.initialize() runs once BLUETOOTH_CONNECT is granted: at
// activity attach when it already is, otherwise after
// requestAndroidPermissions(). Enabling the Mock Device Kit initialises
// the SDK as well.

package com.iseelabs.meta_wearables_dat_flutter

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.core.content.ContextCompat
import com.meta.wearable.dat.core.Wearables
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

class MetaWearablesDatPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener,
    PluginRegistry.NewIntentListener {

    companion object {
        private const val PERMISSION_REQUEST_CODE = 0x4D57
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val initialized = MutableStateFlow(false)
    private var initError: String? = null

    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private val eventChannels = mutableListOf<EventChannel>()

    private lateinit var hub: DeviceSessionHub
    private lateinit var registration: RegistrationBridge
    private lateinit var deviceState: DeviceStateObserver
    private lateinit var camera: MetaSessionManager
    private lateinit var display: MetaDisplayManager
    private lateinit var mock: MetaMockDeviceManager
    private lateinit var experimental: ExperimentalCapabilities
    private lateinit var voice: VoiceInvocationsBridge

    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermissions: CompletableDeferred<Boolean>? = null

    // --- FlutterPlugin ------------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        hub = DeviceSessionHub(scope)
        registration = RegistrationBridge(scope, initialized)
        deviceState = DeviceStateObserver(scope, initialized)
        camera = MetaSessionManager(binding.textureRegistry, hub, scope)
        display = MetaDisplayManager(hub, scope)
        experimental = createExperimentalCapabilities(hub, scope)
        mock = MetaMockDeviceManager(context, experimental)
        voice = VoiceInvocationsBridge(scope)

        channel = MethodChannel(binding.binaryMessenger, "meta_wearables_dat_flutter")
        channel.setMethodCallHandler(this)

        val handlers = linkedMapOf(
            "registration_state" to registration.stateSink,
            "registration_errors" to registration.errorSink,
            "registration_requests" to registration.requestSink,
            "active_device" to deviceState.activeDeviceSink,
            "devices" to deviceState.devicesSink,
            "device_state" to deviceState.deviceStateSink,
            "compatibility" to deviceState.compatibilitySink,
            "device_session_state" to hub.stateSink,
            "device_session_errors" to hub.errorSink,
            "stream_session_state" to camera.stateSink,
            "stream_session_errors" to camera.errorSink,
            "camera_state" to camera.cameraStateSink,
            "video_stream_size" to camera.sizeSink,
            "video_frames" to camera.framesSink,
            "audio_frames" to camera.audioSink,
            "photo_state" to camera.photoStateSink,
            "photo_progress" to camera.photoProgressSink,
            "photo_errors" to camera.photoErrorSink,
            "display_state" to display.stateSink,
            "display_events" to display.eventsSink,
            "display_errors" to display.errorSink,
            "inputs_state" to experimental.inputsState,
            "inputs_events" to experimental.inputsEvents,
            "inputs_errors" to experimental.inputsErrors,
            "motion_state" to experimental.motionState,
            "motion_samples" to experimental.motionSamples,
            "motion_errors" to experimental.motionErrors,
            "speech_state" to experimental.speechState,
            "speech_transcriptions" to experimental.speechTranscriptions,
            "speech_errors" to experimental.speechErrors,
            "voice_invocations" to voice.invocationsSink,
            "voice_state" to voice.stateSink,
            "voice_errors" to voice.errorSink,
            "mock_devices" to mock.devicesSink,
        )
        for ((name, handler) in handlers) {
            eventChannels += EventChannel(binding.binaryMessenger, "meta_wearables_dat_flutter/$name").also {
                it.setStreamHandler(handler)
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannels.forEach { it.setStreamHandler(null) }
        eventChannels.clear()
        registration.dropPendingRequests()
        scope.launch {
            voice.stop()
            experimental.stopInputs()
            experimental.stopMotion()
            experimental.stopSpeech()
            display.stopDisplaySession()
            camera.stopSession()
            hub.stopAll()
            camera.dispose()
            scope.cancel()
        }
    }

    // --- ActivityAware --------------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        binding.addOnNewIntentListener(this)
        registration.attach(binding.activity)
        if (missingPermissions(binding.activity).isEmpty()) initializeWearables()
        registration.handleIntent(binding.activity.intent)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        registration.detach()
    }

    override fun onNewIntent(intent: Intent): Boolean = registration.handleIntent(intent)

    // --- SDK initialisation ---------------------------------------------------------

    private fun requiredPermissions(): List<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) listOf(Manifest.permission.BLUETOOTH_CONNECT) else emptyList()

    private fun missingPermissions(ctx: Context) = requiredPermissions().filter {
        ContextCompat.checkSelfPermission(ctx, it) != PackageManager.PERMISSION_GRANTED
    }

    private fun initializeWearables() {
        if (initialized.value) return
        val result = Wearables.initialize(context)
        val error = result.errorOrNull()
        if (error == null || error.name == "ALREADY_INITIALIZED") {
            initialized.value = true
            initError = null
            activityBinding?.activity?.intent?.let { registration.handleIntent(it) }
        } else {
            initError = error.description
        }
    }

    private suspend fun requestAndroidPermissions(): Boolean {
        val activity = activityBinding?.activity ?: throw WireError(
            WireCategory.PERMISSION, "noActivity", "No Activity is attached to the plugin.",
        )
        val missing = missingPermissions(activity)
        if (missing.isEmpty()) {
            initializeWearables()
            return true
        }
        pendingPermissions?.let {
            throw WireError(WireCategory.PERMISSION, "requestInProgress", "A permission request is already in flight.")
        }
        val deferred = CompletableDeferred<Boolean>()
        pendingPermissions = deferred
        androidx.core.app.ActivityCompat.requestPermissions(activity, missing.toTypedArray(), PERMISSION_REQUEST_CODE)
        val granted = deferred.await()
        if (granted) initializeWearables()
        return granted
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val deferred = pendingPermissions ?: return true
        pendingPermissions = null
        deferred.complete(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
        return true
    }

    private fun requireInitialized() {
        if (initialized.value) return
        throw WireError(
            WireCategory.PLUGIN, "wearablesNotInitialized",
            initError?.let { "Wearables.initialize() failed: $it" }
                ?: "The DAT SDK is not initialised yet. Call requestAndroidPermissions() first.",
        )
    }

    // --- Method calls -----------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                result.success(route(call))
            } catch (e: NotImplementedError) {
                result.notImplemented()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                val wire = if (e is WireError) e else WireCodec.from(e, WireCategory.PLUGIN)
                android.util.Log.w("MetaWearablesDat", "${call.method} failed: $wire")
                result.error(wire.category, wire.message, wire.details)
            }
        }
    }

    private suspend fun route(call: MethodCall): Any? {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        fun string(key: String) = args[key] as? String
        fun required(key: String) = (args[key] as? String)?.takeIf { it.isNotEmpty() }
            ?: throw WireError.invalidArgument("${call.method} requires a non-empty '$key'.")

        when (call.method) {
            // Platform & diagnostics
            "getPlatformVersion" -> return "Android ${Build.VERSION.RELEASE}"
            "dumpDiagnostics" -> return diagnostics()
            "requestAndroidPermissions" -> return requestAndroidPermissions()

            // Registration
            "getRegistrationState" -> return registration.registrationState()
            "startRegistration" -> { requireInitialized(); registration.startRegistration(); return null }
            "startUnregistration" -> {
                requireInitialized()
                hub.stopAll()
                registration.startUnregistration()
                return null
            }
            "handleUrl" -> { requireInitialized(); return registration.handleUrl(required("url")) }
            "continueRegistrationRequest" -> { registration.answer(required("requestId"), true); return null }
            "cancelRegistrationRequest" -> { registration.answer(required("requestId"), false); return null }

            // Permissions & Meta AI navigation
            "requestPermission" -> { requireInitialized(); return registration.requestPermission(string("permission")) }
            "checkPermissionStatus" -> { requireInitialized(); return registration.checkPermission(string("permission")) }
            "openFirmwareUpdate" -> { requireInitialized(); registration.openFirmwareUpdate(); return null }
            "openDatGlassesAppUpdate" -> { requireInitialized(); registration.openDatGlassesAppUpdate(); return null }

            // Devices
            "getDevices" -> return deviceState.allDevices()
            "getDevice" -> return deviceState.device(required("deviceUuid"))
            "getSessionDevice" -> return hub.sessionDevice()

            // Camera
            "startStreamSession" -> {
                requireInitialized()
                return camera.startSession(StreamSessionArgs.parse(args))
            }
            "stopStreamSession" -> { camera.stopSession(); return null }
            "capturePhoto" -> {
                val (bytes, format) = camera.capturePhoto(string("format") ?: "jpeg")
                return mapOf("bytes" to bytes, "format" to format)
            }
            "capturePhotoHq" -> {
                val photo = camera.captureHqPhoto(string("resolution"), string("quality"))
                return buildMap {
                    put("bytes", photo.imageData)
                    put("timestampMs", photo.timestamp)
                    photo.metadata?.let { put("metadata", it) }
                }
            }
            "enableBackgroundStreaming" -> { enableBackgroundStreaming(args); return null }
            "disableBackgroundStreaming" -> { disableBackgroundStreaming(); return null }

            // Display
            "startDisplaySession" -> {
                requireInitialized()
                display.startDisplaySession(string("deviceUuid"))
                return null
            }
            "sendDisplayView" -> {
                val view = args["view"] as? Map<*, *>
                    ?: throw WireError.invalidArgument("sendDisplayView requires a 'view' map.")
                return display.sendView(view)
            }
            "clearDisplay" -> { display.clearDisplay(); return null }
            "stopDisplayVideo" -> { display.stopVideo(); return null }
            "stopDisplaySession" -> { display.stopDisplaySession(); return null }

            // Experimental capabilities
            "startInputs" -> { requireInitialized(); experimental.startInputs(args); return null }
            "stopInputs" -> { experimental.stopInputs(); return null }
            "startMotion" -> { requireInitialized(); experimental.startMotion(args); return null }
            "stopMotion" -> { experimental.stopMotion(); return null }
            "startSpeech" -> { requireInitialized(); experimental.startSpeech(args); return null }
            "stopSpeech" -> { experimental.stopSpeech(); return null }
            "startVoiceInvocations" -> { requireInitialized(); voice.start(string("deviceUuid")); return null }
            "stopVoiceInvocations" -> { voice.stop(); return null }
            "respondVoiceInvocation" -> return voice.respond(
                required("invocationId"),
                args["success"] as? Boolean ?: true,
                string("actionOutput"),
            )

            // Mock Device Kit
            "enableMockDevice" -> {
                mock.enable(
                    args["initiallyRegistered"] as? Boolean ?: true,
                    args["initialPermissionsGranted"] as? Boolean ?: true,
                )
                // MockDeviceKit initialises the SDK itself.
                initialized.value = true
                return null
            }
            "disableMockDevice" -> { hub.stopAll(); mock.disable(); return null }
            "isMockDeviceEnabled" -> return mock.isEnabled
            "pairMockGlasses" -> return mock.pair(string("model"))
            "pairedMockDevices" -> return mock.pairedDevices()
            "unpairMockDevice" -> { mock.unpair(required("uuid")); return null }
            "mockPowerOn", "mockPowerOff", "mockDon", "mockDoff", "mockFold", "mockUnfold",
            "mockCaptouchTap", "mockCaptouchTapAndHold" -> { mock.perform(call.method, required("uuid")); return null }
            "setMockBatteryLevel" -> { mock.setBatteryLevel(required("uuid"), (args["level"] as? Number)?.toInt()); return null }
            "setMockChargingState" -> { mock.setChargingState(required("uuid"), string("state")); return null }
            "setMockThermalLevel" -> { mock.setThermalLevel(required("uuid"), string("level")); return null }
            "setMockCameraFacing" -> { mock.setCameraFacing(required("uuid"), string("facing")); return null }
            "setMockCameraFeed" -> { mock.setCameraFeed(required("uuid"), string("filePath")); return null }
            "setMockCapturedImage" -> { mock.setCapturedImage(required("uuid"), string("filePath")); return null }
            "setMockCapturedPhoto" -> { mock.setCapturedPhoto(required("uuid"), string("filePath")); return null }
            "simulateMockCaptureFailure" -> { mock.simulateCaptureFailure(required("uuid")); return null }
            "setMockPermission" -> { mock.setPermission(string("permission"), string("status"), false); return null }
            "setMockPermissionRequestResult" -> {
                mock.setPermission(string("permission"), string("status"), true)
                return null
            }
            "mockInput" -> { mock.input(required("uuid"), args); return null }
            "mockSpeech" -> { mock.speech(required("uuid"), args); return null }
            "setMockMotionFeed" -> { mock.setMotionFeed(required("uuid"), args); return null }
            "simulateMockVoiceInvocation" -> return mock.voice(required("uuid"), args["incomplete"] as? Boolean ?: false)
            "startMockTestServer" -> return mock.startTestServer((args["port"] as? Number)?.toInt() ?: 9000)
            "stopMockTestServer" -> { mock.stopTestServer(); return null }
            "sendMockDisplayClick" -> return mock.sendDisplayClick(required("uuid"), required("identifier"))

            else -> throw NotImplementedError(call.method)
        }
    }

    // --- Background streaming -----------------------------------------------------------

    private fun enableBackgroundStreaming(args: Map<*, *>) {
        val notification = args["androidNotification"] as? Map<*, *> ?: emptyMap<String, Any?>()
        val intent = Intent(context, BackgroundStreamingService::class.java).apply {
            putExtra(BackgroundStreamingService.EXTRA_TITLE, notification["title"] as? String)
            putExtra(BackgroundStreamingService.EXTRA_TEXT, notification["text"] as? String)
            putExtra(BackgroundStreamingService.EXTRA_CHANNEL_ID, notification["channelId"] as? String)
            putExtra(BackgroundStreamingService.EXTRA_CHANNEL_NAME, notification["channelName"] as? String)
            putExtra(BackgroundStreamingService.EXTRA_ICON_RESOURCE_NAME, notification["iconResourceName"] as? String)
        }
        try {
            ContextCompat.startForegroundService(context, intent)
        } catch (e: Throwable) {
            throw WireError(
                WireCategory.PLUGIN, "backgroundStreamingFailed",
                "Could not start the background streaming service: ${e.message}",
            )
        }
    }

    private fun disableBackgroundStreaming() {
        if (!BackgroundStreamingService.isRunning) return
        context.startService(
            Intent(context, BackgroundStreamingService::class.java).setAction(BackgroundStreamingService.ACTION_STOP),
        )
    }

    // --- Diagnostics ----------------------------------------------------------------------

    private fun diagnostics(): Map<String, Any?> {
        val pm = context.packageManager
        val appInfo = pm.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
        val metaData = appInfo.metaData?.let { bundle ->
            bundle.keySet().filter { it.startsWith("com.meta.wearable") }.associateWith {
                @Suppress("DEPRECATION")
                bundle.get(it)
            }
        } ?: emptyMap()
        val declared = try {
            val info = if (Build.VERSION.SDK_INT >= 33) {
                pm.getPackageInfo(context.packageName, PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
            }
            info.requestedPermissions?.toSet() ?: emptySet()
        } catch (_: Throwable) {
            emptySet()
        }
        val granted = declared.filter {
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }.toSet()
        val activity: Activity? = activityBinding?.activity
        val findings = ManifestDiagnostics.validate(
            metaData = metaData.mapValues { it.value },
            declaredPermissions = declared,
            grantedPermissions = granted,
            isComponentActivity = activity?.let { it is ComponentActivity },
            sdkInt = Build.VERSION.SDK_INT,
        ).toMutableList()
        if (!BuildConfig.EXPERIMENTAL_LINKED) {
            findings += Finding(
                "experimentalModulesNotLinked", "info",
                "Built with mwdat.experimental=false: Inputs, Motion and Speech are unavailable.",
                "Remove mwdat.experimental=false from gradle.properties to enable them.",
            )
        }
        return buildMap {
            put("platform", "android")
            put("pluginVersion", BuildConfig.PLUGIN_VERSION)
            put("sdkVersion", BuildConfig.MWDAT_VERSION)
            put("os", "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
            put("bundleId", context.packageName)
            put("wearablesConfigured", initialized.value)
            initError?.let { put("configureError", it) }
            put("registrationState", registration.registrationState())
            put("devices", deviceState.allDevices())
            hub.sessionDevice()?.let { put("sessionDevice", it) }
            put("findings", findings.map { it.map })
            put("resources", ResourceLedger.snapshot())
            put(
                "experimentalModulesLinked",
                mapOf(
                    "inputs" to experimental.linked,
                    "motion" to experimental.linked,
                    "speech" to experimental.linked,
                    "voiceInvocations" to true,
                    "cameraPhoto" to true,
                    "cameraAudio" to true,
                ),
            )
            put("crashReportingOptOut", metaData[ManifestDiagnostics.CRASH_REPORTING_OPT_OUT]?.toString() == "true")
            put("analyticsOptOut", metaData[ManifestDiagnostics.ANALYTICS_OPT_OUT]?.toString() == "true")
            put("backgroundStreamingEnabled", BackgroundStreamingService.isRunning)
            put("config", mapOf("metaData" to metaData.mapValues { it.value?.toString() }, "permissions" to declared.sorted()))
        }
    }
}
