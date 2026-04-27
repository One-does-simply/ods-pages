import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ods_flutter_local/engine/ai_provider.dart';

// =========================================================================
// Property-based tests for the AI provider request builder, mirroring
// React's tests/unit/engine/ai-provider-properties.test.ts. Hand-rolled
// seeded RNG (no glados dep) — same pattern as the parser property
// tests at test/parser/spec_parser_properties_test.dart.
// =========================================================================

const _runs = 30;
final _rng = Random(20260427);

String _randomString({int min = 0, int max = 200}) {
  final len = min + _rng.nextInt(max - min + 1);
  final buf = StringBuffer();
  for (var i = 0; i < len; i++) {
    final pick = _rng.nextInt(64);
    if (pick < 26) {
      buf.writeCharCode(97 + pick);
    } else if (pick < 52) {
      buf.writeCharCode(65 + (pick - 26));
    } else if (pick < 62) {
      buf.writeCharCode(48 + (pick - 52));
    } else {
      buf.write(' ');
    }
  }
  return buf.toString();
}

List<Message> _randomHistory() {
  final n = _rng.nextInt(7);
  return [
    for (var i = 0; i < n; i++)
      Message(
        role: _rng.nextBool() ? 'user' : 'assistant',
        content: _randomString(min: 0, max: 100),
      ),
  ];
}

({http.Client client, List<http.Request> requests}) _stubAnthropic() {
  final captured = <http.Request>[];
  final client = MockClient((req) async {
    captured.add(req);
    return http.Response(
      jsonEncode({
        'content': [{'type': 'text', 'text': 'ok'}],
        'usage': {'input_tokens': 1, 'output_tokens': 1},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return (client: client, requests: captured);
}

({http.Client client, List<http.Request> requests}) _stubOpenAi() {
  final captured = <http.Request>[];
  final client = MockClient((req) async {
    captured.add(req);
    return http.Response(
      jsonEncode({
        'choices': [{'message': {'content': 'ok'}}],
        'usage': {'prompt_tokens': 1, 'completion_tokens': 1},
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return (client: client, requests: captured);
}

void main() {
  group('AnthropicProvider — request-builder properties', () {
    test('always POSTs to the Messages endpoint', () async {
      for (var i = 0; i < _runs; i++) {
        final f = _stubAnthropic();
        await AnthropicProvider(client: f.client).sendMessage(
          _randomString(max: 500),
          _randomHistory(),
          _randomString(max: 200),
          const SendOptions(model: 'claude-sonnet-4-6', apiKey: 'sk-ant-test'),
        );
        expect(
          f.requests.single.url.toString(),
          'https://api.anthropic.com/v1/messages',
        );
        expect(f.requests.single.method, 'POST');
      }
    });

    test('always preserves history order with user appended last', () async {
      for (var i = 0; i < _runs; i++) {
        final sys = _randomString(max: 200);
        final hist = _randomHistory();
        final user = _randomString(max: 200);
        final f = _stubAnthropic();
        await AnthropicProvider(client: f.client).sendMessage(
          sys,
          hist,
          user,
          const SendOptions(model: 'claude-sonnet-4-6', apiKey: 'sk-ant-test'),
        );
        final body = jsonDecode(f.requests.single.body) as Map<String, dynamic>;
        expect(body['system'], sys);
        expect(
          body['messages'],
          [
            ...hist.map((m) => {'role': m.role, 'content': m.content}),
            {'role': 'user', 'content': user},
          ],
        );
      }
    });
  });

  group('OpenAiProvider — request-builder properties', () {
    test('always POSTs to the Chat Completions endpoint', () async {
      for (var i = 0; i < _runs; i++) {
        final f = _stubOpenAi();
        await OpenAiProvider(client: f.client).sendMessage(
          _randomString(max: 500),
          _randomHistory(),
          _randomString(max: 200),
          const SendOptions(model: 'gpt-4o', apiKey: 'sk-openai-test'),
        );
        expect(
          f.requests.single.url.toString(),
          'https://api.openai.com/v1/chat/completions',
        );
        expect(f.requests.single.method, 'POST');
      }
    });

    test('always prepends system + appends user', () async {
      for (var i = 0; i < _runs; i++) {
        final sys = _randomString(max: 200);
        final hist = _randomHistory();
        final user = _randomString(max: 200);
        final f = _stubOpenAi();
        await OpenAiProvider(client: f.client).sendMessage(
          sys,
          hist,
          user,
          const SendOptions(model: 'gpt-4o', apiKey: 'sk-openai-test'),
        );
        final body = jsonDecode(f.requests.single.body) as Map<String, dynamic>;
        final messages = body['messages'] as List;
        expect(messages.first, {'role': 'system', 'content': sys});
        expect(messages.last, {'role': 'user', 'content': user});
        expect(messages.length, hist.length + 2);
      }
    });
  });
}
