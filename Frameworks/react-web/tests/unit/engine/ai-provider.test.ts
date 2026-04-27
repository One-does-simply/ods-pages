import { describe, it, expect, vi } from 'vitest'
import {
  AnthropicProvider,
  OpenAiProvider,
  AiProviderError,
  type Fetch,
  type Message,
} from '@/engine/ai-provider.ts'

// =========================================================================
// AI provider layer (ADR-0003 phase 1).
//
// Tests use an injected fake `fetch` so no real HTTP fires. The shape of
// the request is the contract we promise — both providers must produce a
// well-formed call that the conformance suite (phase 5) will eventually
// pin cross-framework.
// =========================================================================

function fakeFetch(
  response: { status?: number; body: unknown },
): { fetchImpl: Fetch; calls: Array<{ url: string; init: RequestInit }> } {
  const calls: { url: string; init: RequestInit }[] = []
  const fetchImpl = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({ url: String(input), init: init ?? {} })
    return new Response(JSON.stringify(response.body), {
      status: response.status ?? 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }) as unknown as Fetch
  return { fetchImpl, calls }
}

const SYSTEM = 'You are an ODS Build Helper.'
const HISTORY: Message[] = [
  { role: 'user', content: 'Add a priority field' },
  { role: 'assistant', content: 'Sure, here is the update…' },
]
const USER = 'Now make the default "medium"'

describe('AnthropicProvider — request shape', () => {
  it('POSTs to the Messages API endpoint', async () => {
    const { fetchImpl, calls } = fakeFetch({
      body: {
        content: [{ type: 'text', text: 'ok' }],
        usage: { input_tokens: 10, output_tokens: 5 },
      },
    })
    const p = new AnthropicProvider(fetchImpl)
    await p.sendMessage(SYSTEM, HISTORY, USER, {
      model: 'claude-sonnet-4-6',
      apiKey: 'sk-ant-test',
    })

    expect(calls[0].url).toBe('https://api.anthropic.com/v1/messages')
    expect(calls[0].init.method).toBe('POST')
  })

  it('sets x-api-key + anthropic-version headers', async () => {
    const { fetchImpl, calls } = fakeFetch({
      body: { content: [{ type: 'text', text: 'ok' }], usage: { input_tokens: 1, output_tokens: 1 } },
    })
    await new AnthropicProvider(fetchImpl).sendMessage(SYSTEM, [], USER, {
      model: 'claude-sonnet-4-6',
      apiKey: 'sk-ant-secret',
    })

    const headers = calls[0].init.headers as Record<string, string>
    expect(headers['x-api-key']).toBe('sk-ant-secret')
    expect(headers['anthropic-version']).toBeDefined()
    expect(headers['content-type']).toBe('application/json')
  })

  it('sends system + messages in the Anthropic body shape', async () => {
    const { fetchImpl, calls } = fakeFetch({
      body: { content: [{ type: 'text', text: 'ok' }], usage: { input_tokens: 1, output_tokens: 1 } },
    })
    await new AnthropicProvider(fetchImpl).sendMessage(SYSTEM, HISTORY, USER, {
      model: 'claude-sonnet-4-6',
      apiKey: 'sk-ant-test',
    })

    const body = JSON.parse(String(calls[0].init.body))
    expect(body.model).toBe('claude-sonnet-4-6')
    expect(body.system).toBe(SYSTEM)
    expect(body.max_tokens).toBeGreaterThan(0)
    // Anthropic format: history then current user, no system in messages array.
    expect(body.messages).toEqual([
      ...HISTORY,
      { role: 'user', content: USER },
    ])
  })

  it('parses the assistant text from the response', async () => {
    const { fetchImpl } = fakeFetch({
      body: {
        content: [{ type: 'text', text: 'Here is your spec' }],
        usage: { input_tokens: 42, output_tokens: 17 },
      },
    })
    const r = await new AnthropicProvider(fetchImpl).sendMessage(SYSTEM, [], USER, {
      model: 'claude-sonnet-4-6',
      apiKey: 'sk-ant-test',
    })

    expect(r.text).toBe('Here is your spec')
    expect(r.usage.inputTokens).toBe(42)
    expect(r.usage.outputTokens).toBe(17)
  })

  it('throws AiProviderError on 4xx with status + body', async () => {
    const { fetchImpl } = fakeFetch({
      status: 401,
      body: { error: { type: 'authentication_error', message: 'Invalid API key' } },
    })
    const send = new AnthropicProvider(fetchImpl).sendMessage(SYSTEM, [], USER, {
      model: 'claude-sonnet-4-6',
      apiKey: 'wrong',
    })

    await expect(send).rejects.toBeInstanceOf(AiProviderError)
    await expect(send).rejects.toMatchObject({
      provider: 'anthropic',
      status: 401,
    })
  })
})

