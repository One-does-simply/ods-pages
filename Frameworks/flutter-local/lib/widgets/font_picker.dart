import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// FontPicker — curated dropdown of font choices with a Custom… escape hatch.
//
// Mirrors `Frameworks/react-web/src/components/FontPicker.tsx`. Per ADR-0002,
// font selection used to be a freeform textbox where the user had to know
// font names by heart. This widget replaces that with a curated list:
// system-safe fonts that resolve everywhere, plus the Google Fonts the React
// renderer can lazy-load. "Custom…" reveals a freeform input for power users.
//
// On Flutter the Google Fonts won't be loaded automatically (the codebase
// doesn't bundle the `google_fonts` package today) — they're listed for
// spec-author parity with React, where the same picker exists. Specs
// authored on either renderer should produce the same on-disk shape.
// ---------------------------------------------------------------------------

class _FontOption {
  const _FontOption({required this.label, required this.value});
  final String label;
  final String value;
}

const _systemSentinel = '__system__';
const _customSentinel = '__custom__';

const _systemFonts = <_FontOption>[
  _FontOption(label: 'System default', value: _systemSentinel),
  _FontOption(label: 'Georgia', value: 'Georgia'),
  _FontOption(label: 'Times New Roman', value: 'Times New Roman'),
  _FontOption(label: 'Courier New', value: 'Courier New'),
  _FontOption(label: 'Verdana', value: 'Verdana'),
  _FontOption(label: 'Tahoma', value: 'Tahoma'),
  _FontOption(label: 'Trebuchet MS', value: 'Trebuchet MS'),
];

const _googleFonts = <_FontOption>[
  _FontOption(label: 'Inter', value: 'Inter'),
  _FontOption(label: 'Roboto', value: 'Roboto'),
  _FontOption(label: 'Open Sans', value: 'Open Sans'),
  _FontOption(label: 'Lato', value: 'Lato'),
  _FontOption(label: 'Source Serif 4', value: 'Source Serif 4'),
  _FontOption(label: 'Playfair Display', value: 'Playfair Display'),
  _FontOption(label: 'Merriweather', value: 'Merriweather'),
  _FontOption(label: 'JetBrains Mono', value: 'JetBrains Mono'),
];

List<_FontOption> get _all => [..._systemFonts, ..._googleFonts];

/// Curated font picker. [value] is the current font family ('' = system
/// default); [onChanged] is called with the new value (also empty string
/// for system default). Custom values that don't match any built-in
/// option round-trip through the Custom… escape hatch.
class FontPicker extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  const FontPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Font',
  });

  @override
  State<FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<FontPicker> {
  late String _dropdownValue;
  late TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    final matched = _all.firstWhere(
      (o) => o.value == widget.value,
      orElse: () => const _FontOption(label: '', value: ''),
    );
    final isCustom = widget.value.isNotEmpty &&
        matched.value.isEmpty &&
        widget.value != _systemSentinel;
    _dropdownValue = widget.value.isEmpty
        ? _systemSentinel
        : (matched.value.isNotEmpty ? matched.value : _customSentinel);
    _customController = TextEditingController(text: isCustom ? widget.value : '');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _handleDropdown(String? raw) {
    final next = raw ?? _systemSentinel;
    setState(() => _dropdownValue = next);
    if (next == _systemSentinel) {
      widget.onChanged('');
    } else if (next == _customSentinel) {
      widget.onChanged(_customController.text);
    } else {
      widget.onChanged(next);
    }
  }

  void _handleCustom(String next) {
    setState(() => _customController.text = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final items = <DropdownMenuItem<String>>[
      for (final o in _systemFonts)
        DropdownMenuItem(value: o.value, child: Text(o.label)),
      const DropdownMenuItem(value: _customSentinel, child: Text('Custom…')),
      for (final o in _googleFonts)
        DropdownMenuItem(value: o.value, child: Text(o.label)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _dropdownValue,
          decoration: InputDecoration(
            labelText: widget.label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          items: items,
          onChanged: _handleDropdown,
          style: theme.textTheme.bodyMedium,
        ),
        if (_dropdownValue == _customSentinel) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customController,
            decoration: const InputDecoration(
              hintText: 'e.g., Inter, Comic Sans MS',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: _handleCustom,
          ),
        ],
      ],
    );
  }
}
