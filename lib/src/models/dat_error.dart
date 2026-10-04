import 'package:meta/meta.dart';

/// Error categories. Every failure from the plugin carries one of these in
/// [DatError.category] (and in `PlatformException.code` on the wire).
abstract final class DatErrorCodes {
  /// Registration with the Meta AI app failed.
  static const String registration = 'REGISTRATION_ERROR';

  /// Unregistration from the Meta AI app failed.
  static const String unregistration = 'UNREGISTRATION_ERROR';

  /// A callback URL could not be handled.
  static const String handleUrl = 'HANDLE_URL_ERROR';

  /// A Meta AI-initiated registration request could not be answered.
  static const String registrationRequest = 'REGISTRATION_REQUEST_ERROR';

  /// A wearable permission request or check failed.
  static const String permission = 'PERMISSION_ERROR';

  /// Opening a Meta AI update screen failed.
  static const String navigation = 'NAVIGATION_ERROR';

  /// The device session failed or reported a problem.
  static const String deviceSession = 'DEVICE_SESSION_ERROR';

  /// The camera stream failed or reported a problem.
  static const String stream = 'STREAM_ERROR';

  /// Former name of [stream].
  @Deprecated('Use DatErrorCodes.stream')
  static const String session = 'SESSION_ERROR';

  /// A photo capture from the stream failed.
  static const String capture = 'CAPTURE_ERROR';

  /// The experimental high-resolution photo capture failed.
  static const String photo = 'PHOTO_ERROR';

  /// The display session failed or reported a problem.
  static const String display = 'DISPLAY_ERROR';

  /// The experimental Inputs capability failed.
  static const String inputs = 'INPUTS_ERROR';

  /// The experimental Motion capability failed.
  static const String motion = 'MOTION_ERROR';

  /// The experimental Speech capability failed.
  static const String speech = 'SPEECH_ERROR';

  /// The experimental voice invocations stream failed.
  static const String voiceInvocation = 'VOICE_INVOCATION_ERROR';

  /// A Mock Device Kit call failed.
  static const String mock = 'MOCK_ERROR';

  /// The plugin rejected an argument before calling the SDK.
  static const String invalidArgument = 'INVALID_ARGUMENT';

  /// The call is not supported on this platform.
  static const String notSupported = 'NOT_SUPPORTED';

  /// An experimental module is not linked into this build.
  static const String experimentalNotLinked = 'EXPERIMENTAL_NOT_LINKED';

  /// The plugin itself failed (for example, the SDK is not configured).
  static const String plugin = 'PLUGIN_ERROR';

  /// Former Android code for a missing `FlutterFragmentActivity`; now
  /// reported as [PermissionError] with
  /// [PermissionErrorCase.missingFragmentActivity].
  @Deprecated('Use PermissionErrorCase.missingFragmentActivity')
  static const String missingFragmentActivity = 'MISSING_FRAGMENT_ACTIVITY';
}

/// What the app can do to recover from an error, following Meta's handling
/// guidance for DAT version and compatibility errors.
enum DatRecoveryAction {
  /// Nothing specific; show the message or retry.
  none,

  /// Ask the user to update the glasses firmware
  /// (`MetaWearablesDat.openFirmwareUpdate`).
  openFirmwareUpdate,

  /// Ask the user to update the DAT app on the glasses
  /// (`MetaWearablesDat.openDatGlassesAppUpdate`).
  openDatGlassesAppUpdate,

  /// A new build of this app with a newer SDK is required.
  updateHostApp,

  /// Non-blocking: suggest an update occasionally, keep going.
  suggestUpdate,

  /// Check the glasses setup in the Meta AI app, then retry.
  checkMetaAiAndRetry,

  /// Pair, power on or wear the glasses, then retry.
  connectGlasses,

  /// Grant the missing permission, then retry.
  grantPermission,
}

T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Base class of every error the plugin reports.
///
/// Errors are sealed per category so a `switch` over a [DatError] is
/// exhaustive. Each subclass exposes a typed `reason`; [code] is its wire
/// name.
///
/// ```dart
/// try {
///   await MetaWearablesDat.startStreamSession();
/// } on DeviceSessionError catch (e) {
///   if (e.reason == DeviceSessionErrorCase.noEligibleDevice) { ... }
/// }
/// ```
sealed class DatError implements Exception {
  const DatError({
    required this.category,
    required this.message,
    this.platformCase,
    this.details = const <String, Object?>{},
  });

