import 'dart:io';

import 'package:flutter/services.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Brings a simulated pair of glasses online with Meta's Mock Device Kit,
/// so every tab works without hardware.
///
/// Returns the mock device's uuid.
Future<String> startMockGlasses(MockGlassesModel model) async {
  if (!await MetaWearablesDat.isMockDeviceEnabled()) {
    await MetaWearablesDat.enableMockDevice();
  }
  final device = await MetaWearablesDat.pairMockGlasses(model);
  // A mock device is listed only once it is powered on and unfolded.
  await MetaWearablesDat.mockPowerOn(device.uuid);
  await MetaWearablesDat.mockUnfold(device.uuid);
  await MetaWearablesDat.mockDon(device.uuid);
  // The mock camera streams an H.265 file and returns a fixed photo.
  await MetaWearablesDat.setMockCameraFeed(
    device.uuid,
    await _materialise('assets/mock/mock_feed_h265.mp4'),
  );
  await MetaWearablesDat.setMockCapturedImage(
    device.uuid,
    await _materialise('assets/mock/mock_photo.jpg'),
  );
  return device.uuid;
}

/// Unpairs every mock device and turns Mock Device Kit off.
Future<void> stopMockGlasses() async {
  for (final device in await MetaWearablesDat.pairedMockDevices()) {
    await MetaWearablesDat.unpairMockDevice(device.uuid);
  }
  await MetaWearablesDat.disableMockDevice();
}

Future<String> _materialise(String asset) async {
  final data = await rootBundle.load(asset);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${asset.split('/').last}');
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file.path;
}
