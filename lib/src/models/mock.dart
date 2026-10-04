/// Glasses models the Mock Device Kit can simulate.
enum MockGlassesModel {
  /// Ray-Ban Meta.
  rayBanMeta,

  /// Ray-Ban Meta Optics.
  rayBanMetaOptics,

  /// Oakley Meta HSTN.
  oakleyMetaHSTN,

  /// Oakley Meta Vanguard.
  oakleyMetaVanguard,

  /// Meta glasses.
  metaGlasses,

  /// Meta Ray-Ban Display (enables the Display capability).
  metaRayBanDisplay,
}

/// Transcription source for the mock speech service.
enum MockSpeechSource {
  /// Use `MetaWearablesDat.simulateMockTranscription`.
  injected,

  /// Use the phone's speech recogniser on live audio.
  liveDeviceAsr,
}
