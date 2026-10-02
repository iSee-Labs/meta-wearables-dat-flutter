import 'package:flutter_test/flutter_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_method_channel.dart';
import 'package:meta_wearables_dat_flutter/src/meta_wearables_dat_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _BarePlatform extends MetaWearablesDatPlatform
    with MockPlatformInterfaceMixin {}

void main() {
  test('the default instance is the MethodChannel implementation', () {
    expect(
      MetaWearablesDatPlatform.instance,
      isA<MethodChannelMetaWearablesDat>(),
    );
  });

  test('unimplemented members throw UnimplementedError', () {
    final platform = _BarePlatform();
    MetaWearablesDatPlatform.instance = platform;
    expect(platform.getPlatformVersion, throwsUnimplementedError);
    expect(platform.dumpDiagnostics, throwsUnimplementedError);
    expect(
      () => platform.startStreamSession(const StreamSessionConfig()),
      throwsUnimplementedError,
    );
    expect(platform.registrationRequestStream, throwsUnimplementedError);
    expect(
      () => platform.startInputs(const InputsConfiguration()),
      throwsUnimplementedError,
    );
    expect(
      () => platform.mockAction('mockPowerOn', 'x'),
      throwsUnimplementedError,
    );
    MetaWearablesDatPlatform.instance = MethodChannelMetaWearablesDat();
  });
}