describe('OpenAiProvider — request shape', () => {
  it('POSTs to the Chat Completions endpoint', async () => {
    const { fetchImpl, calls } = fakeFetch({
      body: {
        choices: [{ message: { content: 'ok' } }],
        usage: { prompt_tokens: 10, completion_tokens: 5 },
      },
    })
    await new OpenAiProvider(fetchImpl).sendMessage(SYSTEM, HISTORY, USER, {
      model: 'gpt-4o',
      apiKey: 'sk-openai-test',
    })

    expect(calls[0].url).toBe('https://api.openai.com/v1/chat/completions')
    expect(calls[0].init.method).toBe('POST')
  })

  it('sets Authorization: Bearer header', async () => {
    const { fetchImpl, calls } = fakeFetch({
      body: {
        choices: [{ message: { content: 'ok' } }],
        usage: { prompt_tokens: 1, completion_tokens: 1 },
      },
    })
    await new OpenAiProvider(fetchImpl).sendMessage(SYSTEM, [], USER, {
      model: 'gpt-4o',
      apiKey: 'sk-openai-secret',
    })

    const headers = calls[0].init.headers as Record<string, string>
    expect(headers['authorization']).toBe('Bearer sk-openai-secret')
    expect(headers['content-type']).toBe('application/json')
  })

  it('sends system as the first message in the OpenAI body shape', async () => {
    const { fetchImpl, calls } = fakeFetch({
      body: {
        choices: [{ message: { content: 'ok' } }],
        usage: { prompt_tokens: 1, completion_tokens: 1 },
      },
    })
    await new OpenAiProvider(fetchImpl).sendMessage(SYSTEM, HISTORY, USER, {
      model: 'gpt-4o',
      apiKey: 'sk-openai-test',
    })

    const body = JSON.parse(String(calls[0].init.body))
    expect(body.model).toBe('gpt-4o')
    // OpenAI format: system as first message in the messages array.
    expect(body.messages).toEqual([
      { role: 'system', content: SYSTEM },
      ...HISTORY,
      { role: 'user', content: USER },
    ])
  })

  it('parses the assistant text from choices[0].message.content', async () => {
    const { fetchImpl } = fakeFetch({
      body: {
        choices: [{ message: { content: 'OpenAI says hi' } }],
        usage: { prompt_tokens: 8, completion_tokens: 4 },
      },
    })
    const r = await new OpenAiProvider(fetchImpl).sendMessage(SYSTEM, [], USER, {
      model: 'gpt-4o',
      apiKey: 'sk-openai-test',
    })

    expect(r.text).toBe('OpenAI says hi')
    expect(r.usage.inputTokens).toBe(8)
    expect(r.usage.outputTokens).toBe(4)
  })

  it('throws AiProviderError on 4xx with status + body', async () => {
    const { fetchImpl } = fakeFetch({
      status: 429,
      body: { error: { message: 'Rate limit exceeded' } },
    })
    const send = new OpenAiProvider(fetchImpl).sendMessage(SYSTEM, [], USER, {
      model: 'gpt-4o',
      apiKey: 'sk-openai-test',
    })

    await expect(send).rejects.toBeInstanceOf(AiProviderError)
    await expect(send).rejects.toMatchObject({
      provider: 'openai',
      status: 429,
    })
  })
})

describe('estimateCost — both providers', () => {
  it('Anthropic: input tokens ≈ char-count / 4 and cost uses model pricing', () => {
    const p = new AnthropicProvider()
    // ~100 chars across the prompt = ~25 tokens.
    const c = p.estimateCost('a'.repeat(80), [], 'b'.repeat(20), 'claude-sonnet-4-6')
    expect(c.inputTokens).toBeGreaterThanOrEqual(20)
    expect(c.inputTokens).toBeLessThanOrEqual(30)
    expect(c.estimatedCostUsd).toBeGreaterThan(0)
    expect(c.estimatedCostUsd).toBeLessThan(0.01) // sanity for small input
  })

  it('OpenAI: same formula, different model pricing applied', () => {
    const p = new OpenAiProvider()
    const c = p.estimateCost('a'.repeat(80), [], 'b'.repeat(20), 'gpt-4o-mini')
    expect(c.inputTokens).toBeGreaterThan(0)
    expect(c.estimatedCostUsd).toBeGreaterThan(0)
  })

  it('throws if the model id is unknown', () => {
    expect(() => new AnthropicProvider().estimateCost('a', [], 'b', 'gpt-4o'))
      .toThrow(/unknown model/i)
  })
})

describe('model registry', () => {
  it('Anthropic exposes at least 3 curated models with pricing', () => {
    const models = new AnthropicProvider().models
    expect(models.length).toBeGreaterThanOrEqual(3)
    for (const m of models) {
      expect(m.id).toBeTruthy()
      expect(m.label).toBeTruthy()
      expect(m.pricing.inputPerMTok).toBeGreaterThan(0)
      expect(m.pricing.outputPerMTok).toBeGreaterThan(0)
    }
  })

  it('OpenAI exposes at least 2 curated models with pricing', () => {
    const models = new OpenAiProvider().models
    expect(models.length).toBeGreaterThanOrEqual(2)
    for (const m of models) {
      expect(m.id).toBeTruthy()
      expect(m.pricing.inputPerMTok).toBeGreaterThan(0)
    }
  })
})
