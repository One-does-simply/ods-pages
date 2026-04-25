import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ods_flutter_local/parser/spec_parser.dart';

// =========================================================================
// Property-based tests for the spec parser. Mirrors React's
// spec-parser-properties.test.ts (which uses fast-check); this side
// hand-rolls the random generator with a seeded `Random` so we don't
// take on a new dependency just for property tests.
//
// Pinned invariants:
//   - Totality:    parse never throws, always returns a ParseResult
//   - Soundness:   missing required fields are always detected
//   - Robustness:  any minimal-valid spec parses without errors
// =========================================================================

const _runs = 200;

/// Seeded RNG so failures are reproducible. Bump the seed if you want a
/// different pass.
final _rng = Random(20260425);

String _randomString({int min = 0, int max = 50}) {
  final len = min + _rng.nextInt(max - min + 1);
  final buf = StringBuffer();
  for (var i = 0; i < len; i++) {
    // Mix in a few control / unicode characters to stress the parser.
    final pick = _rng.nextInt(64);
    if (pick < 26) {
      buf.writeCharCode(97 + pick); // a-z
    } else if (pick < 52) {
      buf.writeCharCode(65 + (pick - 26)); // A-Z
    } else if (pick < 62) {
      buf.writeCharCode(48 + (pick - 52)); // 0-9
    } else if (pick == 62) {
      buf.write('"\\\n\t');
    } else {
      buf.writeCharCode(0x2603); // snowman ☃
    }
  }
  return buf.toString();
}

String _randomIdentifier() {
  // Letter then alphanumerics; matches the React generator's stringMatching.
  final len = 1 + _rng.nextInt(20);
  final buf = StringBuffer();
  buf.writeCharCode(97 + _rng.nextInt(26));
  for (var i = 1; i < len; i++) {
    final pick = _rng.nextInt(36);
    if (pick < 26) {
      buf.writeCharCode(97 + pick);
    } else {
      buf.writeCharCode(48 + (pick - 26));
    }
  }
  return buf.toString();
}

dynamic _randomJsonValue(int depth) {
  // Keep depth bounded so we don't generate megabyte specs.
  final pick = _rng.nextInt(depth <= 0 ? 4 : 7);
  switch (pick) {
    case 0:
      return null;
    case 1:
      return _rng.nextBool();
    case 2:
      return _rng.nextInt(1000);
    case 3:
      return _randomString();
    case 4:
      final list = <dynamic>[];
      final n = _rng.nextInt(4);
      for (var i = 0; i < n; i++) {
        list.add(_randomJsonValue(depth - 1));
      }
      return list;
    default:
      final map = <String, dynamic>{};
      final n = _rng.nextInt(4);
      for (var i = 0; i < n; i++) {
        map[_randomIdentifier()] = _randomJsonValue(depth - 1);
      }
      return map;
  }
}

void main() {
  group('SpecParser — totality', () {
    test('never throws on arbitrary string input', () {
      final parser = SpecParser();
      for (var i = 0; i < _runs; i++) {
        final input = _randomString(min: 0, max: 200);
        // Must not throw. Result fields are accessed to keep tree-shaking honest.
        final r = parser.parse(input);
        expect(r.validation, isNotNull);
      }
    });

    test('never throws on arbitrary JSON-encoded input (object/array/primitives)', () {
      final parser = SpecParser();
      for (var i = 0; i < _runs; i++) {
        final value = _randomJsonValue(3);
        final r = parser.parse(jsonEncode(value));
        expect(r.validation, isNotNull);
        // hasErrors should be a real bool either way.
        expect(r.validation.hasErrors, anyOf(isTrue, isFalse));
      }
    });
  });

  group('SpecParser — soundness on missing required fields', () {
    test('flags missing appName as a validation error', () {
      final parser = SpecParser();
      for (var i = 0; i < 50; i++) {
        final spec = {
          'startPage': 'home',
          'pages': {
            'home': {'component': 'page', 'title': 'Home', 'content': []}
          },
        };
        final r = parser.parse(jsonEncode(spec));
        expect(
          r.parseError != null || r.validation.hasErrors,
          isTrue,
          reason: 'spec without appName must surface an error',
        );
      }
    });

    test('flags missing startPage as a validation error', () {
      final parser = SpecParser();
      for (var i = 0; i < 50; i++) {
        final spec = {
          'appName': _randomString(min: 1, max: 50),
          'pages': {
            'home': {'component': 'page', 'title': 'Home', 'content': []}
          },
        };
        final r = parser.parse(jsonEncode(spec));
        expect(
          r.parseError != null || r.validation.hasErrors,
          isTrue,
          reason: 'spec without startPage must surface an error',
        );
      }
    });
  });

  group('SpecParser — minimal-valid spec always parses', () {
    test('any (appName, startPage, pages) triple with the matching page produces a parsed app', () {
      final parser = SpecParser();
      for (var i = 0; i < 100; i++) {
        final appName = _randomString(min: 1, max: 50);
        final pageId = _randomIdentifier();
        final pageTitle = _randomString(min: 1, max: 30);
        final spec = {
          'appName': appName,
          'startPage': pageId,
          'pages': {
            pageId: {
              'component': 'page',
              'title': pageTitle,
              'content': <dynamic>[],
            },
          },
        };
        final r = parser.parse(jsonEncode(spec));
        expect(
          r.isOk,
          isTrue,
          reason: 'minimal spec should parse cleanly: $spec',
        );
        expect(r.app, isNotNull);
        expect(r.app!.appName, appName);
        expect(r.app!.startPage, pageId);
      }
    });
  });
}
