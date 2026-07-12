import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ods_flutter_local/engine/ai_chat_prompt.dart';

// =========================================================================
// Multi-turn chat helpers (ADR-0003 phase 4) — Dart mirror of
// tests/unit/engine/ai-chat-prompt.test.ts. The chat protocol uses
// `<spec>...</spec>` tags so the AI can reply with prose, with a complete
// spec proposal, or both. The screen renders the prose as a chat bubble
// and any proposed spec as a diff card with Apply/Discard. Keep the
// assertions in sync — the wording is shared across frameworks.
// =========================================================================

const _base = 'You are the ODS Build Helper.';
const _spec =
    '{"appName":"Demo","startPage":"home","pages":{"home":{"component":"page","title":"Home","content":[]}}}';

void main() {
  group('buildChatSystemPrompt', () {
    test('includes the base system prompt verbatim', () {
      final out = buildChatSystemPrompt(_base, _spec);
      expect(out.startsWith(_base), isTrue);
    });

    test('teaches the AI the <spec> tag protocol', () {
      final out = buildChatSystemPrompt(_base, _spec);
      // The exact wording can drift but the key tokens must be present.
      expect(out, contains('<spec>'));
      expect(out, contains('</spec>'));
    });

    test('embeds the current spec so the AI has working context', () {
      final out = buildChatSystemPrompt(_base, _spec);
      expect(out, contains(_spec));
    });

    test('still emits the protocol directive when the base system is empty',
        () {
      final out = buildChatSystemPrompt('', _spec);
      expect(out, contains('<spec>'));
      expect(out, contains(_spec));
    });
  });

  group('extractProposedSpec — split prose vs proposed spec', () {
    test('returns prose unchanged + spec=null when no tags present', () {
      final r = extractProposedSpec('Sure, what would you like to change?');
      expect(r.prose, 'Sure, what would you like to change?');
      expect(r.spec, isNull);
    });

    test('extracts a spec wrapped in <spec> tags', () {
      final r = extractProposedSpec('Here you go:\n<spec>$_spec</spec>\nLet me know!');
      expect(r.spec, _spec);
    });

    test('strips the spec block from the prose', () {
      final r = extractProposedSpec('Here you go:\n<spec>$_spec</spec>\nLet me know!');
      expect(r.prose, isNot(contains('<spec>')));
      expect(r.prose, isNot(contains('</spec>')));
      expect(r.prose, contains('Here you go:'));
      expect(r.prose, contains('Let me know!'));
    });

    test('handles multi-line JSON inside the tags', () {
      final pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(_spec));
      final r = extractProposedSpec('Done.\n<spec>\n$pretty\n</spec>');
      expect(r.spec, pretty);
    });

    test('handles a tag-only response (spec proposal with no prose)', () {
      final r = extractProposedSpec('<spec>$_spec</spec>');
      expect(r.spec, _spec);
      expect(r.prose.trim(), '');
    });

    test('returns null spec when only an opening tag is present (malformed)',
        () {
      final r = extractProposedSpec('Sure thing! <spec>$_spec');
      expect(r.spec, isNull);
    });

    test('extracts the first complete <spec> block when multiple are present',
        () {
      final r = extractProposedSpec(
        'first attempt:\n<spec>{"appName":"A"}</spec>\nactually, better:\n<spec>{"appName":"B"}</spec>',
      );
      expect(r.spec, '{"appName":"A"}');
    });

    test('is case-insensitive on the tag name', () {
      final r = extractProposedSpec('<SPEC>$_spec</SPEC>');
      expect(r.spec, _spec);
    });
  });
}