  /// The error category, one of [DatErrorCodes].
  final String category;

  /// Human-readable description from the SDK or the plugin. Suitable for
  /// developers; localise before showing it to end users.
  final String message;

  /// The raw native case name (for example `HINGE_CLOSED` on Android), kept
  /// for diagnostics.
  final String? platformCase;

  /// Extra structured data sent with the error.
  final Map<String, Object?> details;

  /// The canonical case name, shared by iOS and Android (for example
  /// `hingesClosed`). `unknown` when the native case is not recognised.
  String get code;

  /// The platform that reported the error (`ios` or `android`), if known.
  String? get platform => details['platform'] as String?;

  /// Suggested recovery action.
  DatRecoveryAction get recoveryAction => DatRecoveryAction.none;

  @override
  String toString() => '$category/$code: $message';
}

/// Shared constructor arguments for the concrete error classes.
sealed class _TypedDatError<C extends Enum> extends DatError {
  const _TypedDatError({
    required this.reason,
    required super.category,
    required super.message,
    super.platformCase,
    super.details,
  });

  /// The typed reason for this error.
  final C reason;

  @override
  String get code => reason.name;
}

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

/// Reasons for a [RegistrationError].
enum RegistrationErrorCase {
  /// The app is already registered.
  alreadyRegistered,

  /// The app is already unregistered (Android reports this on the shared
  /// registration error stream).
  alreadyUnregistered,

  /// The MWDAT configuration (Info.plist / AndroidManifest) is invalid.
  configurationInvalid,

  /// The Meta AI app is not installed.
  metaAINotInstalled,

  /// No network connection was available.
  networkUnavailable,

  /// Android: registration failed in the Meta AI app.
  failedToRegister,

  /// Android: unregistration failed in the Meta AI app.
  failedToUnregister,

  /// The request timed out.
  timeout,

  /// Android: no Activity was attached to start the flow.
  noActivity,

  /// Any other reason.
  unknown,
}

/// Registration with the Meta AI app failed.
final class RegistrationError extends _TypedDatError<RegistrationErrorCase> {
  /// Creates a [RegistrationError].
  const RegistrationError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.registration);

  /// Decodes a wire error.
  factory RegistrationError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => RegistrationError(
    reason: _byName(
      RegistrationErrorCase.values,
      code,
      RegistrationErrorCase.unknown,
    ),
    message: message,
    platformCase: platformCase,
    details: details,
  );

  /// Whether the MWDAT configuration is invalid.
  @Deprecated('Use reason == RegistrationErrorCase.configurationInvalid')
  bool get isConfigurationInvalid =>
      reason == RegistrationErrorCase.configurationInvalid;

  /// Whether the Meta AI app is not installed.
  @Deprecated('Use reason == RegistrationErrorCase.metaAINotInstalled')
  bool get isMetaAiNotInstalled =>
      reason == RegistrationErrorCase.metaAINotInstalled;

  /// Whether the app is already registered.
  @Deprecated('Use reason == RegistrationErrorCase.alreadyRegistered')
  bool get isAlreadyRegistered =>
      reason == RegistrationErrorCase.alreadyRegistered;

  /// Whether no network connection was available.
  @Deprecated('Use reason == RegistrationErrorCase.networkUnavailable')
  bool get isNetworkUnavailable =>
      reason == RegistrationErrorCase.networkUnavailable;
}

/// Reasons for an [UnregistrationError].
enum UnregistrationErrorCase {
  /// The app is not registered.
  alreadyUnregistered,

  /// The MWDAT configuration is invalid.
  configurationInvalid,

  /// The Meta AI app is not installed.
  metaAINotInstalled,

  /// Android: unregistration failed in the Meta AI app.
  failedToUnregister,

  /// The request timed out.
  timeout,

  /// Android: no Activity was attached to start the flow.
  noActivity,

  /// Any other reason.
  unknown,
}

