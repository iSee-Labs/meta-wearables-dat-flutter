// Fails when line coverage of the plugin's wire-facing Dart code drops
// below a threshold. Run after `flutter test --coverage`.
//
// Usage: dart run tool/coverage_gate.dart [--min 90] [--lcov coverage/lcov.info]
//
// Gated: lib/src/models/**, the method channel and error mapping. The
// static facade and the platform interface's UnimplementedError stubs are
// reported but not gated.

// This is a CLI tool; printing is its output.
// ignore_for_file: avoid_print

import 'dart:io';

bool _gated(String path) =>
    path.startsWith('lib/src/models/') ||
    path == 'lib/src/meta_wearables_dat_method_channel.dart' ||
    path == 'lib/src/error_mapping.dart';

void main(List<String> args) {
  String option(String name, String fallback) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final min = double.parse(option('--min', '90'));
  final lcov = File(option('--lcov', 'coverage/lcov.info'));
  if (!lcov.existsSync()) {
    stderr.writeln('${lcov.path} not found. Run `flutter test --coverage`.');
    exit(2);
  }

  final hits = <String, List<int>>{};
  String? current;
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll(r'\', '/');
      final lib = current.indexOf('lib/');
      if (lib > 0) current = current.substring(lib);
      hits.putIfAbsent(current, () => [0, 0]);
    } else if (line.startsWith('DA:') && current != null) {
      final count = int.parse(line.substring(3).split(',')[1]);
      hits[current]![1]++;
      if (count > 0) hits[current]![0]++;
    }
  }

  var covered = 0;
  var total = 0;
  final files = hits.keys.toList()..sort();
  for (final file in files) {
    final [h, n] = hits[file]!;
    if (n == 0) continue;
    final pct = 100 * h / n;
    final mark = _gated(file) ? ' ' : '-';
    print('$mark ${pct.toStringAsFixed(1).padLeft(5)}%  $file');
    if (_gated(file)) {
      covered += h;
      total += n;
    }
  }

  final pct = total == 0 ? 0 : 100 * covered / total;
  print(
    '\nGated coverage: ${pct.toStringAsFixed(1)}% '
    '($covered/$total lines, minimum $min%)',
  );
  if (pct < min) exit(1);
}
