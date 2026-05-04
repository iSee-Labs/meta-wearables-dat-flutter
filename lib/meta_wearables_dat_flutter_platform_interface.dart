import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class MetaWearablesDatFlutterPlatform extends PlatformInterface {
  /// Constructs a MetaWearablesDatFlutterPlatform.
  MetaWearablesDatFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static MetaWearablesDatFlutterPlatform _instance = MethodChannelMetaWearablesDatFlutter();

  /// The default instance of [MetaWearablesDatFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelMetaWearablesDatFlutter].
  static MetaWearablesDatFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MetaWearablesDatFlutterPlatform] when
  /// they register themselves.
  static set instance(MetaWearablesDatFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