/// Unregistration from the Meta AI app failed.
final class UnregistrationError
    extends _TypedDatError<UnregistrationErrorCase> {
  /// Creates an [UnregistrationError].
  const UnregistrationError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.unregistration);

  /// Decodes a wire error.
  factory UnregistrationError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => UnregistrationError(
    reason: _byName(
      UnregistrationErrorCase.values,
      code,
      UnregistrationErrorCase.unknown,
    ),
    message: message,
    platformCase: platformCase,
    details: details,
  );

  /// Whether the app was not registered.
  @Deprecated('Use reason == UnregistrationErrorCase.alreadyUnregistered')
  bool get isNotRegistered =>
      reason == UnregistrationErrorCase.alreadyUnregistered;
}

/// Reasons for a [HandleUrlError].
enum HandleUrlErrorCase {
  /// The URL carried a registration result that failed.
  registrationError,

  /// The URL carried an unregistration result that failed.
  unregistrationError,

  /// The string is not a valid URL.
  invalidUrl,

  /// Any other reason.
  unknown,
}

/// A callback URL could not be handled.
final class HandleUrlError extends _TypedDatError<HandleUrlErrorCase> {
  /// Creates a [HandleUrlError].
  const HandleUrlError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.handleUrl);

  /// Decodes a wire error.
  factory HandleUrlError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => HandleUrlError(
    reason: _byName(
      HandleUrlErrorCase.values,
      code,
      HandleUrlErrorCase.unknown,
    ),
    message: message,
    platformCase: platformCase,
    details: details,
  );

  /// Whether the URL was invalid.
  @Deprecated('Use reason == HandleUrlErrorCase.invalidUrl')
  bool get isInvalidUrl => reason == HandleUrlErrorCase.invalidUrl;
}

/// Reasons for a [RegistrationRequestError].
enum RegistrationRequestErrorCase {
  /// The request was malformed.
  invalidRequest,

  /// The request was already answered or has expired.
  alreadyHandled,

  /// The MWDAT configuration is invalid.
  configurationInvalid,

  /// No network connection was available.
  networkUnavailable,

  /// The Meta AI app is not installed.
  metaAINotInstalled,

  /// Continuing the registration failed.
  registrationFailed,

  /// Cancelling the registration failed.
  cancellationFailed,

  /// Android: no Activity was attached to continue the flow.
  noActivity,

  /// Any other reason.
  unknown,
}

/// A Meta AI-initiated registration request could not be answered.
final class RegistrationRequestError
    extends _TypedDatError<RegistrationRequestErrorCase> {
  /// Creates a [RegistrationRequestError].
  const RegistrationRequestError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.registrationRequest);

  /// Decodes a wire error.
  factory RegistrationRequestError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => RegistrationRequestError(
    reason: _byName(
      RegistrationRequestErrorCase.values,
      code,
      RegistrationRequestErrorCase.unknown,
    ),
    message: message,
    platformCase: platformCase,
    details: details,
  );
}

// ---------------------------------------------------------------------------
// Permissions & navigation
// ---------------------------------------------------------------------------

/// Reasons for a [PermissionError].
enum PermissionErrorCase {
  /// No glasses are paired.
  noDevice,

  /// No paired glasses are connected.
  noDeviceWithConnection,

  /// The connection to the glasses failed.
  connectionError,

  /// The Meta AI app is not installed.
  metaAINotInstalled,

  /// Another permission request is in progress.
  requestInProgress,

  /// The request timed out.
  requestTimeout,

  /// An internal SDK error.
  internalError,

  /// Android: the host activity is not a `FlutterFragmentActivity`.
  missingFragmentActivity,

  /// Android: no Activity is attached.
  noActivity,

  /// Any other reason.
  unknown,
}

/// A wearable permission request or check failed.
final class PermissionError extends _TypedDatError<PermissionErrorCase> {
  /// Creates a [PermissionError].
  const PermissionError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.permission);

  /// Decodes a wire error.
  factory PermissionError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => PermissionError(
    reason: _byName(
      PermissionErrorCase.values,
      code,
      PermissionErrorCase.unknown,
    ),
    message: message,
    platformCase: platformCase,
    details: details,
  );

  /// Whether the host activity cannot run Meta's permission flow.
  @Deprecated('Use reason == PermissionErrorCase.missingFragmentActivity')
  bool get isMissingFragmentActivity =>
      reason == PermissionErrorCase.missingFragmentActivity;

  /// Always false: denial is reported as `PermissionStatus.denied`, not an
  /// error.
  @Deprecated('Denial is returned as PermissionStatus.denied')
  bool get isDenied => false;

  @override
  DatRecoveryAction get recoveryAction => switch (reason) {
    PermissionErrorCase.noDevice ||
    PermissionErrorCase.noDeviceWithConnection =>
      DatRecoveryAction.connectGlasses,
    _ => DatRecoveryAction.none,
  };
}

