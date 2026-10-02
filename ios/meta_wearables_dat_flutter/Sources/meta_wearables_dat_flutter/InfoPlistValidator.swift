// Pure validation of the host app's Info.plist against everything Meta's
// DAT 1.0 SDK requires. Used by `dumpDiagnostics()` so developers see
// configuration problems before a registration or session fails.
//
// Kept free of SDK and UIKit types so it is unit-testable with plain
// dictionaries.

import Foundation

struct InfoPlistFinding: Equatable {
  enum Severity: String { case error, warning, info }

  let id: String
  let severity: Severity
  let message: String
  let fix: String

  var map: [String: Any] {
    ["id": id, "severity": severity.rawValue, "message": message, "fix": fix]
  }
}

enum InfoPlistValidator {
  /// Background modes the DAT 1.0 binary checks at runtime.
  static let requiredBackgroundModes = ["bluetooth-central", "external-accessory"]
  /// Background modes Meta's samples declare for reliable connectivity.
  static let recommendedBackgroundModes = ["bluetooth-peripheral", "processing"]
  static let accessoryProtocol = "com.meta.ar.wearable"

  static func validate(_ info: [String: Any]) -> [InfoPlistFinding] {
    var findings: [InfoPlistFinding] = []

    let urlSchemes = (info["CFBundleURLTypes"] as? [[String: Any]] ?? [])
      .compactMap { $0["CFBundleURLSchemes"] as? [String] }
      .flatMap { $0 }

    guard let mwdat = info["MWDAT"] as? [String: Any] else {
      findings.append(InfoPlistFinding(
        id: "mwdatMissing", severity: .error,
        message: "Info.plist has no MWDAT dictionary.",
        fix: "Add an MWDAT dictionary with AppLinkURLScheme, MetaAppID, ClientToken and TeamID."))
      return findings + validateCapabilities(info)
    }

    // AppLinkURLScheme
    let appLink = (mwdat["AppLinkURLScheme"] as? String) ?? ""
    if appLink.isEmpty {
      findings.append(InfoPlistFinding(
        id: "appLinkUrlSchemeMissing", severity: .error,
        message: "MWDAT.AppLinkURLScheme is missing or empty.",
        fix: "Set MWDAT.AppLinkURLScheme to your callback scheme followed by ://, e.g. myapp://"))
    } else {
      if !appLink.hasSuffix("://") {
        findings.append(InfoPlistFinding(
          id: "appLinkUrlSchemeSuffix", severity: .error,
          message: "MWDAT.AppLinkURLScheme '\(appLink)' does not end with ://.",
          fix: "Append :// to the scheme. If you preprocess Info.plist, // is stripped unless you use -traditional-cpp."))
      }
      let scheme = appLink.replacingOccurrences(of: "://", with: "")
      if !isValidScheme(scheme) {
        findings.append(InfoPlistFinding(
          id: "appLinkUrlSchemeInvalid", severity: .error,
          message: "URL scheme '\(scheme)' is not RFC 3986 compliant.",
          fix: "Use only letters, digits, '+', '-' and '.', starting with a letter (no underscores)."))
      }
      if !scheme.isEmpty && !urlSchemes.contains(scheme) {
        findings.append(InfoPlistFinding(
          id: "appLinkUrlSchemeNotRegistered", severity: .error,
          message: "Scheme '\(scheme)' is not declared in CFBundleURLTypes.",
          fix: "Add '\(scheme)' to CFBundleURLTypes > CFBundleURLSchemes."))
      }
    }

    // Credentials
    let appId = (mwdat["MetaAppID"] as? String) ?? ""
    let developerMode = appId.isEmpty || appId == "0" || appId.hasPrefix("$(")
    if developerMode {
      findings.append(InfoPlistFinding(
        id: "developerModeCredentials", severity: .info,
        message: "MWDAT.MetaAppID is empty, 0 or an unexpanded build variable: registration only works in Developer Mode.",
        fix: "For Beta/production release channels set MetaAppID, ClientToken and TeamID from Wearables Developer Center."))
    } else {
      if ((mwdat["ClientToken"] as? String) ?? "").isEmpty {
        findings.append(InfoPlistFinding(
          id: "clientTokenMissing", severity: .error,
          message: "MWDAT.ClientToken is empty while MetaAppID is set.",
          fix: "Copy the client token from your Wearables Developer Center app."))
      }
      if ((mwdat["TeamID"] as? String) ?? "").isEmpty {
        findings.append(InfoPlistFinding(
          id: "teamIdMissing", severity: .error,
          message: "MWDAT.TeamID is empty while MetaAppID is set.",
          fix: "Set TeamID to your Apple Developer Team ID, e.g. $(DEVELOPMENT_TEAM)."))
      }
    }

    if mwdat["DAMEnabled"] != nil {
      findings.append(InfoPlistFinding(
        id: "damEnabledIgnored", severity: .info,
        message: "MWDAT.DAMEnabled is ignored since DAT 0.9.",
        fix: "Remove the DAMEnabled key."))
    }

    return findings + validateCapabilities(info)
  }

