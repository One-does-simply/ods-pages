import { describe, it, expect, vi } from 'vitest'
import * as fc from 'fast-check'
import {
  AnthropicProvider,
  OpenAiProvider,
  type Fetch,
  type Message,
} from '@/engine/ai-provider.ts'

// =========================================================================
// Property-based tests for the AI provider request builder. Pins the
// invariants that any (systemPrompt, history, userMessage) input must
// produce a well-formed request — the conformance suite (phase 5) will
// pin the cross-framework version of this same contract.
// =========================================================================

const STUB_OK_ANTHROPIC = {
  content: [{ type: 'text', text: 'ok' }],
  usage: { input_tokens: 1, output_tokens: 1 },
}
const STUB_OK_OPENAI = {
  choices: [{ message: { content: 'ok' } }],
  usage: { prompt_tokens: 1, completion_tokens: 1 },
}

function captureFetch(stub: unknown): { fetchImpl: Fetch; calls: Array<{ url: string; init: RequestInit }> } {
  const calls: { url: string; init: RequestInit }[] = []
  const fetchImpl = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push({ url: String(input), init: init ?? {} })
    return new Response(JSON.stringify(stub), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }) as unknown as Fetch
  return { fetchImpl, calls }
}

const messageArb: fc.Arbitrary<Message> = fc.record({
  role: fc.constantFrom<'user' | 'assistant'>('user', 'assistant'),
  content: fc.string({ minLength: 0, maxLength: 200 }),
})

describe('AnthropicProvider — request-builder properties', () => {
  it('always POSTs to the Messages endpoint regardless of input shape', () => {
    fc.assert(
      fc.asyncProperty(
        fc.string({ maxLength: 500 }),
        fc.array(messageArb, { maxLength: 6 }),
        fc.string({ maxLength: 200 }),
        async (sys, hist, user) => {
          const { fetchImpl, calls } = captureFetch(STUB_OK_ANTHROPIC)
          await new AnthropicProvider(fetchImpl).sendMessage(sys, hist, user, {
            model: 'claude-sonnet-4-6',
            apiKey: 'sk-ant-test',
          })
          expect(calls[0].url).toBe('https://api.anthropic.com/v1/messages')
          expect(calls[0].init.method).toBe('POST')
        },
      ),
      { numRuns: 30 },
    )
  })

  it('always preserves history order with the user message appended last', () => {
    fc.assert(
      fc.asyncProperty(
        fc.string({ maxLength: 200 }),
        fc.array(messageArb, { maxLength: 6 }),
        fc.string({ maxLength: 200 }),
        async (sys, hist, user) => {
          const { fetchImpl, calls } = captureFetch(STUB_OK_ANTHROPIC)
          await new AnthropicProvider(fetchImpl).sendMessage(sys, hist, user, {
            model: 'claude-sonnet-4-6',
            apiKey: 'sk-ant-test',
          })
          const body = JSON.parse(String(calls[0].init.body))
          expect(body.system).toBe(sys)
          expect(body.messages).toEqual([...hist, { role: 'user', content: user }])
        },
      ),
      { numRuns: 30 },
    )
  })
})

describe('OpenAiProvider — request-builder properties', () => {
  it('always POSTs to the Chat Completions endpoint regardless of input shape', () => {
    fc.assert(
      fc.asyncProperty(
        fc.string({ maxLength: 500 }),
        fc.array(messageArb, { maxLength: 6 }),
        fc.string({ maxLength: 200 }),
        async (sys, hist, user) => {
          const { fetchImpl, calls } = captureFetch(STUB_OK_OPENAI)
          await new OpenAiProvider(fetchImpl).sendMessage(sys, hist, user, {
            model: 'gpt-4o',
            apiKey: 'sk-openai-test',
          })
          expect(calls[0].url).toBe('https://api.openai.com/v1/chat/completions')
          expect(calls[0].init.method).toBe('POST')
        },
      ),
      { numRuns: 30 },
    )
  })

  it('always prepends the system message and appends the user message', () => {
    fc.assert(
      fc.asyncProperty(
        fc.string({ maxLength: 200 }),
        fc.array(messageArb, { maxLength: 6 }),
        fc.string({ maxLength: 200 }),
        async (sys, hist, user) => {
          const { fetchImpl, calls } = captureFetch(STUB_OK_OPENAI)
          await new OpenAiProvider(fetchImpl).sendMessage(sys, hist, user, {
            model: 'gpt-4o',
            apiKey: 'sk-openai-test',
          })
          const body = JSON.parse(String(calls[0].init.body))
          expect(body.messages[0]).toEqual({ role: 'system', content: sys })
          expect(body.messages[body.messages.length - 1]).toEqual({ role: 'user', content: user })
          expect(body.messages.length).toBe(hist.length + 2)
        },
      ),
      { numRuns: 30 },
    )
  })
})
