// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// Drives Meta's Mock Device Kit through the plugin for integration tests.
class MockHarness {
  final List<String> _paired = [];

  /// Enables Mock Device Kit from a clean state.
  Future<void> enable({
    bool initiallyRegistered = true,
    bool permissionsGranted = true,
  }) async {
    await MetaWearablesDat.disableMockDevice();
    await MetaWearablesDat.enableMockDevice(
      initiallyRegistered: initiallyRegistered,
      initialPermissionsGranted: permissionsGranted,
    );
  }

  /// Pairs glasses, powers them on, unfolds and dons them, and waits until
  /// they show up in the device list.
  Future<String> bringOnline([
    MockGlassesModel model = MockGlassesModel.rayBanMeta,
  ]) async {
    final device = await MetaWearablesDat.pairMockGlasses(model);
    _paired.add(device.uuid);
    await MetaWearablesDat.mockPowerOn(device.uuid);
    await MetaWearablesDat.mockUnfold(device.uuid);
    await MetaWearablesDat.mockDon(device.uuid);
    await waitFor(
      () async => (await MetaWearablesDat.getDevices()).any(
        (d) => d.uuid == device.uuid,
      ),
      reason: 'mock device ${device.uuid} never appeared in getDevices()',
    );
    return device.uuid;
  }

  /// Copies a bundled asset to a temporary file and returns its path.
  Future<String> materialise(String asset) async {
    final data = await rootBundle.load(asset);
    final file = File('${Directory.systemTemp.path}/${asset.split('/').last}');
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.path;
  }

  /// Stops everything, unpairs and disables Mock Device Kit, and checks no
  /// native resource leaked.
  Future<void> teardown() async {
    await MetaWearablesDat.stopStreamSession();
    await MetaWearablesDat.stopDisplaySession();
    await MetaWearablesDat.stopInputs();
    await MetaWearablesDat.stopMotion();
    await MetaWearablesDat.stopSpeech();
    await MetaWearablesDat.stopVoiceInvocations();
    for (final uuid in _paired) {
      try {
        await MetaWearablesDat.unpairMockDevice(uuid);
      } on DatError {
        // Already gone.
      }
    }
    _paired.clear();
    await MetaWearablesDat.disableMockDevice();
    await waitFor(() async {
      final resources = (await MetaWearablesDat.dumpDiagnostics()).resources;
      return resources.entries
          .where((e) => e.key != 'mockDevices')
          .every((e) => e.value == 0);
    }, reason: 'native resources leaked after teardown');
  }
}

/// Polls [condition] until it returns true.
Future<void> waitFor(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  String reason = 'condition not met',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail('$reason (after ${timeout.inSeconds} s)');
}

/// The first event of [stream] that satisfies [test].
Future<T> firstWhere<T>(
  Stream<T> stream,
  bool Function(T) test, {
  Duration timeout = const Duration(seconds: 20),
}) => stream.firstWhere(test).timeout(timeout);
