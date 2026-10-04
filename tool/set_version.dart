// Sets the plugin version in every file that declares it, so a release
// (or release candidate) needs one command instead of five edits.
//
// Usage: dart run tool/set_version.dart 1.0.0-rc.1
//
// Updates pubspec.yaml, the podspec, the Swift and Gradle version strings,
// and renames the top CHANGELOG heading when it is the previous version.
// Run tool/check_versions.dart afterwards.

// This is a CLI tool; printing is its output.
// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  if (args.length != 1 ||
      !RegExp(r'^\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$').hasMatch(args[0])) {
    stderr.writeln('Usage: dart run tool/set_version.dart <semver>');
    exit(2);
  }
  final next = args[0];
  final pubspec = File('pubspec.yaml');
  final current = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync())!.group(1)!;
  if (current == next) {
    print('Already at $next.');
    return;
  }

  void replace(String path, Pattern from, String to) {
    final file = File(path);
    final text = file.readAsStringSync();
    final updated = text.replaceFirst(from, to);
    if (updated == text) {
      stderr.writeln(
        '$path: nothing to update for ${from is RegExp ? from.pattern : from}',
      );
      exit(1);
    }
    file.writeAsStringSync(updated);
    print('$path: $current -> $next');
  }

  replace(
    'pubspec.yaml',
    RegExp('^version: ${RegExp.escape(current)}', multiLine: true),
    'version: $next',
  );
  replace(
    'ios/meta_wearables_dat_flutter.podspec',
    "s.version          = '$current'",
    "s.version          = '$next'",
  );
  replace(
    'ios/meta_wearables_dat_flutter/Sources/meta_wearables_dat_flutter/MetaWearablesDatPlugin.swift',
    'static let pluginVersion = "$current"',
    'static let pluginVersion = "$next"',
  );
  replace(
    'android/build.gradle',
    RegExp('^version = "${RegExp.escape(current)}"', multiLine: true),
    'version = "$next"',
  );

  final changelog = File('CHANGELOG.md');
  final log = changelog.readAsStringSync();
  if (log.contains('## $current\n')) {
    changelog.writeAsStringSync(
      log.replaceFirst('## $current\n', '## $next\n'),
    );
    print('CHANGELOG.md: heading $current -> $next');
  } else {
    print(
      'CHANGELOG.md: no "## $current" heading; add a "## $next" entry by hand.',
    );
  }
}
