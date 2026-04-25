// Parses coverage/lcov.info and enforces per-directory minimum line
// coverage. Mirrors the per-folder thresholds in the React framework's
// vitest.config.ts. Run with:
//
//     flutter test test/engine test/models test/parser test/integration \
//         test/conformance --exclude-tags=slow --coverage
//     dart run tool/coverage_check.dart
//
// Exits 1 if any directory falls below its threshold, prints the full
// breakdown either way. CI step in flutter.yml runs this immediately
// after `flutter test --coverage`.

import 'dart:io';

/// Per-directory line-coverage minima. Bucket key is the leading
/// `lib/<top-level>/` of each source path. Bump these in lockstep with
/// new tests landing — they should ratchet up, not drift down.
const _thresholds = <String, double>{
  'lib/engine/': 60.0,
  'lib/models/': 85.0,
  'lib/parser/': 80.0,
};

class _Bucket {
  int hit = 0;
  int total = 0;
  double get percent => total == 0 ? 0.0 : 100.0 * hit / total;
}

void main() {
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info not found — run `flutter test --coverage` first.',
    );
    exit(2);
  }

  final buckets = <String, _Bucket>{};
  String? currentFile;
  for (final raw in lcov.readAsLinesSync()) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3).replaceAll(r'\', '/');
    } else if (line.startsWith('DA:') && currentFile != null) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      final count = int.tryParse(parts[1]) ?? 0;
      final bucket = _bucketFor(currentFile);
      if (bucket == null) continue;
      final b = buckets.putIfAbsent(bucket, _Bucket.new);
      b.total++;
      if (count > 0) b.hit++;
    } else if (line == 'end_of_record') {
      currentFile = null;
    }
  }

  // Print summary.
  stdout.writeln('Directory                 Hit  Total  Coverage  Threshold');
  stdout.writeln('=' * 60);
  var fails = 0;
  for (final entry in _thresholds.entries) {
    final dir = entry.key;
    final threshold = entry.value;
    final b = buckets[dir];
    if (b == null) {
      stdout.writeln(
        '${dir.padRight(25)}     -     - (no files traced) [SKIP]',
      );
      continue;
    }
    final passed = b.percent >= threshold;
    final status = passed ? 'PASS' : 'FAIL';
    if (!passed) fails++;
    stdout.writeln(
      '${dir.padRight(25)}'
      '${b.hit.toString().padLeft(5)}'
      '${b.total.toString().padLeft(7)}'
      '${b.percent.toStringAsFixed(2).padLeft(9)}%'
      '${threshold.toStringAsFixed(2).padLeft(8)}%  [$status]',
    );
  }

  // Total roll-up (info only — not gated).
  final totalHit = buckets.values.fold<int>(0, (s, b) => s + b.hit);
  final totalTotal = buckets.values.fold<int>(0, (s, b) => s + b.total);
  final totalPct = totalTotal == 0 ? 0.0 : 100.0 * totalHit / totalTotal;
  stdout.writeln('-' * 60);
  stdout.writeln(
    '${'TOTAL'.padRight(25)}'
    '${totalHit.toString().padLeft(5)}'
    '${totalTotal.toString().padLeft(7)}'
    '${totalPct.toStringAsFixed(2).padLeft(9)}%',
  );

  if (fails > 0) {
    stderr.writeln('\n$fails directory threshold(s) failed.');
    exit(1);
  }
  stdout.writeln('\nAll coverage thresholds met.');
}

/// Returns the bucket key (e.g. `lib/engine/`) for a source path, or
/// null if the path is outside any tracked directory.
String? _bucketFor(String path) {
  for (final dir in _thresholds.keys) {
    if (path.startsWith(dir)) return dir;
  }
  return null;
}
