import 'package:flutter_test/flutter_test.dart';
import 'package:ods_flutter_local/models/ods_theme.dart';

// =========================================================================
// OdsTheme tests (ADR-0002)
// =========================================================================

void main() {
  group('OdsTheme defaults', () {
    test('default base is indigo', () {
      const t = OdsTheme();
      expect(t.base, 'indigo');
    });

    test('default mode is system', () {
      const t = OdsTheme();
      expect(t.mode, 'system');
    });

    test('default headerStyle is light', () {
      const t = OdsTheme();
      expect(t.headerStyle, 'light');
    });

    test('default overrides is empty', () {
      const t = OdsTheme();
      expect(t.overrides, isEmpty);
    });
  });

  group('OdsTheme.fromJson', () {
    test('null returns defaults', () {
      final t = OdsTheme.fromJson(null);
      expect(t.base, 'indigo');
      expect(t.mode, 'system');
      expect(t.headerStyle, 'light');
    });

    test('parses full theme object', () {
      final t = OdsTheme.fromJson({
        'base': 'nord',
        'mode': 'dark',
        'headerStyle': 'solid',
        'overrides': {
          'primary': 'oklch(50% 0.2 260)',
          'fontSans': 'Inter',
        },
      });
      expect(t.base, 'nord');
      expect(t.mode, 'dark');
      expect(t.headerStyle, 'solid');
      expect(t.overrides['primary'], 'oklch(50% 0.2 260)');
      expect(t.overrides['fontSans'], 'Inter');
    });

    test('parses minimal theme with only base', () {
      final t = OdsTheme.fromJson({'base': 'corporate'});
      expect(t.base, 'corporate');
      expect(t.mode, 'system');
      expect(t.headerStyle, 'light');
      expect(t.overrides, isEmpty);
    });

    test('falls back to system for invalid mode', () {
      final t = OdsTheme.fromJson({'mode': 'invalid'});
      expect(t.mode, 'system');
    });

    test('falls back to light for invalid headerStyle', () {
      final t = OdsTheme.fromJson({'headerStyle': 'glowing'});
      expect(t.headerStyle, 'light');
    });

    test('migrates legacy color-mode alias "light" → "indigo"', () {
      final t = OdsTheme.fromJson({'base': 'light'});
      expect(t.base, 'indigo');
    });

    test('migrates legacy color-mode alias "dark" → "slate"', () {
      final t = OdsTheme.fromJson({'base': 'dark'});
      expect(t.base, 'slate');
    });

    test('preserves valid theme names unchanged', () {
      final t = OdsTheme.fromJson({'base': 'nord'});
      expect(t.base, 'nord');
    });
  });

  group('OdsTheme.toJson', () {
    test('round-trips a full theme', () {
      final t = OdsTheme.fromJson({
        'base': 'abyss',
        'mode': 'dark',
        'headerStyle': 'solid',
        'overrides': {'primary': '#ff0000'},
      });
      final json = t.toJson();
      expect(json['base'], 'abyss');
      expect(json['mode'], 'dark');
      expect(json['headerStyle'], 'solid');
      expect(json['overrides'], {'primary': '#ff0000'});
    });

    test('omits overrides when empty', () {
      const t = OdsTheme();
      expect(t.toJson().containsKey('overrides'), isFalse);
    });
  });
}
