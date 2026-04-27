import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ods_flutter_local/engine/ai_provider.dart';

// =========================================================================
// AI provider layer (ADR-0003 phase 1) — Dart side, mirrors React's
// tests/unit/engine/ai-provider.test.ts. We use http's MockClient so no
// real network fires; the request shape both providers produce is the
// contract.
// =========================================================================

const _system = 'You are an ODS Build Helper.';
const _user = 'Now make the default "medium"';
final _history = [
  const Message(role: 'user', content: 'Add a priority field'),
  const Message(role: 'assistant', content: 'Sure, here is the update…'),
];

/// Returns (client, captured-requests). Append-only so each test can
/// inspect the exact wire format both providers emitted.
({http.Client client, List<http.Request> requests}) _fakeClient({
  int status = 200,
  required Object responseBody,
}) {
  final captured = <http.Request>[];
  final client = MockClient((req) async {
    captured.add(req);
    return http.Response(
      jsonEncode(responseBody),
      status,
      headers: {'content-type': 'application/json'},
    );
  });
  return (client: client, requests: captured);
}

void main() {
  group('AnthropicProvider — request shape', () {
    test('POSTs to the Messages API endpoint', () async {
      final f = _fakeClient(responseBody: {
        'content': [{'type': 'text', 'text': 'ok'}],
        'usage': {'input_tokens': 10, 'output_tokens': 5},
      });
      await AnthropicProvider(client: f.client).sendMessage(
        _system,
        _history,
        _user,
        const SendOptions(model: 'claude-sonnet-4-6', apiKey: 'sk-ant-test'),
      );
      expect(f.requests.single.url.toString(),
          'https://api.anthropic.com/v1/messages');
      expect(f.requests.single.method, 'POST');
    });

    test('sets x-api-key + anthropic-version headers', () async {
      final f = _fakeClient(responseBody: {
        'content': [{'type': 'text', 'text': 'ok'}],
        'usage': {'input_tokens': 1, 'output_tokens': 1},
      });
      await AnthropicProvider(client: f.client).sendMessage(
        _system,
        const [],
        _user,
        const SendOptions(model: 'claude-sonnet-4-6', apiKey: 'sk-ant-secret'),
      );
      final headers = f.requests.single.headers;
      expect(headers['x-api-key'], 'sk-ant-secret');
      expect(headers['anthropic-version'], isNotNull);
      expect(headers['content-type'], contains('application/json'));
    });

    test('sends system + messages in the Anthropic body shape', () async {
      final f = _fakeClient(responseBody: {
        'content': [{'type': 'text', 'text': 'ok'}],
        'usage': {'input_tokens': 1, 'output_tokens': 1},
      });
      await AnthropicProvider(client: f.client).sendMessage(
        _system,
        _history,
        _user,
        const SendOptions(model: 'claude-sonnet-4-6', apiKey: 'sk-ant-test'),
      );
      final body = jsonDecode(f.requests.single.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-sonnet-4-6');
      expect(body['system'], _system);
      expect(body['max_tokens'], greaterThan(0));
      expect(
        body['messages'],
        [
          ..._history.map((m) => {'role': m.role, 'content': m.content}),
          {'role': 'user', 'content': _user},
        ],
      );
    });

    test('parses the assistant text from the response', () async {
      final f = _fakeClient(responseBody: {
        'content': [{'type': 'text', 'text': 'Here is your spec'}],
        'usage': {'input_tokens': 42, 'output_tokens': 17},
      });
      final r = await AnthropicProvider(client: f.client).sendMessage(
        _system,
        const [],
        _user,
        const SendOptions(model: 'claude-sonnet-4-6', apiKey: 'sk-ant-test'),
      );
      expect(r.text, 'Here is your spec');
      expect(r.usage.inputTokens, 42);
      expect(r.usage.outputTokens, 17);
    });

    test('throws AiProviderError on 4xx with status', () async {
      final f = _fakeClient(
        status: 401,
        responseBody: {
          'error': {'type': 'authentication_error', 'message': 'Invalid API key'},
        },
      );
      expect(
        () => AnthropicProvider(client: f.client).sendMessage(
          _system,
          const [],
          _user,
          const SendOptions(model: 'claude-sonnet-4-6', apiKey: 'wrong'),
        ),
        throwsA(isA<AiProviderError>()
            .having((e) => e.provider, 'provider', 'anthropic')
            .having((e) => e.status, 'status', 401)),
      );
    });
  });

  group('OpenAiProvider — request shape', () {
    test('POSTs to the Chat Completions endpoint', () async {
      final f = _fakeClient(responseBody: {
        'choices': [{'message': {'content': 'ok'}}],
        'usage': {'prompt_tokens': 10, 'completion_tokens': 5},
      });
      await OpenAiProvider(client: f.client).sendMessage(
        _system,
        _history,
        _user,
        const SendOptions(model: 'gpt-4o', apiKey: 'sk-openai-test'),
      );
      expect(f.requests.single.url.toString(),
          'https://api.openai.com/v1/chat/completions');
      expect(f.requests.single.method, 'POST');
    });

    test('sets Authorization: Bearer header', () async {
      final f = _fakeClient(responseBody: {
        'choices': [{'message': {'content': 'ok'}}],
        'usage': {'prompt_tokens': 1, 'completion_tokens': 1},
      });
      await OpenAiProvider(client: f.client).sendMessage(
        _system,
        const [],
        _user,
        const SendOptions(model: 'gpt-4o', apiKey: 'sk-openai-secret'),
      );
      final headers = f.requests.single.headers;
      expect(headers['authorization'], 'Bearer sk-openai-secret');
      expect(headers['content-type'], contains('application/json'));
    });

    test('sends system as the first message in the OpenAI body shape', () async {
      final f = _fakeClient(responseBody: {
        'choices': [{'message': {'content': 'ok'}}],
        'usage': {'prompt_tokens': 1, 'completion_tokens': 1},
      });
      await OpenAiProvider(client: f.client).sendMessage(
        _system,
        _history,
        _user,
        const SendOptions(model: 'gpt-4o', apiKey: 'sk-openai-test'),
      );
      final body = jsonDecode(f.requests.single.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-4o');
      expect(
        body['messages'],
        [
          {'role': 'system', 'content': _system},
          ..._history.map((m) => {'role': m.role, 'content': m.content}),
          {'role': 'user', 'content': _user},
        ],
      );
    });

    test('parses the assistant text from choices[0].message.content', () async {
      final f = _fakeClient(responseBody: {
        'choices': [{'message': {'content': 'OpenAI says hi'}}],
        'usage': {'prompt_tokens': 8, 'completion_tokens': 4},
      });
      final r = await OpenAiProvider(client: f.client).sendMessage(
        _system,
        const [],
        _user,
        const SendOptions(model: 'gpt-4o', apiKey: 'sk-openai-test'),
      );
      expect(r.text, 'OpenAI says hi');
      expect(r.usage.inputTokens, 8);
      expect(r.usage.outputTokens, 4);
    });

    test('throws AiProviderError on 4xx with status', () async {
      final f = _fakeClient(
        status: 429,
        responseBody: {
          'error': {'message': 'Rate limit exceeded'},
        },
      );
      expect(
        () => OpenAiProvider(client: f.client).sendMessage(
          _system,
          const [],
          _user,
          const SendOptions(model: 'gpt-4o', apiKey: 'sk-openai-test'),
        ),
        throwsA(isA<AiProviderError>()
            .having((e) => e.provider, 'provider', 'openai')
            .having((e) => e.status, 'status', 429)),
      );
    });
  });

  group('estimateCost — both providers', () {
    test('Anthropic: input tokens ≈ char-count / 4 and cost uses model pricing', () {
      final p = AnthropicProvider();
      final c = p.estimateCost(
        'a' * 80,
        const [],
        'b' * 20,
        'claude-sonnet-4-6',
      );
      expect(c.inputTokens, greaterThanOrEqualTo(20));
      expect(c.inputTokens, lessThanOrEqualTo(30));
      expect(c.estimatedCostUsd, greaterThan(0));
      expect(c.estimatedCostUsd, lessThan(0.01));
    });

    test('OpenAI: same formula, different model pricing', () {
      final p = OpenAiProvider();
      final c = p.estimateCost('a' * 80, const [], 'b' * 20, 'gpt-4o-mini');
      expect(c.inputTokens, greaterThan(0));
      expect(c.estimatedCostUsd, greaterThan(0));
    });

    test('throws AiProviderError if the model id is unknown', () {
      expect(
        () => AnthropicProvider().estimateCost('a', const [], 'b', 'gpt-4o'),
        throwsA(isA<AiProviderError>()),
      );
    });
  });

  group('model registry', () {
    test('Anthropic exposes at least 3 curated models with pricing', () {
      final models = AnthropicProvider().models;
      expect(models.length, greaterThanOrEqualTo(3));
      for (final m in models) {
        expect(m.id, isNotEmpty);
        expect(m.label, isNotEmpty);
        expect(m.pricing.inputPerMTok, greaterThan(0));
        expect(m.pricing.outputPerMTok, greaterThan(0));
      }
    });

    test('OpenAI exposes at least 2 curated models with pricing', () {
      final models = OpenAiProvider().models;
      expect(models.length, greaterThanOrEqualTo(2));
      for (final m in models) {
        expect(m.id, isNotEmpty);
        expect(m.pricing.inputPerMTok, greaterThan(0));
      }
    });
  });
}
