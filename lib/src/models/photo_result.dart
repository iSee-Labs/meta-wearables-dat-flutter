import 'dart:typed_data';

/// Encoding of a photo captured from the stream.
enum PhotoFormat {
  /// JPEG.
  jpeg,

  /// HEIC. Android returns JPEG when the glasses deliver an uncompressed
  /// bitmap; check [PhotoResult.format].
  heic,
}

/// A photo captured from the running stream.
class PhotoResult {
  /// Creates a [PhotoResult].
  const PhotoResult({required this.bytes, required this.format});

  /// Encoded image bytes.
  final Uint8List bytes;

  /// The actual encoding of [bytes].
  final PhotoFormat format;
}
