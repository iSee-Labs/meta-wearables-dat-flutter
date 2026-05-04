import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_method_channel.dart';
import 'package:meta_wearables_dat_flutter/src/models/camera_facing.dart';
import 'package:meta_wearables_dat_flutter/src/models/device_info.dart';
import 'package:meta_wearables_dat_flutter/src/models/frame_data.dart';
import 'package:meta_wearables_dat_flutter/src/models/photo_result.dart';
import 'package:meta_wearables_dat_flutter/src/models/registration_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/session_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_quality.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_stream_size.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Platform interface for `meta_wearables_dat_flutter`.
///
/// Concrete implementations subclass [MetaWearablesDatPlatform] and override
/// the methods they implement. The shipped default,
/// [MethodChannelMetaWearablesDat], forwards every call across a single
/// `MethodChannel` and six `EventChannel`s.
///
/// Tests can substitute their own subclass with [MockPlatformInterfaceMixin]:
///
/// ```dart
/// class _Fake extends MetaWearablesDatPlatform with MockPlatformInterfaceMixin {
///   @override
///   Future<bool> requestAndroidPermissions() async => true;
/// }
/// MetaWearablesDatPlatform.instance = _Fake();
/// ```
abstract class MetaWearablesDatPlatform extends PlatformInterface {
  /// Constructs a [MetaWearablesDatPlatform].
  MetaWearablesDatPlatform() : super(token: _token);

  static final Object _token = Object();

  static MetaWearablesDatPlatform _instance = MethodChannelMetaWearablesDat();

  /// The current default platform implementation.
  static MetaWearablesDatPlatform get instance => _instance;

  /// Sets the platform implementation (used by tests).
  static set instance(MetaWearablesDatPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // --- Diagnostics ----------------------------------------------------------

  /// Returns a short string identifying the host platform, e.g. `iOS 17.4`
  /// or `Android 14`. Used by the example app's smoke test in slice 2.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  // --- Permissions ----------------------------------------------------------

  /// Implements [MetaWearablesDat.requestAndroidPermissions].
  Future<bool> requestAndroidPermissions() {
    throw UnimplementedError(
      'requestAndroidPermissions() has not been implemented.',
    );
  }

  /// Implements [MetaWearablesDat.requestCameraPermission].
  Future<bool> requestCameraPermission() {
    throw UnimplementedError(
      'requestCameraPermission() has not been implemented.',
    );
  }

  /// Implements [MetaWearablesDat.getCameraPermissionStatus].
  Future<bool> getCameraPermissionStatus() {
    throw UnimplementedError(
      'getCameraPermissionStatus() has not been implemented.',
    );
  }

  // --- Registration ---------------------------------------------------------

  /// Implements [MetaWearablesDat.startRegistration].
  Future<void> startRegistration({String? appId, String? urlScheme}) {
    throw UnimplementedError('startRegistration() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.handleUrl].
  Future<bool> handleUrl(String url) {
    throw UnimplementedError('handleUrl() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.startUnregistration].
  Future<void> startUnregistration() {
    throw UnimplementedError(
      'startUnregistration() has not been implemented.',
    );
  }

  /// Implements [MetaWearablesDat.getRegistrationState].
  Future<RegistrationState> getRegistrationState() {
    throw UnimplementedError(
      'getRegistrationState() has not been implemented.',
    );
  }

  /// Implements [MetaWearablesDat.registrationStateStream].
  Stream<RegistrationState> registrationStateStream() {
    throw UnimplementedError(
      'registrationStateStream() has not been implemented.',
    );
  }

  /// Implements [MetaWearablesDat.activeDeviceStream].
  Stream<DeviceInfo?> activeDeviceStream() {
    throw UnimplementedError('activeDeviceStream() has not been implemented.');
  }

  // --- Streaming ------------------------------------------------------------

  /// Implements [MetaWearablesDat.startStreamSession].
  Future<int> startStreamSession({
    String? deviceUUID,
    int fps = 30,
    StreamQuality quality = StreamQuality.medium,
  }) {
    throw UnimplementedError('startStreamSession() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.stopStreamSession].
  Future<void> stopStreamSession({String? deviceUUID}) {
    throw UnimplementedError('stopStreamSession() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.pauseStreamSession].
  Future<void> pauseStreamSession({String? deviceUUID}) {
    throw UnimplementedError('pauseStreamSession() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.resumeStreamSession].
  Future<void> resumeStreamSession({String? deviceUUID}) {
    throw UnimplementedError(
      'resumeStreamSession() has not been implemented.',
    );
  }

  /// Implements [MetaWearablesDat.sessionStateStream].
  Stream<SessionState> sessionStateStream() {
    throw UnimplementedError('sessionStateStream() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.sessionErrorStream].
  Stream<Object> sessionErrorStream() {
    throw UnimplementedError('sessionErrorStream() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.videoStreamSizeStream].
  Stream<VideoStreamSize> videoStreamSizeStream() {
    throw UnimplementedError(
      'videoStreamSizeStream() has not been implemented.',
    );
  }

  // --- Capture --------------------------------------------------------------

  /// Implements [MetaWearablesDat.captureStreamFrame]. The default
  /// MethodChannel implementation is a pure-Dart override that does NOT
  /// invoke the platform channel; see slice 8.
  Future<FrameData?> captureStreamFrame(
    int textureId, {
    FrameFormat format = FrameFormat.rawRgba,
  }) {
    throw UnimplementedError(
      'captureStreamFrame() has not been implemented.',
    );
  }

  /// Implements [MetaWearablesDat.capturePhoto].
  Future<PhotoResult> capturePhoto({
    String? deviceUUID,
    PhotoFormat format = PhotoFormat.jpeg,
  }) {
    throw UnimplementedError('capturePhoto() has not been implemented.');
  }

  // --- Mock Device ----------------------------------------------------------

  /// Implements [MetaWearablesDat.enableMockDevice].
  Future<void> enableMockDevice() {
    throw UnimplementedError('enableMockDevice() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.disableMockDevice].
  Future<void> disableMockDevice() {
    throw UnimplementedError('disableMockDevice() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.pairMockRayBanMeta].
  Future<String> pairMockRayBanMeta() {
    throw UnimplementedError('pairMockRayBanMeta() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.unpairMockDevice].
  Future<void> unpairMockDevice(String uuid) {
    throw UnimplementedError('unpairMockDevice() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.mockPowerOn].
  Future<void> mockPowerOn(String uuid) {
    throw UnimplementedError('mockPowerOn() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.mockDon].
  Future<void> mockDon(String uuid) {
    throw UnimplementedError('mockDon() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.setMockCameraFacing].
  Future<void> setMockCameraFacing(String uuid, CameraFacing facing) {
    throw UnimplementedError(
      'setMockCameraFacing() has not been implemented.',
    );
  }

  /// Implements [MetaWearablesDat.setMockCameraFeed].
  Future<void> setMockCameraFeed(String uuid, String filePath) {
    throw UnimplementedError('setMockCameraFeed() has not been implemented.');
  }

  /// Implements [MetaWearablesDat.setMockCapturedImage].
  Future<void> setMockCapturedImage(String uuid, String filePath) {
    throw UnimplementedError(
      'setMockCapturedImage() has not been implemented.',
    );
  }

  /// Implements [MetaWearablesDat.mockDevicesStream].
  Stream<List<DeviceInfo>> mockDevicesStream() {
    throw UnimplementedError('mockDevicesStream() has not been implemented.');
  }
}