  private static func validateCapabilities(_ info: [String: Any]) -> [InfoPlistFinding] {
    var findings: [InfoPlistFinding] = []
    let modes = info["UIBackgroundModes"] as? [String] ?? []
    for mode in requiredBackgroundModes where !modes.contains(mode) {
      findings.append(InfoPlistFinding(
        id: "backgroundMode.\(mode)", severity: .error,
        message: "UIBackgroundModes must contain '\(mode)' (checked by the DAT SDK).",
        fix: "Add '\(mode)' to UIBackgroundModes."))
    }
    for mode in recommendedBackgroundModes where !modes.contains(mode) {
      findings.append(InfoPlistFinding(
        id: "backgroundMode.\(mode)", severity: .warning,
        message: "UIBackgroundModes does not contain '\(mode)' (declared by Meta's samples).",
        fix: "Add '\(mode)' to UIBackgroundModes."))
    }
    if modes.contains("audio") && ((info["NSMicrophoneUsageDescription"] as? String) ?? "").isEmpty {
      findings.append(InfoPlistFinding(
        id: "microphoneUsageMissing", severity: .warning,
        message: "UIBackgroundModes contains 'audio' but NSMicrophoneUsageDescription is missing.",
        fix: "Add NSMicrophoneUsageDescription, or drop the audio mode if you do not record the glasses microphone."))
    }

    let protocols = info["UISupportedExternalAccessoryProtocols"] as? [String] ?? []
    if !protocols.contains(accessoryProtocol) {
      findings.append(InfoPlistFinding(
        id: "externalAccessoryProtocol", severity: .error,
        message: "UISupportedExternalAccessoryProtocols must contain '\(accessoryProtocol)'.",
        fix: "Add '\(accessoryProtocol)' to UISupportedExternalAccessoryProtocols."))
    }

    if ((info["NSLocalNetworkUsageDescription"] as? String) ?? "").isEmpty {
      findings.append(InfoPlistFinding(
        id: "localNetworkUsageMissing", severity: .error,
        message: "NSLocalNetworkUsageDescription must be present and non-empty (Wi-Fi link).",
        fix: "Add a user-facing NSLocalNetworkUsageDescription string."))
    }
    let bonjour = info["NSBonjourServices"] as? [String] ?? []
    if !bonjour.contains("_bonjour._tcp") {
      findings.append(InfoPlistFinding(
        id: "bonjourServices", severity: .warning,
        message: "NSBonjourServices does not contain '_bonjour._tcp'.",
        fix: "Add '_bonjour._tcp' to NSBonjourServices."))
    }
    if ((info["NSBluetoothAlwaysUsageDescription"] as? String) ?? "").isEmpty {
      findings.append(InfoPlistFinding(
        id: "bluetoothUsageMissing", severity: .error,
        message: "NSBluetoothAlwaysUsageDescription is missing.",
        fix: "Add a user-facing NSBluetoothAlwaysUsageDescription string."))
    }
    return findings
  }

  /// RFC 3986 scheme: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
  static func isValidScheme(_ scheme: String) -> Bool {
    guard let first = scheme.unicodeScalars.first, CharacterSet.letters.contains(first),
      scheme.allSatisfy({ $0.isASCII })
    else { return false }
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+-."))
    return scheme.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  /// Reads the MWDAT opt-out flags for diagnostics.
  static func optOut(_ info: [String: Any], key: String) -> Bool {
    let mwdat = info["MWDAT"] as? [String: Any] ?? [:]
    let section = mwdat[key] as? [String: Any] ?? [:]
    return (section["OptOut"] as? Bool) ?? false
  }
}
