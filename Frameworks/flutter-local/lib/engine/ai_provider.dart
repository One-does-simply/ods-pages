// ---------------------------------------------------------------------------
// AI provider layer (ADR-0003 phase 1) — Dart side, mirrors React's
// src/engine/ai-provider.ts. Two implementations behind one interface so
// the rest of the framework doesn't care whether it's talking to
// Anthropic or OpenAI. Both providers use package:http directly — no
// SDK deps — and accept an injected http.Client so tests run against
// MockClient instead of real HTTP. Streaming, tool-use, and conversation
// persistence are deferred (ADR-0003 §5).
// ---------------------------------------------------------------------------

library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class Message {
  /// 'user' | 'assistant'
  final String role;
  final String content;
  const Message({required this.role, required this.content});
}

class Pricing {
  /// USD per 1,000,000 input tokens.
  final double inputPerMTok;

  /// USD per 1,000,000 output tokens.
  final double outputPerMTok;
  const Pricing({required this.inputPerMTok, required this.outputPerMTok});
}

class AiModel {
  final String id;
  final String label;
  final int contextWindow;
  final Pricing pricing;
  const AiModel({
    required this.id,
    required this.label,
    required this.contextWindow,
    required this.pricing,
  });
}

class CostEstimate {
  final int inputTokens;
  final double estimatedCostUsd;
  const CostEstimate({required this.inputTokens, required this.estimatedCostUsd});
}

class SendOptions {
  final String model;
  final String apiKey;
  const SendOptions({required this.model, required this.apiKey});
}

class Usage {
  final int inputTokens;
  final int outputTokens;
  const Usage({required this.inputTokens, required this.outputTokens});
}

class AiResponse {
  final String text;
  final Usage usage;
  const AiResponse({required this.text, required this.usage});
}

class AiProviderError implements Exception {
  final String message;

  /// 'anthropic' | 'openai'
  final String provider;
  final int? status;
  final Object? responseBody;
  AiProviderError(
    this.message, {
    required this.provider,
    this.status,
    this.responseBody,
  });
  @override
  String toString() => 'AiProviderError($provider, $status): $message';
}

abstract class AiProvider {
  /// 'anthropic' | 'openai'
  String get name;
  List<AiModel> get models;
  CostEstimate estimateCost(
    String systemPrompt,
    List<Message> history,
    String userMessage,
    String modelId,
  );
  Future<AiResponse> sendMessage(
    String systemPrompt,
    List<Message> history,
    String userMessage,
    SendOptions opts,
  );
}

// ---------------------------------------------------------------------------
// Token estimation
// ---------------------------------------------------------------------------

/// Crude estimate: ~4 characters per token. Both providers' real
/// tokenizers vary by model and content; this is a warning-UI estimate
/// only, never used for billing.
int _estimateTokens(String text) => (text.length / 4).ceil();

CostEstimate _estimateCostFor(
  List<AiModel> models,
  String providerName,
  String systemPrompt,
  List<Message> history,
  String userMessage,
  String modelId,
) {
  final model = models.firstWhere(
    (m) => m.id == modelId,
    orElse: () => throw AiProviderError(
      'Unknown model "$modelId" — pick one of: ${models.map((m) => m.id).join(', ')}',
      provider: providerName,
    ),
  );
  final totalChars = systemPrompt.length +
      userMessage.length +
      history.fold<int>(0, (sum, m) => sum + m.content.length);
  final inputTokens = _estimateTokens(' ' * totalChars);
  final estimatedCostUsd = (inputTokens / 1000000) * model.pricing.inputPerMTok;
  return CostEstimate(inputTokens: inputTokens, estimatedCostUsd: estimatedCostUsd);
}

// ---------------------------------------------------------------------------
// Anthropic
// ---------------------------------------------------------------------------

const anthropicModels = <AiModel>[
  AiModel(
    id: 'claude-opus-4-7',
    label: 'Claude Opus 4.7 (most capable)',
    contextWindow: 200000,
    pricing: Pricing(inputPerMTok: 15, outputPerMTok: 75),
  ),
  AiModel(
    id: 'claude-sonnet-4-6',
    label: 'Claude Sonnet 4.6 (balanced)',
    contextWindow: 200000,
    pricing: Pricing(inputPerMTok: 3, outputPerMTok: 15),
  ),
  AiModel(
    id: 'claude-haiku-4-5',
    label: 'Claude Haiku 4.5 (fastest)',
    contextWindow: 200000,
    pricing: Pricing(inputPerMTok: 1, outputPerMTok: 5),
  ),
];

const _anthropicVersion = '2023-06-01';

class AnthropicProvider implements AiProvider {
  final http.Client _client;

  AnthropicProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get name => 'anthropic';

  @override
  List<AiModel> get models => anthropicModels;

  @override
  CostEstimate estimateCost(
    String systemPrompt,
    List<Message> history,
    String userMessage,
    String modelId,
  ) =>
      _estimateCostFor(models, name, systemPrompt, history, userMessage, modelId);

  @override
  Future<AiResponse> sendMessage(
    String systemPrompt,
    List<Message> history,
    String userMessage,
    SendOptions opts,
  ) async {
    final body = jsonEncode({
      'model': opts.model,
      'max_tokens': 4096,
      'system': systemPrompt,
      'messages': [
        ...history.map((m) => {'role': m.role, 'content': m.content}),
        {'role': 'user', 'content': userMessage},
      ],
    });
    final res = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': opts.apiKey,
        'anthropic-version': _anthropicVersion,
      },
      body: body,
    );

    Object? json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      json = null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiProviderError(
        'Anthropic request failed (${res.statusCode})',
        provider: name,
        status: res.statusCode,
        responseBody: json,
      );
    }
    final content = (json is Map<String, dynamic>) ? json['content'] : null;
    if (content is! List || content.isEmpty) {
      throw AiProviderError(
        'Anthropic response missing content[0].text',
        provider: name,
        status: res.statusCode,
        responseBody: json,
      );
    }
    final first = content.first;
    final text = (first is Map && first['text'] is String) ? first['text'] as String : null;
    if (text == null) {
      throw AiProviderError(
        'Anthropic response missing content[0].text',
        provider: name,
        status: res.statusCode,
        responseBody: json,
      );
    }
    final usage = (json as Map)['usage'] as Map?;
    return AiResponse(
      text: text,
      usage: Usage(
        inputTokens: (usage?['input_tokens'] as int?) ?? 0,
        outputTokens: (usage?['output_tokens'] as int?) ?? 0,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OpenAI
// ---------------------------------------------------------------------------

const openaiModels = <AiModel>[
  AiModel(
    id: 'gpt-4o',
    label: 'GPT-4o (capable)',
    contextWindow: 128000,
    pricing: Pricing(inputPerMTok: 2.5, outputPerMTok: 10),
  ),
  AiModel(
    id: 'gpt-4o-mini',
    label: 'GPT-4o mini (fast + cheap)',
    contextWindow: 128000,
    pricing: Pricing(inputPerMTok: 0.15, outputPerMTok: 0.6),
  ),
];

class OpenAiProvider implements AiProvider {
  final http.Client _client;

  OpenAiProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  String get name => 'openai';

  @override
  List<AiModel> get models => openaiModels;

  @override
  CostEstimate estimateCost(
    String systemPrompt,
    List<Message> history,
    String userMessage,
    String modelId,
  ) =>
      _estimateCostFor(models, name, systemPrompt, history, userMessage, modelId);

  @override
  Future<AiResponse> sendMessage(
    String systemPrompt,
    List<Message> history,
    String userMessage,
    SendOptions opts,
  ) async {
    final body = jsonEncode({
      'model': opts.model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...history.map((m) => {'role': m.role, 'content': m.content}),
        {'role': 'user', 'content': userMessage},
      ],
    });
    final res = await _client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer ${opts.apiKey}',
      },
      body: body,
    );

    Object? json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      json = null;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiProviderError(
        'OpenAI request failed (${res.statusCode})',
        provider: name,
        status: res.statusCode,
        responseBody: json,
      );
    }
    final choices = (json is Map) ? json['choices'] : null;
    final text = (choices is List &&
            choices.isNotEmpty &&
            choices.first is Map &&
            (choices.first as Map)['message'] is Map &&
            ((choices.first as Map)['message'] as Map)['content'] is String)
        ? ((choices.first as Map)['message'] as Map)['content'] as String
        : null;
    if (text == null) {
      throw AiProviderError(
        'OpenAI response missing choices[0].message.content',
        provider: name,
        status: res.statusCode,
        responseBody: json,
      );
    }
    final usage = (json as Map)['usage'] as Map?;
    return AiResponse(
      text: text,
      usage: Usage(
        inputTokens: (usage?['prompt_tokens'] as int?) ?? 0,
        outputTokens: (usage?['completion_tokens'] as int?) ?? 0,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

/// Construct a provider by name. Pass through an http.Client for tests
/// to inject a MockClient.
AiProvider makeProvider(String name, {http.Client? client}) {
  switch (name) {
    case 'anthropic':
      return AnthropicProvider(client: client);
    case 'openai':
      return OpenAiProvider(client: client);
    default:
      throw AiProviderError('Unknown provider "$name"', provider: name);
  }
}
