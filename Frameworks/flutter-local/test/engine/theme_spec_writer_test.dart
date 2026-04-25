import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ods_flutter_local/engine/theme_spec_writer.dart';

// =========================================================================
// Pure helper extracted from SettingsScreen's admin save-to-spec path
// (ADR-0002 phase 5). Mirrors the React framework's
// theme-spec-writer.test.ts. Keeping this pure makes the round-trip
// semantics — what gets written, what gets dropped, what gets preserved —
// testable without rendering the screen or mocking LoadedAppsStore.
// =========================================================================

Map<String, dynamic> baseSpec() => {
      'appName': 'Spec Writer Probe',
      'startPage': 'home',
      'theme': {'base': 'indigo', 'mode': 'system'},
      'pages': {
        'home': {'component': 'page', 'title': 'Home', 'content': []}
      },
      'dataSources': <String, dynamic>{},
    };

SpecWriterParams defaults() => const SpecWriterParams(
      base: 'nord',
      tokenOverrides: {},
      logo: '',
      favicon: '',
      headerStyle: 'light',
      fontFamily: '',
    );

void main() {
  group('buildUpdatedSpecJson — theme block', () {
    test('writes the new theme.base', () {
      final out = buildUpdatedSpecJson(jsonEncode(baseSpec()), defaults());
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect((parsed['theme'] as Map)['base'], 'nord');
    });

    test('preserves theme.mode from the existing spec', () {
      final out = buildUpdatedSpecJson(jsonEncode(baseSpec()), defaults());
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect((parsed['theme'] as Map)['mode'], 'system');
    });

    test('omits headerStyle when it is the default ("light")', () {
      final out = buildUpdatedSpecJson(jsonEncode(baseSpec()), defaults());
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect((parsed['theme'] as Map).containsKey('headerStyle'), isFalse);
    });

    test('writes headerStyle when non-default', () {
      final params = const SpecWriterParams(
        base: 'nord',
        tokenOverrides: {},
        logo: '',
        favicon: '',
        headerStyle: 'solid',
        fontFamily: '',
      );
      final out = buildUpdatedSpecJson(jsonEncode(baseSpec()), params);
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect((parsed['theme'] as Map)['headerStyle'], 'solid');
    });

    test('writes token overrides under theme.overrides', () {
      final params = const SpecWriterParams(
        base: 'nord',
        tokenOverrides: {'primary': 'oklch(50% 0.2 260)'},
        logo: '',
        favicon: '',
        headerStyle: 'light',
        fontFamily: '',
      );
      final out = buildUpdatedSpecJson(jsonEncode(baseSpec()), params);
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      final overrides = (parsed['theme'] as Map)['overrides'] as Map;
      expect(overrides['primary'], 'oklch(50% 0.2 260)');
    });

    test('folds fontFamily into theme.overrides.fontSans', () {
      final params = const SpecWriterParams(
        base: 'nord',
        tokenOverrides: {},
        logo: '',
        favicon: '',
        headerStyle: 'light',
        fontFamily: 'Inter',
      );
      final out = buildUpdatedSpecJson(jsonEncode(baseSpec()), params);
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      final overrides = (parsed['theme'] as Map)['overrides'] as Map;
      expect(overrides['fontSans'], 'Inter');
    });

    test('omits theme.overrides when there are no tokens or font', () {
      final out = buildUpdatedSpecJson(jsonEncode(baseSpec()), defaults());
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect((parsed['theme'] as Map).containsKey('overrides'), isFalse);
    });
  });

  group('buildUpdatedSpecJson — top-level identity fields', () {
    test('writes logo when non-empty', () {
      final params = const SpecWriterParams(
        base: 'nord',
        tokenOverrides: {},
        logo: 'https://example.com/logo.png',
        favicon: '',
        headerStyle: 'light',
        fontFamily: '',
      );
      final out = buildUpdatedSpecJson(jsonEncode(baseSpec()), params);
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect(parsed['logo'], 'https://example.com/logo.png');
    });

    test('removes logo when empty string', () {
      final start = {...baseSpec(), 'logo': 'https://example.com/old.png'};
      final out = buildUpdatedSpecJson(jsonEncode(start), defaults());
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect(parsed.containsKey('logo'), isFalse);
    });

    test('writes favicon when non-empty', () {
      final params = const SpecWriterParams(
        base: 'nord',
        tokenOverrides: {},
        logo: '',
        favicon: 'https://example.com/favicon.ico',
        headerStyle: 'light',
        fontFamily: '',
      );
      final out = buildUpdatedSpecJson(jsonEncode(baseSpec()), params);
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect(parsed['favicon'], 'https://example.com/favicon.ico');
    });

    test('removes favicon when empty string', () {
      final start = {...baseSpec(), 'favicon': 'https://example.com/old.ico'};
      final out = buildUpdatedSpecJson(jsonEncode(start), defaults());
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect(parsed.containsKey('favicon'), isFalse);
    });
  });

  group('buildUpdatedSpecJson — preservation', () {
    test('preserves unrelated top-level fields (appName, pages)', () {
      final out = buildUpdatedSpecJson(jsonEncode(baseSpec()), defaults());
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect(parsed['appName'], 'Spec Writer Probe');
      expect(parsed['startPage'], 'home');
      expect(((parsed['pages'] as Map)['home'] as Map)['title'], 'Home');
    });

    test('preserves unknown spec fields the parser would otherwise strip', () {
      final start = {...baseSpec(), 'customField': {'future': 'value'}};
      final out = buildUpdatedSpecJson(jsonEncode(start), defaults());
      final parsed = jsonDecode(out!) as Map<String, dynamic>;
      expect(parsed['customField'], {'future': 'value'});
    });
  });

  group('buildUpdatedSpecJson — error handling', () {
    test('returns null on invalid JSON', () {
      expect(buildUpdatedSpecJson('not valid json', defaults()), isNull);
    });
  });
}
