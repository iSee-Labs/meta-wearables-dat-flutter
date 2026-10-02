// Contract for the experimental DAT 1.0 modules (mwdat-inputs,
// mwdat-motion, mwdat-speech). Meta marks them @Unpublishable: apps can
// build and test with them but cannot ship to production release channels.
//
// Two implementations exist and Gradle compiles exactly one:
//   src/experimental/kotlin    real bridges (default)
//   src/noexperimental/kotlin  stubs, when the app sets
//                              `mwdat.experimental=false`
// Both provide `createExperimentalCapabilities`.

package com.iseelabs.meta_wearables_dat_flutter

import android.net.Uri
import com.meta.wearable.dat.mockdevice.api.MockGlasses

interface ExperimentalCapabilities {
    val linked: Boolean

    val inputsState: EventSinkHandler
    val inputsEvents: EventSinkHandler
    val inputsErrors: EventSinkHandler
    val motionState: EventSinkHandler
    val motionSamples: EventSinkHandler
    val motionErrors: EventSinkHandler
    val speechState: EventSinkHandler
    val speechTranscriptions: EventSinkHandler
    val speechErrors: EventSinkHandler

    suspend fun startInputs(args: Map<*, *>)
    suspend fun stopInputs()
    suspend fun startMotion(args: Map<*, *>)
    suspend fun stopMotion()
    suspend fun startSpeech(args: Map<*, *>)
    suspend fun stopSpeech()

    fun mockInput(glasses: MockGlasses, args: Map<*, *>)
    fun mockMotionFeed(glasses: MockGlasses, args: Map<*, *>, uri: (String?) -> Uri)

    companion object {
        fun notLinked(module: String) = WireError(
            WireCategory.EXPERIMENTAL_NOT_LINKED, "notLinked",
            "$module is not linked. Remove `mwdat.experimental=false` from gradle.properties to use it.",
        )
    }
}