/// Reasons for a [NavigationError].
enum NavigationErrorCase {
  /// The Meta AI app is not installed.
  metaAINotInstalled,

  /// The app is not registered.
  notRegistered,

  /// Android: no Activity is attached.
  noActivity,

  /// Any other reason.
  unknown,
}

/// Opening a Meta AI update screen failed.
final class NavigationError extends _TypedDatError<NavigationErrorCase> {
  /// Creates a [NavigationError].
  const NavigationError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.navigation);

  /// Decodes a wire error.
  factory NavigationError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => NavigationError(
    reason: _byName(
      NavigationErrorCase.values,
      code,
      NavigationErrorCase.unknown,
    ),
    message: message,
    platformCase: platformCase,
    details: details,
  );
}

// ---------------------------------------------------------------------------
// Device session
// ---------------------------------------------------------------------------

/// Reasons for a [DeviceSessionError].
enum DeviceSessionErrorCase {
  /// No paired, connected glasses match the request.
  noEligibleDevice,

  /// The session was already stopped.
  sessionAlreadyStopped,

  /// A session already exists (only one per app and device).
  sessionAlreadyExists,

  /// The session has not started yet.
  sessionIdle,

  /// The capability is already attached to the session.
  capabilityAlreadyActive,

  /// The capability is not attached to the session.
  capabilityNotFound,

  /// Android: the capability is not enabled for this user.
  capabilityDenied,

  /// Android: the device disconnected.
  deviceDisconnected,

  /// Android: the device ended the session.
  sessionEndedByDevice,

  /// An unexpected SDK error; see [DatError.details] `reason`.
  unexpectedError,

  /// The glasses are critically hot.
  thermalCritical,

  /// The glasses hit a thermal emergency.
  thermalEmergency,

  /// The glasses shut down on peak power.
  peakPowerShutdown,

  /// The glasses battery is critically low.
  batteryCritical,

  /// The DAT app on the glasses must be updated.
  datAppOnTheGlassesUpdateRequired,

  /// The DAT app on the glasses did not become reachable.
  dwaUnavailable,

  /// This app's SDK is too old for the glasses. Terminal: ship a new build.
  insufficientSDKVersion,

  /// App and glasses versions are outside the recommended range.
  /// Non-blocking warning.
  dwaOutOfStuRange,

  /// The glasses did not connect within the start timeout.
  startTimeout,

  /// The session stopped before it reached `started`.
  stoppedBeforeStart,

  /// Any other reason.
  unknown,
}

