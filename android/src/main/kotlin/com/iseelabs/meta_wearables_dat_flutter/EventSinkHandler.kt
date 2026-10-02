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

class EventSinkHandler(
    /**
     * State channels replay their latest value to each new listener, so a
     * listener that subscribes after a transition still sees the current
     * state.
     */
    private val replaysLast: Boolean = false,
) : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var last: Any? = null

    @Volatile
    private var hasLast = false

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
        if (replaysLast && hasLast) events.success(last)
        onSinkChange?.invoke(events)
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        onSinkChange?.invoke(null)
    }

    fun send(value: Any?) {
        if (replaysLast) {
            last = value
            hasLast = true
        }
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
