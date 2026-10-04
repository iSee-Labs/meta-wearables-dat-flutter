/// Camera stream resolution. The SDK may lower it under poor bandwidth.
enum StreamQuality {
  /// 360 x 640.
  low(0, 360, 640),

  /// 504 x 896.
  medium(1, 504, 896),

  /// 720 x 1280.
  high(2, 720, 1280);

  const StreamQuality(this.value, this.width, this.height);

  /// Ordinal kept for compatibility.
  final int value;

  /// Nominal width in pixels (portrait).
  final int width;

  /// Nominal height in pixels (portrait).
  final int height;

  /// Frame rates the SDK accepts.
  static const List<int> fpsValues = [2, 7, 15, 24, 30];
}

/// Frame rates the DAT SDK accepts. Under limited bandwidth the SDK lowers
/// resolution first, then frame rate, but never below 15 fps.
enum StreamFrameRate {
  /// 2 fps.
  fps2(2),

  /// 7 fps.
  fps7(7),

  /// 15 fps.
  fps15(15),

  /// 24 fps (SDK default).
  fps24(24),

  /// 30 fps.
  fps30(30);

  const StreamFrameRate(this.value);

  /// Frames per second.
  final int value;

  /// Returns the matching rate, or throws [ArgumentError] for unsupported
  /// values.
  static StreamFrameRate fromFps(int fps) => values.firstWhere(
    (rate) => rate.value == fps,
    orElse: () => throw ArgumentError.value(
      fps,
      'fps',
      'Must be one of 2, 7, 15, 24, 30',
    ),
  );
}
