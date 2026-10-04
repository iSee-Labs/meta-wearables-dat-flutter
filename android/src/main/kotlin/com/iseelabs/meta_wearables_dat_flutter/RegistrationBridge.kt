// Registration, permissions and Meta AI navigation.
//
// App-initiated registration: startRegistration(activity) opens Meta AI;
// the SDK handles the return itself. Meta AI-initiated registration (DAT
// 1.0): the launch intent carries a RegistrationRequest, which is parked
// under a request id and surfaced on `registration_requests`; Dart answers
// it once with continue / cancel. Intents are passed to
// Wearables.handleIntent from onAttachedToActivity and onNewIntent.

package com.iseelabs.meta_wearables_dat_flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.registration.RegistrationRequest
import com.meta.wearable.dat.core.types.DatResult
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionError
import com.meta.wearable.dat.core.types.PermissionStatus
import java.util.UUID
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class RegistrationBridge(
    private val scope: CoroutineScope,
    private val initialized: StateFlow<Boolean>,
) {
    companion object {
        const val REQUEST_LIFETIME_MS = 300_000L
    }

    val stateSink = EventSinkHandler()
    val errorSink = EventSinkHandler()
    val requestSink = EventSinkHandler()

    private var stateJob: Job? = null
    private var errorJob: Job? = null
    private val pending = linkedMapOf<String, Pair<RegistrationRequest, Job>>()
    private var unregistering = false

    var activity: Activity? = null
    private var permissionLauncher: ActivityResultLauncher<Permission>? = null
    private var permissionResult: CompletableDeferred<DatResult<PermissionStatus, PermissionError>>? = null
    private val permissionMutex = Mutex()
    private var lastHandledIntent: Intent? = null

    init {
        stateSink.onSinkChange = { sink -> if (sink != null) startState() else stopState() }
        errorSink.onSinkChange = { sink -> if (sink != null) startErrors() else stopErrors() }
        requestSink.onSinkChange = { sink -> sink?.let { s -> pending.forEach { (id, p) -> s.success(encode(id, p.first)) } } }
    }

    // --- Activity wiring -------------------------------------------------------------

    fun attach(activity: Activity) {
        this.activity = activity
        if (activity is ComponentActivity) {
            permissionLauncher = activity.activityResultRegistry.register(
                "meta_wearables_dat_permission",
                Wearables.RequestPermissionContract(),
            ) { result ->
                permissionResult?.complete(result)
                permissionResult = null
            }
        }
    }

    fun detach() {
        permissionLauncher?.unregister()
        permissionLauncher = null
        permissionResult?.cancel()
        permissionResult = null
        activity = null
    }

    /** Called with the launch intent and every onNewIntent. */
    fun handleIntent(intent: Intent?): Boolean {
        if (intent == null || intent === lastHandledIntent || !initialized.value) return false
        lastHandledIntent = intent
        val result = Wearables.handleIntent(intent) { request -> scope.launch { park(request) } }
        result.errorOrNull()?.let { error ->
            errorSink.send(WireCodec.error(WireCategory.REGISTRATION_REQUEST, error as Enum<*>).eventPayload)
        }
        return result.getOrNull() ?: false
    }

    // --- State & errors --------------------------------------------------------------

    fun registrationState(): String =
        if (initialized.value) WireCodec.state(Wearables.registrationState.value) else "unavailable"

    private fun startState() {
        stopState()
        stateJob = scope.launch {
            if (!initialized.value) stateSink.send("unavailable")
            initialized.first { it }
            Wearables.registrationState.collect { stateSink.send(WireCodec.state(it)) }
        }
    }

    private fun stopState() {
        stateJob?.cancel()
        stateJob = null
    }

    private fun startErrors() {
        stopErrors()
        errorJob = scope.launch {
            initialized.first { it }
            Wearables.registrationErrorStream.collect { error ->
                val unregister = unregistering || error.name.contains("UNREGISTER")
                errorSink.send(WireCodec.registrationError(error, unregister).eventPayload)
            }
        }
    }

    private fun stopErrors() {
        errorJob?.cancel()
        errorJob = null
    }

    // --- Registration --------------------------------------------------------------

    private fun requireActivity(category: String): Activity = activity ?: throw WireError(
        category, "noActivity", "No Activity is attached. Call this after the Flutter UI is running.",
    )

    fun startRegistration() {
        unregistering = false
        Wearables.startRegistration(requireActivity(WireCategory.REGISTRATION))
    }

    fun startUnregistration() {
        unregistering = true
        Wearables.startUnregistration(requireActivity(WireCategory.UNREGISTRATION))
    }

    fun handleUrl(url: String): Boolean {
        val uri = Uri.parse(url)
        if (uri.scheme.isNullOrEmpty()) {
            throw WireError(WireCategory.HANDLE_URL, "invalidUrl", "Not a valid URL: $url")
        }
        val intent = Intent(Intent.ACTION_VIEW, uri)
        val result = Wearables.handleIntent(intent) { request -> scope.launch { park(request) } }
        return result.getOrNull() ?: throw WireCodec.from(result.errorOrNull(), WireCategory.REGISTRATION_REQUEST)
    }

    private fun park(request: RegistrationRequest) {
        val id = UUID.randomUUID().toString()
        val expiry = scope.launch {
            delay(REQUEST_LIFETIME_MS)
            pending.remove(id)
        }
        pending[id] = request to expiry
        requestSink.send(encode(id, request))
    }

    private fun encode(id: String, request: RegistrationRequest) =
        mapOf("requestId" to id, "flowId" to request.flowId, "protocolVersion" to request.protocolVersion)

    fun answer(requestId: String, accept: Boolean) {
        val (request, expiry) = pending.remove(requestId) ?: throw WireError(
            WireCategory.REGISTRATION_REQUEST, "alreadyHandled",
            "Registration request $requestId was already answered or has expired.",
        )
        expiry.cancel()
        val result = if (accept) {
            request.continueRegistration(requireActivity(WireCategory.REGISTRATION_REQUEST))
        } else {
            request.cancelRegistration()
        }
        if (result.isFailure) throw WireCodec.from(result.errorOrNull(), WireCategory.REGISTRATION_REQUEST)
    }

    fun dropPendingRequests() {
        pending.values.forEach { it.second.cancel() }
        pending.clear()
    }

    // --- Permissions ---------------------------------------------------------------

    suspend fun requestPermission(raw: String?): String {
        val permission = WireCodec.parse<Permission>(raw)
            ?: throw WireError.invalidArgument("Unknown permission '$raw'.")
        val launcher = permissionLauncher ?: throw WireError(
            WireCategory.PERMISSION, "missingFragmentActivity",
            "Meta's permission request needs a ComponentActivity. Make MainActivity extend FlutterFragmentActivity.",
        )
        return permissionMutex.withLock {
            val deferred = CompletableDeferred<DatResult<PermissionStatus, PermissionError>>()
            permissionResult = deferred
            launcher.launch(permission)
            val result = deferred.await()
            val status = result.getOrNull() ?: throw WireCodec.from(result.errorOrNull(), WireCategory.PERMISSION)
            if (status == PermissionStatus.Granted) "granted" else "denied"
        }
    }

    suspend fun checkPermission(raw: String?): String {
        val permission = WireCodec.parse<Permission>(raw)
            ?: throw WireError.invalidArgument("Unknown permission '$raw'.")
        val result = Wearables.checkPermissionStatus(permission)
        val status = result.getOrNull() ?: throw WireCodec.from(result.errorOrNull(), WireCategory.PERMISSION)
        return if (status == PermissionStatus.Granted) "granted" else "denied"
    }

    // --- Meta AI navigation -----------------------------------------------------------

    fun openFirmwareUpdate() {
        val result = Wearables.openFirmwareUpdate(requireActivity(WireCategory.NAVIGATION))
        if (result.isFailure) throw WireCodec.from(result.errorOrNull(), WireCategory.NAVIGATION)
    }

    fun openDatGlassesAppUpdate() {
        val result = Wearables.openDATGlassesAppUpdate(requireActivity(WireCategory.NAVIGATION))
        if (result.isFailure) throw WireCodec.from(result.errorOrNull(), WireCategory.NAVIGATION)
    }
}
