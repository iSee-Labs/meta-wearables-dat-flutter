// Pure validation of the host app's Android configuration against what
// Meta's DAT 1.0 SDK needs. Used by `dumpDiagnostics()`.

package com.iseelabs.meta_wearables_dat_flutter

data class Finding(
    val id: String,
    val severity: String,
    val message: String,
    val fix: String,
) {
    val map: Map<String, Any?> get() =
        mapOf("id" to id, "severity" to severity, "message" to message, "fix" to fix)
}

object ManifestDiagnostics {
    const val APPLICATION_ID = "com.meta.wearable.mwdat.APPLICATION_ID"
    const val CLIENT_TOKEN = "com.meta.wearable.mwdat.CLIENT_TOKEN"
    const val ANALYTICS_OPT_OUT = "com.meta.wearable.mwdat.ANALYTICS_OPT_OUT"
    const val CRASH_REPORTING_OPT_OUT = "com.meta.wearable.mwdat.CRASH_REPORTING_OPT_OUT"
    const val DAM_ENABLED = "com.meta.wearable.mwdat.DAM_ENABLED"

    /**
     * @param metaData application `<meta-data>` values.
     * @param declaredPermissions permissions declared in the merged manifest.
     * @param grantedPermissions runtime permissions currently granted.
     * @param isComponentActivity whether the attached activity can host
     *   Meta's permission contract (FlutterFragmentActivity qualifies).
     */
    fun validate(
        metaData: Map<String, Any?>,
        declaredPermissions: Set<String>,
        grantedPermissions: Set<String>,
        isComponentActivity: Boolean?,
        sdkInt: Int,
    ): List<Finding> {
        val findings = mutableListOf<Finding>()
        val appId = metaData[APPLICATION_ID]?.toString().orEmpty()
        val developerMode = appId.isEmpty() || appId == "0" || appId.startsWith("\${")
        if (!metaData.containsKey(APPLICATION_ID)) {
            findings += Finding(
                "applicationIdMissing", "error",
                "AndroidManifest.xml has no $APPLICATION_ID meta-data.",
                "Add <meta-data android:name=\"$APPLICATION_ID\" android:value=\"\${mwdat_application_id}\"/>.",
            )
        } else if (developerMode) {
            findings += Finding(
                "developerModeCredentials", "info",
                "APPLICATION_ID is empty or 0: registration only works in Developer Mode.",
                "For Beta/production release channels set APPLICATION_ID and CLIENT_TOKEN from Wearables Developer Center.",
            )
        } else if (metaData[CLIENT_TOKEN]?.toString().isNullOrEmpty()) {
            findings += Finding(
                "clientTokenMissing", "error",
                "$CLIENT_TOKEN is empty while APPLICATION_ID is set.",
                "Copy the client token from your Wearables Developer Center app.",
            )
        }
        if (metaData.containsKey(DAM_ENABLED)) {
            findings += Finding(
                "damEnabledIgnored", "info",
                "$DAM_ENABLED is ignored since DAT 0.9.",
                "Remove the DAM_ENABLED meta-data entry.",
            )
        }
        for (perm in listOf(
            "android.permission.BLUETOOTH",
            "android.permission.BLUETOOTH_CONNECT",
            "android.permission.INTERNET",
        )) {
            if (perm !in declaredPermissions) {
                findings += Finding(
                    "permission.${perm.substringAfterLast('.')}", "error",
                    "$perm is not declared in AndroidManifest.xml.",
                    "Add <uses-permission android:name=\"$perm\"/>.",
                )
            }
        }
        if ("android.permission.BLUETOOTH_CONNECT" !in grantedPermissions) {
            findings += Finding(
                "bluetoothConnectNotGranted", "warning",
                "BLUETOOTH_CONNECT is not granted yet; the SDK is initialised once it is.",
                "Call MetaWearablesDat.requestAndroidPermissions() before using glasses APIs.",
            )
        }
        if (sdkInt >= 33 && "android.permission.POST_NOTIFICATIONS" !in grantedPermissions) {
            findings += Finding(
                "postNotificationsNotGranted", "info",
                "POST_NOTIFICATIONS is not granted; the background-streaming notification will be hidden.",
                "Request POST_NOTIFICATIONS before enableBackgroundStreaming() on Android 13+.",
            )
        }
        if (isComponentActivity == false) {
            findings += Finding(
                "activityNotComponentActivity", "error",
                "The host activity is not a ComponentActivity; Meta's permission contract cannot run.",
                "Make MainActivity extend FlutterFragmentActivity.",
            )
        }
        return findings
    }
}
