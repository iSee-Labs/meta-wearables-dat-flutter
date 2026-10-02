// Checks that the plugin version and the pinned Meta DAT SDK version agree
// across every file that declares them.
//
// Usage:
//   dart run tool/check_versions.dart            # consistency only
//   dart run tool/check_versions.dart --tag v1.0.0  # also match a git tag
//
// Exits non-zero and lists every mismatch.

// This is a CLI tool; printing is its output.
// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  final errors = <String>[];

  String? read(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      errors.add('$path: missing');
      return null;
    }
    return file.readAsStringSync();
  }

  String? match(String path, RegExp pattern, {String? source}) {
    final text = source ?? read(path);
    if (text == null) return null;
    final m = pattern.firstMatch(text);
    if (m == null) errors.add('$path: no match for ${pattern.pattern}');
    return m?.group(1);
  }

  final plugin = <String, String?>{
    'pubspec.yaml': match(
      'pubspec.yaml',
      RegExp(r'^version:\s*(\S+)', multiLine: true),
    ),
    'ios/meta_wearables_dat_flutter.podspec': match(
      'ios/meta_wearables_dat_flutter.podspec',
      RegExp(r"s\.version\s*=\s*'([^']+)'"),
    ),
    'MetaWearablesDatPlugin.swift (pluginVersion)': match(
      'ios/meta_wearables_dat_flutter/Sources/meta_wearables_dat_flutter/MetaWearablesDatPlugin.swift',
      RegExp('static let pluginVersion = "([^"]+)"'),
    ),
    'android/build.gradle (version)': match(
      'android/build.gradle',
      RegExp('^version = "([^"]+)"', multiLine: true),
    ),
  };

  final changelog = read('CHANGELOG.md');
  if (changelog != null) {
    final top = RegExp(r'^## (\S+)', multiLine: true).firstMatch(changelog);
    plugin['CHANGELOG.md (top entry)'] = top?.group(1);
  }

  final sdk = <String, String?>{
    'Package.swift (exact)': match(
      'ios/meta_wearables_dat_flutter/Package.swift',
      RegExp(r'exact:\s*"([^"]+)"'),
    ),
    'MetaWearablesDatPlugin.swift (sdkVersion)': match(
      'ios/meta_wearables_dat_flutter/Sources/meta_wearables_dat_flutter/MetaWearablesDatPlugin.swift',
      RegExp('static let sdkVersion = "([^"]+)"'),
    ),
    'android/build.gradle (mwdat_version)': match(
      'android/build.gradle',
      RegExp('mwdat_version = "([^"]+)"'),
    ),
  };

  void agree(String label, Map<String, String?> values) {
    final distinct = values.values.whereType<String>().toSet();
    if (distinct.length > 1) {
      errors.add(
        '$label versions disagree:\n'
        '${values.entries.map((e) => '    ${e.key}: ${e.value}').join('\n')}',
      );
    }
  }

  agree('Plugin', plugin);
  agree('Meta DAT SDK', sdk);

  // The plugin's major.minor tracks Meta's SDK.
  final pluginVersion = plugin['pubspec.yaml'];
  final sdkVersion = sdk['Package.swift (exact)'];
  String majorMinor(String v) => v.split('.').take(2).join('.');
  if (pluginVersion != null &&
      sdkVersion != null &&
      majorMinor(pluginVersion) != majorMinor(sdkVersion)) {
    errors.add(
      'Plugin $pluginVersion does not track Meta DAT $sdkVersion '
      '(major.minor must match).',
    );
  }

  final tagIndex = args.indexOf('--tag');
  if (tagIndex >= 0 && tagIndex + 1 < args.length) {
    final tag = args[tagIndex + 1].replaceFirst(RegExp('^v'), '');
    if (tag != pluginVersion) {
      errors.add('Tag $tag does not match pubspec version $pluginVersion.');
    }
  }

  if (errors.isEmpty) {
    print('OK: plugin $pluginVersion, Meta DAT $sdkVersion');
    return;
  }
  for (final e in errors) {
    stderr.writeln('ERROR: $e');
  }
  exit(1);
}
