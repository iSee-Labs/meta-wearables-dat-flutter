// A StreamHandler that hands its sink to the owning component.
//
// Every plugin event channel uses it: the owner sends values while Dart
// listens and nothing is produced otherwise (backpressure contract).
// `send` is safe from any thread; values are delivered on the main thread
// as Flutter requires.

package com.iseelabs.meta_wearables_dat_flutter

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

class EventSinkHandler : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    var sink: EventChannel.EventSink? = null
        private set

    var onSinkChange: ((EventChannel.EventSink?) -> Unit)? = null
        set(value) {
            field = value
            value?.invoke(sink)
        }

    val hasListener: Boolean get() = sink != null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        onSinkChange?.invoke(events)
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        onSinkChange?.invoke(null)
    }

    fun send(value: Any?) {
        if (sink == null) return
        if (Looper.myLooper() == Looper.getMainLooper()) {
            sink?.success(value)
        } else {
            main.post { sink?.success(value) }
        }
    }
}

/** Reports a plugin-level failure to every listener of a channel. */
class FailingStreamHandler(private val error: WireError) : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        events.error(error.category, error.message, error.details)
    }

    override fun onCancel(arguments: Any?) = Unit
}
