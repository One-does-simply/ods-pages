// ---------------------------------------------------------------------------
// AI provider layer (ADR-0003 phase 1).
//
// Two implementations behind one interface so the rest of the framework
// (settings panel, one-shot edit screen, future chat panel) doesn't care
// whether it's talking to Anthropic or OpenAI. Both providers use raw
// `fetch` — no SDK deps — and accept an injected fetch impl so tests run
// without real HTTP. Streaming, tool-use, and conversation persistence
// are explicitly deferred to later phases (ADR-0003 §5).
// ---------------------------------------------------------------------------

export interface Message {
  role: 'user' | 'assistant'
  content: string
}

export interface AiModel {
  id: string
  label: string
  contextWindow: number
  /** Prices in USD per 1,000,000 tokens. Refresh periodically; provider
   *  pricing changes don't usually break code, just the cost estimate. */
  pricing: {
    inputPerMTok: number
    outputPerMTok: number
  }
}

export interface CostEstimate {
  inputTokens: number
  estimatedCostUsd: number
}

export interface SendOptions {
  model: string
  apiKey: string
  signal?: AbortSignal
}

export interface AiResponse {
  text: string
  usage: { inputTokens: number; outputTokens: number }
}

/** A `fetch`-compatible function. Default is the global; tests inject a fake. */
export type Fetch = typeof fetch

export class AiProviderError extends Error {
  readonly provider: 'anthropic' | 'openai'
  readonly status?: number
  readonly responseBody?: unknown

  constructor(
    message: string,
    provider: 'anthropic' | 'openai',
    status?: number,
    responseBody?: unknown,
  ) {
    super(message)
    this.name = 'AiProviderError'
    this.provider = provider
    this.status = status
    this.responseBody = responseBody
  }
}

export interface AiProvider {
  readonly name: 'anthropic' | 'openai'
  readonly models: AiModel[]
  estimateCost(systemPrompt: string, history: Message[], userMessage: string, modelId: string): CostEstimate
  sendMessage(systemPrompt: string, history: Message[], userMessage: string, opts: SendOptions): Promise<AiResponse>
}

// ---------------------------------------------------------------------------
// Token estimation
// ---------------------------------------------------------------------------

/** Crude estimate: ~4 characters per token. Both providers' real
 *  tokenizers vary by model and content; this is a warning-UI estimate
 *  only, never used for billing. */
function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4)
}

function estimateCostFor(
  models: AiModel[],
  providerName: 'anthropic' | 'openai',
  systemPrompt: string,
  history: Message[],
  userMessage: string,
  modelId: string,
): CostEstimate {
  const model = models.find((m) => m.id === modelId)
  if (!model) {
    throw new AiProviderError(
      `Unknown model "${modelId}" — pick one of: ${models.map((m) => m.id).join(', ')}`,
      providerName,
    )
  }
  const totalChars =
    systemPrompt.length +
    userMessage.length +
    history.reduce((sum, m) => sum + m.content.length, 0)
  const inputTokens = estimateTokens(' '.repeat(totalChars))
  const estimatedCostUsd = (inputTokens / 1_000_000) * model.pricing.inputPerMTok
  return { inputTokens, estimatedCostUsd }
}

// ---------------------------------------------------------------------------
// Anthropic
// ---------------------------------------------------------------------------

export const ANTHROPIC_MODELS: AiModel[] = [
  {
    id: 'claude-opus-4-7',
    label: 'Claude Opus 4.7 (most capable)',
    contextWindow: 200_000,
    pricing: { inputPerMTok: 15, outputPerMTok: 75 },
  },
  {
    id: 'claude-sonnet-4-6',
    label: 'Claude Sonnet 4.6 (balanced)',
    contextWindow: 200_000,
    pricing: { inputPerMTok: 3, outputPerMTok: 15 },
  },
  {
    id: 'claude-haiku-4-5',
    label: 'Claude Haiku 4.5 (fastest)',
    contextWindow: 200_000,
    pricing: { inputPerMTok: 1, outputPerMTok: 5 },
  },
]

const ANTHROPIC_VERSION = '2023-06-01'

export class AnthropicProvider implements AiProvider {
  readonly name = 'anthropic' as const
  readonly models = ANTHROPIC_MODELS
  private readonly fetchImpl: Fetch

  constructor(fetchImpl?: Fetch) {
    // If no impl is injected (production path), bind the global fetch
    // to its rightful receiver. Without this, browsers throw "Illegal
    // invocation" because `fetch` requires `this === window`. Tests
    // pass their own MockClient-like function so the bind is a no-op.
    this.fetchImpl = fetchImpl ?? ((input, init) => globalThis.fetch(input, init))
  }

