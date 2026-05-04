import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_platform_interface.dart';
import 'package:meta_wearables_dat_flutter/src/models/dat_error.dart';
import 'package:meta_wearables_dat_flutter/src/models/device_info.dart';
import 'package:meta_wearables_dat_flutter/src/models/frame_data.dart';
import 'package:meta_wearables_dat_flutter/src/models/photo_result.dart';
import 'package:meta_wearables_dat_flutter/src/models/registration_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/session_state.dart';
import 'package:meta_wearables_dat_flutter/src/models/stream_quality.dart';
import 'package:meta_wearables_dat_flutter/src/models/video_stream_size.dart';

/// Default [MetaWearablesDatPlatform] implementation that forwards every call
/// across a single `MethodChannel` plus six topic-specific `EventChannel`s.
///
/// Method handlers are added slice by slice (slice 4 onward); until then,
/// every method call surfaces as a `MissingPluginException` from the native
/// stub. Stream getters are pure pass-throughs and emit no events until their
/// stream handlers are wired natively.
class MethodChannelMetaWearablesDat extends MetaWearablesDatPlatform {
  /// Method channel used for request/response calls.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'meta_wearables_dat_flutter',
  );

  /// Event channel for [registrationStateStream].
  @visibleForTesting
  final EventChannel registrationStateChannel = const EventChannel(
    'meta_wearables_dat_flutter/registration_state',
  );

  /// Event channel for [activeDeviceStream].
  @visibleForTesting
  final EventChannel activeDeviceChannel = const EventChannel(
    'meta_wearables_dat_flutter/active_device',
  );

  /// Event channel for [sessionStateStream].
  @visibleForTesting
  final EventChannel sessionStateChannel = const EventChannel(
    'meta_wearables_dat_flutter/session_state',
  );

  /// Event channel for [sessionErrorStream].
  @visibleForTesting
  final EventChannel sessionErrorsChannel = const EventChannel(
    'meta_wearables_dat_flutter/session_errors',
  );

  /// Event channel for [videoStreamSizeStream].
  @visibleForTesting
  final EventChannel videoStreamSizeChannel = const EventChannel(
    'meta_wearables_dat_flutter/video_stream_size',
  );

  /// Event channel for [mockDevicesStream].
  @visibleForTesting
  final EventChannel mockDevicesChannel = const EventChannel(
    'meta_wearables_dat_flutter/mock_devices',
  );

  // Cached broadcast streams so multiple Dart-side listeners share a single
  // platform-channel subscription.
  Stream<RegistrationState>? _registrationStateStream;
  Stream<DeviceInfo?>? _activeDeviceStream;
  Stream<SessionState>? _sessionStateStream;
  Stream<Object>? _sessionErrorStream;
  Stream<VideoStreamSize>? _videoStreamSizeStream;
  Stream<List<DeviceInfo>>? _mockDevicesStream;

  /// Latest [VideoStreamSize] observed on the `video_stream_size` channel.
  /// Used as the canvas size for [captureStreamFrame] when the caller does
  /// not pass an explicit size. Updated by the [videoStreamSizeStream]
  /// getter so frames captured before any host listener attaches still
  /// pick up the right dimensions (the broadcast stream replays the
  /// initial event to every late subscriber).
  VideoStreamSize? _lastVideoStreamSize;

  // --- Diagnostics ----------------------------------------------------------

  @override
  Future<String?> getPlatformVersion() {
    return methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  // --- Permissions ----------------------------------------------------------

  @override
  Future<bool> requestAndroidPermissions() async {
    final granted = await methodChannel.invokeMethod<bool>(
      'requestAndroidPermissions',
    );
    return granted ?? false;
  }

  @override
  Future<bool> requestCameraPermission() async {
    try {
      final granted = await methodChannel.invokeMethod<bool>(
        'requestCameraPermission',
      );
      return granted ?? false;
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Future<bool> getCameraPermissionStatus() async {
    try {
      final granted = await methodChannel.invokeMethod<bool>(
        'getCameraPermissionStatus',
      );
      return granted ?? false;
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  // --- Registration ---------------------------------------------------------

  @override
  Future<void> startRegistration({String? appId, String? urlScheme}) async {
    try {
      await methodChannel.invokeMethod<void>(
        'startRegistration',
        <String, Object?>{
          if (appId != null) 'appId': appId,
          if (urlScheme != null) 'urlScheme': urlScheme,
        },
      );
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Future<bool> handleUrl(String url) async {
    try {
      final consumed = await methodChannel.invokeMethod<bool>(
        'handleUrl',
        <String, Object?>{'url': url},
      );
      return consumed ?? false;
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Future<void> startUnregistration() async {
    try {
      await methodChannel.invokeMethod<void>('startUnregistration');
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Future<RegistrationState> getRegistrationState() async {
    final raw = await methodChannel.invokeMethod<int>('getRegistrationState');
    return RegistrationState.fromInt(raw);
  }

  // --- Registration streams -------------------------------------------------

  @override
  Stream<RegistrationState> registrationStateStream() {
    return _registrationStateStream ??= registrationStateChannel
        .receiveBroadcastStream()
        .map((event) => RegistrationState.fromInt(event as int?));
  }

  @override
  Stream<DeviceInfo?> activeDeviceStream() {
    return _activeDeviceStream ??=
        activeDeviceChannel.receiveBroadcastStream().map((event) {
      if (event == null) return null;
      return DeviceInfo.fromMap(event as Map<Object?, Object?>);
    });
  }

  // --- Streaming ------------------------------------------------------------

  @override
  Future<int> startStreamSession({
    String? deviceUUID,
    int fps = 30,
    StreamQuality quality = StreamQuality.medium,
  }) async {
    try {
      final id = await methodChannel.invokeMethod<int>(
        'startStreamSession',
        <String, Object?>{
          if (deviceUUID != null) 'deviceUuid': deviceUUID,
          'fps': fps,
          'quality': quality.name,
        },
      );
      if (id == null) {
        throw const SessionError(
          code: DatErrorCodes.session,
          message: 'startStreamSession returned null',
        );
      }
      return id;
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Future<void> stopStreamSession({String? deviceUUID}) async {
    try {
      await methodChannel.invokeMethod<void>(
        'stopStreamSession',
        <String, Object?>{
          if (deviceUUID != null) 'deviceUuid': deviceUUID,
        },
      );
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Future<void> pauseStreamSession({String? deviceUUID}) async {
    try {
      await methodChannel.invokeMethod<void>(
        'pauseStreamSession',
        <String, Object?>{
          if (deviceUUID != null) 'deviceUuid': deviceUUID,
        },
      );
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  @override
  Future<void> resumeStreamSession({String? deviceUUID}) async {
    try {
      await methodChannel.invokeMethod<void>(
        'resumeStreamSession',
        <String, Object?>{
          if (deviceUUID != null) 'deviceUuid': deviceUUID,
        },
      );
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  // --- Streaming streams ----------------------------------------------------

  @override
  Stream<SessionState> sessionStateStream() {
    return _sessionStateStream ??= sessionStateChannel
        .receiveBroadcastStream()
        .map((event) => SessionState.fromInt(event as int?));
  }

  @override
  Stream<Object> sessionErrorStream() {
    return _sessionErrorStream ??=
        sessionErrorsChannel.receiveBroadcastStream().map(_mapSessionError);
  }

  @override
  Stream<VideoStreamSize> videoStreamSizeStream() {
    return _videoStreamSizeStream ??= videoStreamSizeChannel
        .receiveBroadcastStream()
        .map((event) => VideoStreamSize.fromMap(event as Map<Object?, Object?>))
        .map((size) {
      _lastVideoStreamSize = size;
      return size;
    });
  }

  // --- Photo capture --------------------------------------------------------

  @override
  Future<PhotoResult> capturePhoto({
    String? deviceUUID,
    PhotoFormat format = PhotoFormat.jpeg,
  }) async {
    try {
      final result = await methodChannel
          .invokeMethod<Map<Object?, Object?>>('capturePhoto', <String, Object?>{
        if (deviceUUID != null) 'deviceUuid': deviceUUID,
        'format': format.name,
      });
      if (result == null) {
        throw const CaptureError(
          code: DatErrorCodes.capture,
          message: 'capturePhoto returned null',
        );
      }
      final bytes = result['bytes'];
      final formatName = result['format'] as String? ?? format.name;
      final byteList = switch (bytes) {
        final Uint8List u => u,
        final List<int> l => Uint8List.fromList(l),
        _ => Uint8List(0),
      };
      return PhotoResult(
        bytes: byteList,
        format: formatName == 'heic' ? PhotoFormat.heic : PhotoFormat.jpeg,
      );
    } on PlatformException catch (e) {
      throw _mapPlatformException(e);
    }
  }

  // --- Frame capture --------------------------------------------------------

  /// Pure-Dart on-demand snapshot of the live stream Texture.
  ///
  /// Implementation details:
  ///
  /// 1. Builds a [ui.Scene] containing nothing but a single texture layer
  ///    pointing at [textureId] via [ui.SceneBuilder.addTexture].
  /// 2. Rasterises the scene to a [ui.Image] at the most recently observed
  ///    [VideoStreamSize] (defaulting to 1280x720 if none has been emitted
  ///    yet).
  /// 3. Encodes the image with [ui.Image.toByteData] using the byte format
  ///    matching [FrameFormat].
  ///
  /// This is intentionally on the slow path - allocating an [ui.Image]
  /// per call - because the API is meant for "give me the current frame"
  /// queries (OCR, ML inference, screenshot), not 30fps consumption.
  /// Hosts that need every frame should subscribe to a dedicated
  /// `videoFramesStream()` (planned for v0.2).
  ///
  /// Notifies of a missing texture by returning `null`. Throws a
  /// [CaptureError] if the rasterisation or encoding step fails.
  @override
  Future<FrameData?> captureStreamFrame(
    int textureId, {
    FrameFormat format = FrameFormat.rawRgba,
  }) async {
    final size = _lastVideoStreamSize ??
        const VideoStreamSize(width: 1280, height: 720);
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) return null;

    ui.Scene? scene;
    ui.Image? image;
    try {
      final builder = ui.SceneBuilder()
        ..pushOffset(0, 0)
        ..addTexture(
          textureId,
          width: width.toDouble(),
          height: height.toDouble(),
        )
        ..pop();
      scene = builder.build();
      image = await scene.toImage(width, height);

      final byteFormat = switch (format) {
        FrameFormat.png => ui.ImageByteFormat.png,
        FrameFormat.rawStraightRgba => ui.ImageByteFormat.rawStraightRgba,
        FrameFormat.rawRgba => ui.ImageByteFormat.rawRgba,
      };
      final byteData = await image.toByteData(format: byteFormat);
      if (byteData == null) {
        throw const CaptureError(
          code: DatErrorCodes.capture,
          message: 'ui.Image.toByteData returned null',
        );
      }
      return FrameData(
        bytes: byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
        width: width,
        height: height,
        format: format,
      );
    } catch (e) {
      if (e is DatError) rethrow;
      throw CaptureError(
        code: DatErrorCodes.capture,
        message: 'captureStreamFrame failed: $e',
      );
    } finally {
      image?.dispose();
      scene?.dispose();
    }
  }

  // --- Mock devices stream --------------------------------------------------

  @override
  Stream<List<DeviceInfo>> mockDevicesStream() {
    return _mockDevicesStream ??=
        mockDevicesChannel.receiveBroadcastStream().map((event) {
      final list = (event as List<Object?>?) ?? const [];
      return list
          .map((e) => DeviceInfo.fromMap(e! as Map<Object?, Object?>))
          .toList(growable: false);
    });
  }

  // --- Helpers --------------------------------------------------------------

  /// Maps a [PlatformException] thrown from the platform channel to the
  /// most specific [DatError] subclass we have for its `code`. Anything
  /// unrecognised passes through as a base [DatError].
  static DatError _mapPlatformException(PlatformException e) {
    final code = e.code;
    final message = e.message ?? '';
    final details = e.details;
    switch (code) {
      case DatErrorCodes.registration:
        return RegistrationError(
          code: code,
          message: message,
          details: details,
        );
      case DatErrorCodes.permission:
      case DatErrorCodes.missingFragmentActivity:
        return PermissionError(code: code, message: message, details: details);
      case DatErrorCodes.session:
        return SessionError(code: code, message: message, details: details);
      case DatErrorCodes.capture:
        return CaptureError(code: code, message: message, details: details);
      case _:
        return DatError(code: code, message: message, details: details);
    }
  }

  /// Maps a raw event from the `session_errors` channel to a typed
  /// [DatError] subclass, falling back to a base [DatError] for anything
  /// unrecognised.
  static DatError _mapSessionError(Object? event) {
    final map = event as Map<Object?, Object?>? ?? const {};
    final code = map['code'] as String? ?? DatErrorCodes.session;
    final message = map['message'] as String? ?? '';
    final details = map['details'];
    switch (code) {
      case DatErrorCodes.registration:
        return RegistrationError(
          code: code,
          message: message,
          details: details,
        );
      case DatErrorCodes.permission:
        return PermissionError(code: code, message: message, details: details);
      case DatErrorCodes.capture:
        return CaptureError(code: code, message: message, details: details);
      case DatErrorCodes.session:
        return SessionError(code: code, message: message, details: details);
      case _:
        return DatError(code: code, message: message, details: details);
    }
  }
}
