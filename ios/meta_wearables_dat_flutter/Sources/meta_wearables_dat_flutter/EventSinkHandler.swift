// A `FlutterStreamHandler` that hands its sink to an owner callback.
//
// Every plugin event channel uses this handler: the owning component keeps
// the sink while Dart listens and drops it on cancel, so no work happens
// when nobody listens (backpressure contract). The callback is replayed
// when it is (re)assigned so lazily-created owners catch up on listeners
// that subscribed first. `arguments` exposes the listen arguments, used by
// per-device channels such as `device_state`.

import Flutter
import Foundation

final class EventSinkHandler: NSObject, FlutterStreamHandler {
  var onSinkChange: ((FlutterEventSink?, Any?) -> Void)? {
    didSet { onSinkChange?(sink, arguments) }
  }
  private(set) var sink: FlutterEventSink?
  private(set) var arguments: Any?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    self.arguments = arguments
    sink = events
    onSinkChange?(events, arguments)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    self.arguments = nil
    onSinkChange?(nil, arguments)
    return nil
  }

  /// Emits `value` when a listener is attached; a no-op otherwise.
  func send(_ value: Any?) {
    sink?(value ?? NSNull())
  }

  var hasListener: Bool { sink != nil }
}
