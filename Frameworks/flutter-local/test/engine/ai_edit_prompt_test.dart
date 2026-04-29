import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ods_flutter_local/engine/ai_edit_prompt.dart';

// =========================================================================
// One-shot Edit-with-AI prompt + parse helpers (ADR-0003 phase 6) — Dart
// mirror of tests/unit/engine/ai-edit-prompt.test.ts. Keep the assertions
// in sync — the wording is shared across frameworks.
// =========================================================================

const _base = 'You are the ODS Build Helper.';
const _spec =
    '{"appName":"Demo","startPage":"home","pages":{"home":{"component":"page","title":"Home","content":[]}}}';
const _instruction = 'add a priority field with low/medium/high options';

void main() {
  group('buildEditPrompt', () {
    test('preserves the base system prompt unchanged at the top', () {
      final prompt = buildEditPrompt(_spec, _instruction, _base);
      expect(prompt.system.startsWith(_base), isTrue);
    });

    test('appends a one-shot directive to the system prompt', () {
      final prompt = buildEditPrompt(_spec, _instruction, _base);
      // Directive should clearly tell the AI to return JSON only.
      expect(prompt.system.toLowerCase(), contains('json'));
      final lower = prompt.system.toLowerCase();
      expect(
        lower.contains('no commentary') ||
            lower.contains('no explanation') ||
            lower.contains('only') ||
            lower.contains('spec'),
        isTrue,
      );
    });

    test('embeds the current spec verbatim in the user message', () {
      final prompt = buildEditPrompt(_spec, _instruction, _base);
      expect(prompt.user, contains(_spec));
    });

    test('embeds the instruction in the user message', () {
      final prompt = buildEditPrompt(_spec, _instruction, _base);
      expect(prompt.user, contains(_instruction));
    });

    test('handles empty base system prompt by still emitting the directive', () {
      final prompt = buildEditPrompt(_spec, _instruction, '');
      expect(prompt.system.toLowerCase(), contains('json'));
    });

    test('does not crash on multi-line instructions', () {
      const multi =
          'add a priority field\nalso rename "title" to "headline"\nand add a deadline date';
      final prompt = buildEditPrompt(_spec, multi, _base);
      expect(prompt.user, contains(multi));
    });
  });

  group('extractJsonSpec', () {
    test('returns input unchanged when already pure JSON', () {
      expect(extractJsonSpec(_spec), _spec);
    });

    test('strips ```json fences', () {
      const wrapped = '```json\n$_spec\n```';
      expect(extractJsonSpec(wrapped), _spec);
    });

    test('strips bare ``` fences with no language tag', () {
      const wrapped = '```\n$_spec\n```';
      expect(extractJsonSpec(wrapped), _spec);
    });

    test('strips leading/trailing whitespace + commentary outside the JSON block',
        () {
      const wrapped =
          'Sure, here is the updated spec:\n\n```json\n$_spec\n```\n\nLet me know if you want any changes.';
      expect(extractJsonSpec(wrapped), _spec);
    });

    test('returns trimmed text when no fence is present', () {
      const padded = '\n\n  $_spec  \n\n';
      expect(extractJsonSpec(padded), _spec);
    });

    test('handles multi-line JSON inside fences', () {
      final pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(_spec));
      final wrapped = '```json\n$pretty\n```';
      expect(extractJsonSpec(wrapped), pretty);
    });
  });
}