  estimateCost(systemPrompt: string, history: Message[], userMessage: string, modelId: string): CostEstimate {
    return estimateCostFor(this.models, this.name, systemPrompt, history, userMessage, modelId)
  }

  async sendMessage(
    systemPrompt: string,
    history: Message[],
    userMessage: string,
    opts: SendOptions,
  ): Promise<AiResponse> {
    const body = {
      model: opts.model,
      max_tokens: 4096,
      system: systemPrompt,
      messages: [...history, { role: 'user', content: userMessage }],
    }
    const res = await this.fetchImpl('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': opts.apiKey,
        'anthropic-version': ANTHROPIC_VERSION,
      },
      body: JSON.stringify(body),
      signal: opts.signal,
    })

    const json = (await res.json().catch(() => null)) as
      | { content?: Array<{ type: string; text: string }>; usage?: { input_tokens: number; output_tokens: number } }
      | null

    if (!res.ok) {
      throw new AiProviderError(
        `Anthropic request failed (${res.status})`,
        'anthropic',
        res.status,
        json,
      )
    }
    if (!json?.content?.[0]?.text) {
      throw new AiProviderError('Anthropic response missing content[0].text', 'anthropic', res.status, json)
    }
    return {
      text: json.content[0].text,
      usage: {
        inputTokens: json.usage?.input_tokens ?? 0,
        outputTokens: json.usage?.output_tokens ?? 0,
      },
    }
  }
}

// ---------------------------------------------------------------------------
// OpenAI
// ---------------------------------------------------------------------------

export const OPENAI_MODELS: AiModel[] = [
  {
    id: 'gpt-4o',
    label: 'GPT-4o (capable)',
    contextWindow: 128_000,
    pricing: { inputPerMTok: 2.5, outputPerMTok: 10 },
  },
  {
    id: 'gpt-4o-mini',
    label: 'GPT-4o mini (fast + cheap)',
    contextWindow: 128_000,
    pricing: { inputPerMTok: 0.15, outputPerMTok: 0.6 },
  },
]

export class OpenAiProvider implements AiProvider {
  readonly name = 'openai' as const
  readonly models = OPENAI_MODELS
  private readonly fetchImpl: Fetch

  constructor(fetchImpl?: Fetch) {
    // See AnthropicProvider — bind global fetch to globalThis so the
    // browser doesn't throw "Illegal invocation" when we call it via
    // `this.fetchImpl(...)`.
    this.fetchImpl = fetchImpl ?? ((input, init) => globalThis.fetch(input, init))
  }

  estimateCost(systemPrompt: string, history: Message[], userMessage: string, modelId: string): CostEstimate {
    return estimateCostFor(this.models, this.name, systemPrompt, history, userMessage, modelId)
  }

  async sendMessage(
    systemPrompt: string,
    history: Message[],
    userMessage: string,
    opts: SendOptions,
  ): Promise<AiResponse> {
    const body = {
      model: opts.model,
      messages: [
        { role: 'system', content: systemPrompt },
        ...history,
        { role: 'user', content: userMessage },
      ],
    }
    const res = await this.fetchImpl('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'authorization': `Bearer ${opts.apiKey}`,
      },
      body: JSON.stringify(body),
      signal: opts.signal,
    })

    const json = (await res.json().catch(() => null)) as
      | { choices?: Array<{ message?: { content?: string } }>; usage?: { prompt_tokens: number; completion_tokens: number } }
      | null

    if (!res.ok) {
      throw new AiProviderError(
        `OpenAI request failed (${res.status})`,
        'openai',
        res.status,
        json,
      )
    }
    const text = json?.choices?.[0]?.message?.content
    if (typeof text !== 'string') {
      throw new AiProviderError('OpenAI response missing choices[0].message.content', 'openai', res.status, json)
    }
    return {
      text,
      usage: {
        inputTokens: json?.usage?.prompt_tokens ?? 0,
        outputTokens: json?.usage?.completion_tokens ?? 0,
      },
    }
  }
}

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

/** Construct a provider by name. Pass-through for the configured fetch. */
export function makeProvider(
  name: 'anthropic' | 'openai',
  fetchImpl?: Fetch,
): AiProvider {
  switch (name) {
    case 'anthropic': return new AnthropicProvider(fetchImpl)
    case 'openai': return new OpenAiProvider(fetchImpl)
  }
}
