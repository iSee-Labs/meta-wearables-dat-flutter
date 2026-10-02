// Verifies that Dart, Swift and Kotlin agree on every method and event
// channel name. Exits non-zero on any difference.
//
//   dart run tool/check_channel_parity.dart

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:meta_wearables_dat_flutter/src/channels.dart';

const _swiftPlugin =
    'ios/meta_wearables_dat_flutter/Sources/meta_wearables_dat_flutter/MetaWearablesDatPlugin.swift';
const _kotlinPlugin =
    'android/src/main/kotlin/com/iseelabs/meta_wearables_dat_flutter/MetaWearablesDatPlugin.kt';

void main() {
  final swift = File(_swiftPlugin).readAsStringSync();
  final kotlin = File(_kotlinPlugin).readAsStringSync();

  final swiftRoute = swift.substring(
    swift.indexOf('switch call.method {'),
    swift.indexOf('// MARK: - URL forwarding'),
  );
  final swiftMethods = <String>{
    for (final m in RegExp(
      r'case ((?:"[^"]+"(?:,\s*)?)+):',
    ).allMatches(swiftRoute))
      ...RegExp('"([^"]+)"').allMatches(m.group(1)!).map((e) => e.group(1)!),
  };
  final kotlinRoute = kotlin.substring(
    kotlin.indexOf('when (call.method) {'),
    kotlin.indexOf('// --- Background streaming'),
  );
  final kotlinMethods = <String>{
    for (final m in RegExp(
      r'^\s*((?:"[^"]+",?\s*)+)->',
      multiLine: true,
    ).allMatches(kotlinRoute))
      ...RegExp('"([^"]+)"').allMatches(m.group(1)!).map((e) => e.group(1)!),
  };

  final swiftEvents = RegExp(
    r'bind\("([a-z_]+)"',
  ).allMatches(swift).map((m) => m.group(1)!).toSet();
  final kotlinHandlers = kotlin.substring(
    kotlin.indexOf('val handlers = linkedMapOf('),
    kotlin.indexOf('for ((name, handler) in handlers)'),
  );
  final kotlinEvents = RegExp(
    '"([a-z_]+)" to ',
  ).allMatches(kotlinHandlers).map((m) => m.group(1)!).toSet();

  var failed = false;
  void compare(
    String what,
    Set<String> dart,
    Set<String> native,
    String platform,
  ) {
    final missing = dart.difference(native);
    final extra = native.difference(dart);
    if (missing.isEmpty && extra.isEmpty) return;
    failed = true;
    if (missing.isNotEmpty) {
      print('$platform is missing $what: ${missing.toList()..sort()}');
    }
    if (extra.isNotEmpty) {
      print(
        '$platform has $what Dart does not list: ${extra.toList()..sort()}',
      );
    }
  }

  final dartMethods = DatChannels.methods.toSet();
  final dartEvents = DatChannels.events.toSet();
  compare('methods', dartMethods, swiftMethods, 'iOS');
  compare('methods', dartMethods, kotlinMethods, 'Android');
  compare('event channels', dartEvents, swiftEvents, 'iOS');
  compare('event channels', dartEvents, kotlinEvents, 'Android');

  if (failed) exit(1);
  print(
    'Channel parity OK: ${dartMethods.length} methods, ${dartEvents.length} event channels.',
  );
}
