import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Resolution of an experimental high-resolution photo. [full] is
/// 4032 x 3024.
@experimental
enum PhotoResolution {
  /// Small.
  small,

  /// Medium (default).
  medium,

  /// Large.
  large,

  /// Full sensor resolution.
  full,
}

/// Compression quality of an experimental high-resolution photo.
@experimental
enum PhotoQuality {
  /// Low.
  low,

  /// Medium (default).
  medium,

  /// High.
  high,
}

/// State of the experimental photo capability.
@experimental
enum PhotoState {
  /// Stopped.
  stopped,

  /// Starting.
  starting,

  /// Ready to capture.
  started,

  /// Stopping.
  stopping;

  /// Parses the wire name; unknown values map to [stopped].
  static PhotoState fromWire(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return stopped;
  }
}

/// A photo from the experimental `Camera.photo` capability.
///
/// **Experimental:** cannot be used in apps on production release channels.
@experimental
class HighResPhoto {
  /// Creates a [HighResPhoto].
  const HighResPhoto({required this.bytes, this.metadata, this.timestamp});

  /// Decodes a platform-channel map.
  factory HighResPhoto.fromMap(Map<Object?, Object?> map) {
    final ts = (map['timestampMs'] as num?)?.toInt();
    return HighResPhoto(
      bytes: map['bytes'] as Uint8List? ?? Uint8List(0),
      metadata: map['metadata'] as Uint8List?,
      timestamp: ts == null ? null : DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  /// Encoded image bytes.
  final Uint8List bytes;

  /// Raw metadata from the glasses, when provided.
  final Uint8List? metadata;

  /// Capture time, when reported.
  final DateTime? timestamp;
}

/// Transfer progress of an experimental high-resolution photo.
@experimental
class PhotoTransferProgress {
  /// Creates a [PhotoTransferProgress].
  const PhotoTransferProgress({
    required this.bytesReceived,
    required this.totalBytes,
  });

  /// Decodes a platform-channel map.
  factory PhotoTransferProgress.fromMap(Map<Object?, Object?> map) =>
      PhotoTransferProgress(
        bytesReceived: (map['bytesReceived'] as num?)?.toInt() ?? 0,
        totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      );

  /// Bytes received so far.
  final int bytesReceived;

  /// Total bytes, or 0 when unknown.
  final int totalBytes;

  /// Progress from 0 to 1.
  double get fraction =>
      totalBytes <= 0 ? 0 : (bytesReceived / totalBytes).clamp(0, 1).toDouble();
}
