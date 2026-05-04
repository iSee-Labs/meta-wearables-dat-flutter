// Basic integration test for the plugin's `getPlatformVersion` smoke check.
// Real device-side verification (registration, streaming, capture) lives in
// `samples/camera_access/` once that app is built (slice 11).
//
// Reference: https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getPlatformVersion returns a non-empty string',
      (WidgetTester tester) async {
    final version = await MetaWearablesDat.getPlatformVersion();
    expect(version, isNotNull);
    expect(version!.isNotEmpty, isTrue);
  });
}
