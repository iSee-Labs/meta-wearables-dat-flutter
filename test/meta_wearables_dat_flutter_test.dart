import 'package:flutter_test/flutter_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter_method_channel.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMetaWearablesDatFlutterPlatform
    with MockPlatformInterfaceMixin
    implements MetaWearablesDatFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final initialPlatform = MetaWearablesDatFlutterPlatform.instance;

  test('$MethodChannelMetaWearablesDatFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMetaWearablesDatFlutter>());
  });

  test('getPlatformVersion', () async {
    final metaWearablesDatFlutterPlugin = MetaWearablesDatFlutter();
    final fakePlatform = MockMetaWearablesDatFlutterPlatform();
    MetaWearablesDatFlutterPlatform.instance = fakePlatform;

    expect(await metaWearablesDatFlutterPlugin.getPlatformVersion(), '42');
  });
}