/// The device session failed or reported a problem.
final class DeviceSessionError extends _TypedDatError<DeviceSessionErrorCase> {
  /// Creates a [DeviceSessionError].
  const DeviceSessionError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.deviceSession);

  /// Decodes a wire error.
  factory DeviceSessionError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => DeviceSessionError(
    reason: _byName(
      DeviceSessionErrorCase.values,
      code,
      DeviceSessionErrorCase.unknown,
    ),
    message: message,
    platformCase: platformCase,
    details: details,
  );

  /// True when no recovery is possible in this app build
  /// ([DeviceSessionErrorCase.insufficientSDKVersion]).
  bool get isTerminal =>
      details['terminal'] == true ||
      reason == DeviceSessionErrorCase.insufficientSDKVersion;

  /// True for non-blocking warnings ([DeviceSessionErrorCase.dwaOutOfStuRange]);
  /// the session keeps running.
  bool get isWarning =>
      details['severity'] == 'warning' ||
      reason == DeviceSessionErrorCase.dwaOutOfStuRange;

  @override
  DatRecoveryAction get recoveryAction => switch (reason) {
    DeviceSessionErrorCase.datAppOnTheGlassesUpdateRequired =>
      DatRecoveryAction.openDatGlassesAppUpdate,
    DeviceSessionErrorCase.insufficientSDKVersion =>
      DatRecoveryAction.updateHostApp,
    DeviceSessionErrorCase.dwaOutOfStuRange => DatRecoveryAction.suggestUpdate,
    DeviceSessionErrorCase.dwaUnavailable =>
      DatRecoveryAction.checkMetaAiAndRetry,
    DeviceSessionErrorCase.noEligibleDevice ||
    DeviceSessionErrorCase.startTimeout ||
    DeviceSessionErrorCase.deviceDisconnected =>
      DatRecoveryAction.connectGlasses,
    _ => DatRecoveryAction.none,
  };

  /// Whether no eligible device was found.
  @Deprecated('Use reason == DeviceSessionErrorCase.noEligibleDevice')
  bool get isNoEligibleDevice =>
      reason == DeviceSessionErrorCase.noEligibleDevice;

  /// Whether the session was already stopped.
  @Deprecated('Use reason == DeviceSessionErrorCase.sessionAlreadyStopped')
  bool get isSessionAlreadyStopped =>
      reason == DeviceSessionErrorCase.sessionAlreadyStopped;

  /// Whether a session already exists.
  @Deprecated('Use reason == DeviceSessionErrorCase.sessionAlreadyExists')
  bool get isSessionAlreadyExists =>
      reason == DeviceSessionErrorCase.sessionAlreadyExists;

  /// Whether the session is idle.
  @Deprecated('Use reason == DeviceSessionErrorCase.sessionIdle')
  bool get isSessionIdle => reason == DeviceSessionErrorCase.sessionIdle;

  /// Whether the capability is already active.
  @Deprecated('Use reason == DeviceSessionErrorCase.capabilityAlreadyActive')
  bool get isCapabilityAlreadyActive =>
      reason == DeviceSessionErrorCase.capabilityAlreadyActive;

  /// Whether the capability was not found.
  @Deprecated('Use reason == DeviceSessionErrorCase.capabilityNotFound')
  bool get isCapabilityNotFound =>
      reason == DeviceSessionErrorCase.capabilityNotFound;

  /// Whether the DAT app on the glasses needs an update.
  @Deprecated(
    'Use reason == DeviceSessionErrorCase.datAppOnTheGlassesUpdateRequired',
  )
  bool get isDatAppUpdateRequired =>
      reason == DeviceSessionErrorCase.datAppOnTheGlassesUpdateRequired;

  /// Whether the SDK reported an unexpected error.
  @Deprecated('Use reason == DeviceSessionErrorCase.unexpectedError')
  bool get isUnexpectedError =>
      reason == DeviceSessionErrorCase.unexpectedError;
}

// ---------------------------------------------------------------------------
// Camera
// ---------------------------------------------------------------------------

/// Reasons for a [StreamError].
enum StreamErrorCase {
  /// An internal SDK error.
  internalError,

  /// The target device was not found.
  deviceNotFound,

  /// The target device is not connected.
  deviceNotConnected,

  /// The stream timed out.
  timeout,

  /// The video stream failed. On Android check [StreamError.isFatal].
  videoStreamingError,

  /// The experimental audio stream failed.
  audioStreamingError,

  /// Camera permission was denied.
  permissionDenied,

  /// The glasses were folded or taken off.
  hingesClosed,

  /// The glasses are too hot to stream.
  thermalHot,

  /// The glasses battery is too low to stream.
  batteryLow,

  /// The glasses hit their peak power limit.
  peakPowerLimit,

  /// A photo capture failed.
  photoCaptureFailed,

  /// The stream stopped before it started.
  stoppedBeforeStart,

  /// Android has no HEVC decoder; the `hvc1` preview stays empty.
  hevcDecoderUnavailable,

  /// iOS: raw frames pause while the app is in the background.
  rawPausedInBackground,

  /// iOS: the stream was stopped because the app moved to the background.
  stoppedInBackground,

  /// Any other reason.
  unknown,
}

