import 'package:meta/meta.dart';

/// State of the experimental Speech capability.
@experimental
enum SpeechState {
  /// Starting.
  starting,

  /// Listening.
  started,

  /// Stopping.
  stopping,

  /// Stopped.
  stopped;

  /// Parses the wire name; unknown values map to [stopped].
  static SpeechState fromWire(Object? raw) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return stopped;
  }
}

/// On-device transcription from the glasses microphone. Requires the
/// microphone permission.
///
/// **Experimental:** cannot be used in apps on production release channels.
@experimental
class TranscriptionResult {
  /// Creates a [TranscriptionResult].
  const TranscriptionResult({
    required this.text,
    required this.isFinal,
    this.confidence,
  });

  /// Decodes a platform-channel map.
  factory TranscriptionResult.fromMap(Map<Object?, Object?> map) {
    final confidence = (map['confidence'] as num?)?.toDouble();
    return TranscriptionResult(
      text: map['text'] as String? ?? '',
      isFinal: map['isFinal'] as bool? ?? false,
      confidence: confidence == null || confidence < 0 ? null : confidence,
    );
  }

  /// Transcribed text.
  final String text;

  /// Whether this is the final result for the utterance.
  final bool isFinal;

  /// Confidence 0-1, or `null` when unavailable.
  final double? confidence;
}
