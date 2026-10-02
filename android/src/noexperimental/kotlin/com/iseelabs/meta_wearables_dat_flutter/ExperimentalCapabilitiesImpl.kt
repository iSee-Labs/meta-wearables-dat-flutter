// Stub used when the host app builds with `mwdat.experimental=false`:
// the experimental DAT modules are not linked and every call fails with
// EXPERIMENTAL_NOT_LINKED.

package com.iseelabs.meta_wearables_dat_flutter

import android.net.Uri
import com.meta.wearable.dat.mockdevice.api.MockGlasses
import kotlinx.coroutines.CoroutineScope

@Suppress("UNUSED_PARAMETER")
fun createExperimentalCapabilities(hub: DeviceSessionHub, scope: CoroutineScope): ExperimentalCapabilities =
    object : ExperimentalCapabilities {
        override val linked = false
        override val inputsState = EventSinkHandler(replaysLast = true)
        override val inputsEvents = EventSinkHandler()
        override val inputsErrors = EventSinkHandler()
        override val motionState = EventSinkHandler(replaysLast = true)
        override val motionSamples = EventSinkHandler()
        override val motionErrors = EventSinkHandler()
        override val speechState = EventSinkHandler(replaysLast = true)
        override val speechTranscriptions = EventSinkHandler()
        override val speechErrors = EventSinkHandler()

        override suspend fun startInputs(args: Map<*, *>) = throw ExperimentalCapabilities.notLinked("mwdat-inputs")
        override suspend fun stopInputs() = Unit
        override suspend fun startMotion(args: Map<*, *>) = throw ExperimentalCapabilities.notLinked("mwdat-motion")
        override suspend fun stopMotion() = Unit
        override suspend fun startSpeech(args: Map<*, *>) = throw ExperimentalCapabilities.notLinked("mwdat-speech")
        override suspend fun stopSpeech() = Unit
        override fun mockInput(glasses: MockGlasses, args: Map<*, *>) =
            throw ExperimentalCapabilities.notLinked("mwdat-inputs")
        override fun mockMotionFeed(glasses: MockGlasses, args: Map<*, *>, uri: (String?) -> Uri) =
            throw ExperimentalCapabilities.notLinked("mwdat-motion")
    }
