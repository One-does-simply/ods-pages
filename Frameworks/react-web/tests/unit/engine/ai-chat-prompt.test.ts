import { describe, it, expect } from 'vitest'
import {
  buildChatSystemPrompt,
  extractProposedSpec,
} from '@/engine/ai-chat-prompt.ts'

// =========================================================================
// Multi-turn chat helpers (ADR-0003 phase 4). The chat protocol uses
// `<spec>...</spec>` tags so the AI can choose to reply with prose, with
// a complete spec proposal, or both. The screen renders the prose as a
// chat bubble and any proposed spec as a diff card with Apply/Discard.
// =========================================================================

const BASE_SYSTEM = 'You are the ODS Build Helper.'
const SPEC =
  '{"appName":"Demo","startPage":"home","pages":{"home":{"component":"page","title":"Home","content":[]}}}'

describe('buildChatSystemPrompt', () => {
  it('includes the base system prompt verbatim', () => {
    const out = buildChatSystemPrompt(BASE_SYSTEM, SPEC)
    expect(out.startsWith(BASE_SYSTEM)).toBe(true)
  })

  it('teaches the AI the <spec> tag protocol', () => {
    const out = buildChatSystemPrompt(BASE_SYSTEM, SPEC)
    // The AI needs to know to wrap full-spec proposals; the exact wording
    // can drift but the key tokens must be present.
    expect(out).toContain('<spec>')
    expect(out).toContain('</spec>')
  })

  it('embeds the current spec so the AI has working context', () => {
    const out = buildChatSystemPrompt(BASE_SYSTEM, SPEC)
    expect(out).toContain(SPEC)
  })

  it('still emits the protocol directive when the base system is empty', () => {
    const out = buildChatSystemPrompt('', SPEC)
    expect(out).toContain('<spec>')
    expect(out).toContain(SPEC)
  })
})

describe('extractProposedSpec — split prose vs proposed spec', () => {
  it('returns prose unchanged + spec=null when no tags present', () => {
    const r = extractProposedSpec('Sure, what would you like to change?')
    expect(r.prose).toBe('Sure, what would you like to change?')
    expect(r.spec).toBe(null)
  })

  it('extracts a spec wrapped in <spec> tags', () => {
    const r = extractProposedSpec('Here you go:\n<spec>' + SPEC + '</spec>\nLet me know!')
    expect(r.spec).toBe(SPEC)
  })

  it('strips the spec block from the prose', () => {
    const r = extractProposedSpec('Here you go:\n<spec>' + SPEC + '</spec>\nLet me know!')
    expect(r.prose).not.toContain('<spec>')
    expect(r.prose).not.toContain('</spec>')
    expect(r.prose).toContain('Here you go:')
    expect(r.prose).toContain('Let me know!')
  })

  it('handles multi-line JSON inside the tags', () => {
    const pretty = JSON.stringify(JSON.parse(SPEC), null, 2)
    const r = extractProposedSpec('Done.\n<spec>\n' + pretty + '\n</spec>')
    expect(r.spec).toBe(pretty)
  })

  it('handles a tag-only response (spec proposal with no prose)', () => {
    const r = extractProposedSpec('<spec>' + SPEC + '</spec>')
    expect(r.spec).toBe(SPEC)
    expect(r.prose.trim()).toBe('')
  })

  it('returns null spec when only an opening tag is present (malformed)', () => {
    const r = extractProposedSpec('Sure thing! <spec>' + SPEC)
    expect(r.spec).toBe(null)
  })

  it('extracts the first complete <spec> block when multiple are present', () => {
    const r = extractProposedSpec(
      'first attempt:\n<spec>{"appName":"A"}</spec>\nactually, better:\n<spec>{"appName":"B"}</spec>',
    )
    expect(r.spec).toBe('{"appName":"A"}')
  })
})