/// The camera stream failed or reported a problem.
final class StreamError extends _TypedDatError<StreamErrorCase> {
  /// Creates a [StreamError].
  const StreamError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.stream);

  /// Decodes a wire error.
  factory StreamError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => StreamError(
    reason: _byName(StreamErrorCase.values, code, StreamErrorCase.unknown),
    message: message,
    platformCase: platformCase,
    details: details,
  );

  /// Android: the SDK reported `CRITICAL_STREAM_ERROR`; the stream stops.
  bool get isFatal => details['fatal'] == true;

  /// Informational events that do not stop the stream.
  bool get isWarning => details['severity'] == 'warning';

  @override
  DatRecoveryAction get recoveryAction => switch (reason) {
    StreamErrorCase.permissionDenied => DatRecoveryAction.grantPermission,
    StreamErrorCase.deviceNotConnected ||
    StreamErrorCase.deviceNotFound ||
    StreamErrorCase.hingesClosed => DatRecoveryAction.connectGlasses,
    _ => DatRecoveryAction.none,
  };

  /// Whether the glasses are thermally limited.
  @Deprecated('Use reason == StreamErrorCase.thermalHot')
  bool get isThermalCritical => reason == StreamErrorCase.thermalHot;

  /// Whether the hinges were closed.
  @Deprecated('Use reason == StreamErrorCase.hingesClosed')
  bool get isHingesClosed => reason == StreamErrorCase.hingesClosed;

  /// Whether camera permission was denied.
  @Deprecated('Use reason == StreamErrorCase.permissionDenied')
  bool get isPermissionDenied => reason == StreamErrorCase.permissionDenied;

  /// Whether the device disconnected.
  @Deprecated('Use reason == StreamErrorCase.deviceNotConnected')
  bool get isDeviceDisconnected => reason == StreamErrorCase.deviceNotConnected;

  /// Whether the video stream failed.
  @Deprecated('Use reason == StreamErrorCase.videoStreamingError')
  bool get isVideoStreamingError =>
      reason == StreamErrorCase.videoStreamingError;

  /// Whether an internal error occurred.
  @Deprecated('Use reason == StreamErrorCase.internalError')
  bool get isInternalError => reason == StreamErrorCase.internalError;

  /// Whether the stream timed out.
  @Deprecated('Use reason == StreamErrorCase.timeout')
  bool get isTimeout => reason == StreamErrorCase.timeout;
}

/// Former name of [StreamError].
@Deprecated('Use StreamError')
typedef SessionError = StreamError;

/// Former name of [StreamError].
@Deprecated('Use StreamError')
typedef StreamSessionError = StreamError;

/// Reasons for a [CaptureError].
enum CaptureErrorCase {
  /// The device disconnected during the capture.
  deviceDisconnected,

  /// No stream is running.
  notStreaming,

  /// Another capture is in progress.
  captureInProgress,

  /// The capture failed.
  captureFailed,

  /// No photo arrived in time.
  timeout,

  /// The stream stopped during the capture.
  sessionStopped,

  /// Any other reason.
  unknown,
}

/// A photo capture from the stream failed.
final class CaptureError extends _TypedDatError<CaptureErrorCase> {
  /// Creates a [CaptureError].
  const CaptureError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.capture);

  /// Decodes a wire error.
  factory CaptureError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => CaptureError(
    reason: _byName(CaptureErrorCase.values, code, CaptureErrorCase.unknown),
    message: message,
    platformCase: platformCase,
    details: details,
  );

  /// Whether the device disconnected.
  @Deprecated('Use reason == CaptureErrorCase.deviceDisconnected')
  bool get isDeviceDisconnected =>
      reason == CaptureErrorCase.deviceDisconnected;

  /// Whether another capture is in progress.
  @Deprecated('Use reason == CaptureErrorCase.captureInProgress')
  bool get isCaptureInProgress => reason == CaptureErrorCase.captureInProgress;

  /// Whether the capture failed.
  @Deprecated('Use reason == CaptureErrorCase.captureFailed')
  bool get isCaptureFailed => reason == CaptureErrorCase.captureFailed;

  /// Whether no stream was running.
  @Deprecated('Use reason == CaptureErrorCase.notStreaming')
  bool get isNotStreaming => reason == CaptureErrorCase.notStreaming;
}

/// Reasons for a [PhotoError].
@experimental
enum PhotoErrorCase {
  /// The photo capability is not ready.
  notReady,

  /// The capture failed.
  captureFailure,

  /// Setting up the photo capability failed.
  sessionSetupFailed,

  /// A capture is already in progress.
  busy,

  /// The photo service is unavailable.
  serviceUnavailable,

  /// Camera permission was denied.
  permissionDenied,

  /// The device is too hot or its battery too low.
  deviceHealthCritical,

  /// The device disconnected.
  deviceDisconnected,

