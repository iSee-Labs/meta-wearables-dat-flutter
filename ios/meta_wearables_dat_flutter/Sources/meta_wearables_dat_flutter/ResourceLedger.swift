// Counts the native resources the plugin holds so `dumpDiagnostics()` can
// report them and integration tests can prove every `stop*` call released
// everything it acquired (textures, listeners, sessions, decoders).

import Foundation

@MainActor
final class ResourceLedger {
  static let shared = ResourceLedger()

  enum Kind: String, CaseIterable {
    case textures
    case listeners
    case deviceSessions
    case cameras
    case displays
    case decoders
    case capabilities
    case mockDevices
  }

  private var counts: [Kind: Int] = [:]

  func acquire(_ kind: Kind, _ amount: Int = 1) {
    counts[kind, default: 0] += amount
  }

  func release(_ kind: Kind, _ amount: Int = 1) {
    counts[kind, default: 0] = max(0, counts[kind, default: 0] - amount)
  }

  func set(_ kind: Kind, _ value: Int) {
    counts[kind] = max(0, value)
  }

  func snapshot() -> [String: Int] {
    var map: [String: Int] = [:]
    for kind in Kind.allCases { map[kind.rawValue] = counts[kind, default: 0] }
    return map
  }
}
