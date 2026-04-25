// ---------------------------------------------------------------------------
// theme_spec_writer — pure helper for the admin save-to-spec path.
//
// Mirrors React's Frameworks/react-web/src/engine/theme-spec-writer.ts.
// Given a raw spec JSON string and a desired theme + identity payload,
// returns the new spec JSON with `theme`, `logo`, `favicon` rewritten
// surgically. Unknown fields and the original formatting choices outside
// those three blocks are preserved.
//
// Extracted from SettingsScreen (ADR-0002 phase 5) so the round-trip
// semantics are unit-testable without rendering the screen or mocking
// LoadedAppsStore. The persistence side-effect stays in the screen.
// ---------------------------------------------------------------------------

library;

import 'dart:convert';

class SpecWriterParams {
  /// The new `theme.base` (e.g., 'nord', 'indigo').
  final String base;

  /// Color/size token overrides written under `theme.overrides`.
  final Map<String, String> tokenOverrides;

  /// Top-level `logo` URL. Empty string removes the field.
  final String logo;

  /// Top-level `favicon` URL. Empty string removes the field.
  final String favicon;

  /// `theme.headerStyle`. 'light' is the default and is omitted from the spec.
  /// Accepted: 'light' | 'solid' | 'transparent'.
  final String headerStyle;

  /// Folded into `theme.overrides.fontSans` when non-empty.
  final String fontFamily;

  const SpecWriterParams({
    required this.base,
    required this.tokenOverrides,
    required this.logo,
    required this.favicon,
    required this.headerStyle,
    required this.fontFamily,
  });
}

/// Returns the updated spec JSON, or `null` if the input cannot be parsed.
/// Callers should treat null as a soft failure (log + skip the write).
String? buildUpdatedSpecJson(String rawSpecJson, SpecWriterParams params) {
  Map<String, dynamic> spec;
  try {
    final decoded = jsonDecode(rawSpecJson);
    if (decoded is! Map<String, dynamic>) return null;
    spec = decoded;
  } catch (_) {
    return null;
  }

  final themeBlock = <String, dynamic>{'base': params.base};
  final existing = spec['theme'] as Map<String, dynamic>?;
  if (existing != null && existing['mode'] != null) {
    themeBlock['mode'] = existing['mode'];
  }
  if (params.headerStyle != 'light') {
    themeBlock['headerStyle'] = params.headerStyle;
  }

  final tk = <String, String>{...params.tokenOverrides};
  if (params.fontFamily.isNotEmpty) tk['fontSans'] = params.fontFamily;
  if (tk.isNotEmpty) themeBlock['overrides'] = tk;

  spec['theme'] = themeBlock;

  if (params.logo.isNotEmpty) {
    spec['logo'] = params.logo;
  } else {
    spec.remove('logo');
  }

  if (params.favicon.isNotEmpty) {
    spec['favicon'] = params.favicon;
  } else {
    spec.remove('favicon');
  }

  return const JsonEncoder.withIndent('  ').convert(spec);
}