  /// No photo arrived in time.
  timeout,

  /// Any other reason.
  unknown,
}

/// The experimental high-resolution photo capture failed.
///
/// **Experimental:** cannot be used in apps on production release channels.
@experimental
final class PhotoError extends _TypedDatError<PhotoErrorCase> {
  /// Creates a [PhotoError].
  const PhotoError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.photo);

  /// Decodes a wire error.
  factory PhotoError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => PhotoError(
    reason: _byName(PhotoErrorCase.values, code, PhotoErrorCase.unknown),
    message: message,
    platformCase: platformCase,
    details: details,
  );
}

// ---------------------------------------------------------------------------
// Display
// ---------------------------------------------------------------------------

/// Reasons for a [DisplayError].
enum DisplayErrorCase {
  /// The device disconnected.
  deviceDisconnected,

  /// iOS: the video URL is invalid.
  invalidVideoURL,

  /// iOS: a display error; see [DatError.details] `reason`.
  displayError,

  /// Android: the display is not in a state that accepts the call.
  invalidSessionState,

  /// Android: rendering the view failed.
  renderingFailed,

  /// An unexpected SDK error.
  unexpectedError,

  /// Video playback failed; see [DatError.details] `videoErrorType`.
  videoPlaybackFailed,

  /// No display session is running.
  notStarted,

  /// The display did not start in time.
  timeout,

  /// The video codec is not supported (only mp4 is).
  unsupportedCodec,

  /// Any other reason.
  unknown,
}

/// The display session failed or reported a problem.
final class DisplayError extends _TypedDatError<DisplayErrorCase> {
  /// Creates a [DisplayError].
  const DisplayError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.display);

  /// Decodes a wire error.
  factory DisplayError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => DisplayError(
    reason: _byName(DisplayErrorCase.values, code, DisplayErrorCase.unknown),
    message: message,
    platformCase: platformCase,
    details: details,
  );
}

// ---------------------------------------------------------------------------
// Experimental capabilities
// ---------------------------------------------------------------------------

/// Reasons for an [InputsError].
@experimental
enum InputsErrorCase {
  /// Inputs are not approved for this app in Wearables Developer Center.
  permissionDenied,

  /// The input channel closed.
  connectionClosed,

  /// Activation timed out.
  activationTimeout,

  /// Activation failed.
  activationFailed,

  /// iOS: inputs are not available on this device.
  capabilityUnavailable,

  /// The device disconnected.
  deviceDisconnected,

  /// Communication with the glasses failed.
  communicationError,

  /// Any other reason.
  unknown,
}

/// The experimental Inputs capability failed.
///
/// **Experimental:** cannot be used in apps on production release channels.
@experimental
final class InputsError extends _TypedDatError<InputsErrorCase> {
  /// Creates an [InputsError].
  const InputsError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.inputs);

  /// Decodes a wire error.
  factory InputsError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => InputsError(
    reason: _byName(InputsErrorCase.values, code, InputsErrorCase.unknown),
    message: message,
    platformCase: platformCase,
    details: details,
  );
}

/// Reasons for a [MotionError].
@experimental
enum MotionErrorCase {
  /// The motion sensor is unavailable.
  sensorUnavailable,

  /// The motion capability was closed.
  capabilityClosed,

  /// The device disconnected.
  deviceDisconnected,

  /// Any other reason.
  unknown,
}

/// The experimental Motion capability failed.
///
/// **Experimental:** cannot be used in apps on production release channels.
@experimental
final class MotionError extends _TypedDatError<MotionErrorCase> {
  /// Creates a [MotionError].
  const MotionError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.motion);

  /// Decodes a wire error.
  factory MotionError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => MotionError(
    reason: _byName(MotionErrorCase.values, code, MotionErrorCase.unknown),
    message: message,
    platformCase: platformCase,
    details: details,
  );
}

/// Reasons for a [SpeechError].
@experimental
enum SpeechErrorCase {
  /// The device disconnected.
  deviceDisconnected,

  /// The speech capability is in the wrong state.
  invalidState,

  /// Speech is unavailable.
  unavailable,

  /// Speech is already listening.
  alreadyListening,

  /// Starting speech failed.
  startFailed,

  /// An unexpected SDK error.
  unexpectedError,

  /// Any other reason.
  unknown,
}

