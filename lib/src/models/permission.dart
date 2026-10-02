/// A wearable permission, granted by the user in the Meta AI app.
enum Permission {
  /// Glasses camera.
  camera,

  /// Glasses microphone (needed by experimental Speech).
  microphone;

  /// The wire name sent to the platform.
  String get value => name;
}

/// Result of a permission check or request.
enum PermissionStatus {
  /// Granted.
  granted,

  /// Denied or not granted yet.
  denied;

  /// Parses the wire name; anything else maps to [denied].
  static PermissionStatus fromWire(Object? raw) =>
      raw == 'granted' ? granted : denied;

  /// The wire name sent to the platform.
  String get value => name;

  /// Whether the permission is granted.
  bool get isGranted => this == granted;
}
