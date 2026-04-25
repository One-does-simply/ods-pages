/// Theme + customizations for an ODS app.
///
/// Per ADR-0002 this is the single concept builders learn for visual
/// style. A theme picks a base palette from the catalog; `overrides`
/// adjusts any token (color, font, header style, etc.) on top of it.
///
/// App identity (logo / favicon / appName / appIcon) is NOT here —
/// it lives at the top level of `OdsApp` because it's "which app is
/// this," not visual style.
class OdsTheme {
  /// Base theme name from the catalog (e.g., 'indigo', 'abyss').
  final String base;

  /// Color scheme: 'light', 'dark', or 'system' (follow OS preference).
  final String mode;

  /// App bar style: 'solid', 'light', or 'transparent'.
  final String headerStyle;

  /// Per-token overrides on top of the chosen base theme. Token names
  /// follow the theme JSON's color keys (`primary`, `secondary`,
  /// `base100`, etc.) and font keys (`fontSans`, `fontSerif`,
  /// `fontMono`).
  final Map<String, String> overrides;

  const OdsTheme({
    this.base = 'indigo',
    this.mode = 'system',
    this.headerStyle = 'light',
    this.overrides = const {},
  });

  static const _validModes = {'light', 'dark', 'system'};
  static const _validHeaderStyles = {'light', 'solid', 'transparent'};

  factory OdsTheme.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OdsTheme();

    var base = json['base'] as String? ?? 'indigo';
    // Legacy color-mode aliases that some hand-edited specs may carry.
    if (base == 'light') base = 'indigo';
    if (base == 'dark') base = 'slate';

    final modeRaw = json['mode'] as String?;
    final mode = _validModes.contains(modeRaw) ? modeRaw! : 'system';

    final hsRaw = json['headerStyle'] as String?;
    final headerStyle =
        _validHeaderStyles.contains(hsRaw) ? hsRaw! : 'light';

    final overrides = (json['overrides'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
        const <String, String>{};

    return OdsTheme(
      base: base,
      mode: mode,
      headerStyle: headerStyle,
      overrides: overrides,
    );
  }

  Map<String, dynamic> toJson() => {
        'base': base,
        'mode': mode,
        'headerStyle': headerStyle,
        if (overrides.isNotEmpty) 'overrides': overrides,
      };
}