/// The experimental Speech capability failed.
///
/// **Experimental:** cannot be used in apps on production release channels.
@experimental
final class SpeechError extends _TypedDatError<SpeechErrorCase> {
  /// Creates a [SpeechError].
  const SpeechError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.speech);

  /// Decodes a wire error.
  factory SpeechError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => SpeechError(
    reason: _byName(SpeechErrorCase.values, code, SpeechErrorCase.unknown),
    message: message,
    platformCase: platformCase,
    details: details,
  );
}

/// Reasons for a [VoiceInvocationError].
@experimental
enum VoiceInvocationErrorCase {
  /// The device was not found.
  deviceNotFound,

  /// The Wearables instance is invalid.
  invalidWearablesInterface,

  /// The voice channel is not connected.
  channelNotConnected,

  /// The voice channel failed.
  channelError,

  /// Sending the init request failed.
  failToSendInitRequest,

  /// Sending a message failed.
  failToSendMessage,

  /// The init request failed.
  initRequestError,

  /// The action message was malformed.
  invalidActionMessageProto,

  /// The message type is unknown.
  unknownMessageType,

  /// The action failed.
  actionFailed,

  /// The stream is in the wrong state.
  invalidSessionState,

  /// The invocation was already answered.
  alreadyResponded,

  /// Any other reason.
  unknown,
}

/// The experimental voice invocations stream failed.
///
/// **Experimental:** cannot be used in apps on production release channels.
@experimental
final class VoiceInvocationError
    extends _TypedDatError<VoiceInvocationErrorCase> {
  /// Creates a [VoiceInvocationError].
  const VoiceInvocationError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.voiceInvocation);

  /// Decodes a wire error.
  factory VoiceInvocationError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => VoiceInvocationError(
    reason: _byName(
      VoiceInvocationErrorCase.values,
      code,
      VoiceInvocationErrorCase.unknown,
    ),
    message: message,
    platformCase: platformCase,
    details: details,
  );
}

// ---------------------------------------------------------------------------
// Mock & plugin
// ---------------------------------------------------------------------------

/// Reasons for a [MockDeviceKitError].
enum MockDeviceKitErrorCase {
  /// Mock Device Kit is not enabled.
  notEnabled,

  /// The mock test server could not start (iOS: simulator only).
  testServerUnavailable,

  /// No paired mock device has that id.
  deviceNotFound,

  /// The mock device is not a pair of glasses.
  wrongDeviceKind,

  /// Any other reason.
  unknown,
}

/// A Mock Device Kit call failed.
final class MockDeviceKitError extends _TypedDatError<MockDeviceKitErrorCase> {
  /// Creates a [MockDeviceKitError].
  const MockDeviceKitError({
    required super.reason,
    required super.message,
    super.platformCase,
    super.details,
  }) : super(category: DatErrorCodes.mock);

  /// Decodes a wire error.
  factory MockDeviceKitError.fromWire(
    String? code,
    String message,
    String? platformCase,
    Map<String, Object?> details,
  ) => MockDeviceKitError(
    reason: _byName(
      MockDeviceKitErrorCase.values,
      code,
      MockDeviceKitErrorCase.unknown,
    ),
    message: message,
    platformCase: platformCase,
    details: details,
  );
}

/// The plugin rejected an argument before calling the SDK.
final class DatArgumentError extends DatError {
  /// Creates a [DatArgumentError].
  const DatArgumentError({required super.message, super.details})
    : super(category: DatErrorCodes.invalidArgument);

  @override
  String get code => 'invalidArgument';
}

/// Plugin-level failures: the SDK is not configured or initialised, a
/// platform does not support the call, or an experimental module is not
/// linked. [code] holds the specific reason, for example
/// `wearablesNotConfigured`, `wearablesNotInitialized` or `notLinked`.
final class DatPluginError extends DatError {
  /// Creates a [DatPluginError].
  const DatPluginError({
    required String code,
    required super.message,
    super.category = DatErrorCodes.plugin,
    super.platformCase,
    super.details,
  }) : _code = code;

  final String _code;

  @override
  String get code => _code;

  /// Whether the call failed because an experimental module is not linked
  /// (Android built with `mwdat.experimental=false`).
  bool get isExperimentalNotLinked =>
      category == DatErrorCodes.experimentalNotLinked;
}
