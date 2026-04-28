import { describe, it, expect } from 'vitest'
import {
  buildEditPrompt,
  extractJsonSpec,
} from '@/engine/ai-edit-prompt.ts'

// =========================================================================
// Pure prompt-build + response-parse helpers for the one-shot Edit-with-AI
// flow (ADR-0003 phase 3). Keeps the spec-stuffing + AI-instruction wording
// in one testable place; the screen just calls these.
// =========================================================================

const BASE = 'You are the ODS Build Helper.'
const SPEC = '{"appName":"Demo","startPage":"home","pages":{"home":{"component":"page","title":"Home","content":[]}}}'
const INSTRUCTION = 'add a priority field with low/medium/high options'

describe('buildEditPrompt', () => {
  it('preserves the base system prompt unchanged at the top', () => {
    const { system } = buildEditPrompt(SPEC, INSTRUCTION, BASE)
    expect(system.startsWith(BASE)).toBe(true)
  })

  it('appends a one-shot directive to the system prompt', () => {
    const { system } = buildEditPrompt(SPEC, INSTRUCTION, BASE)
    // The directive should clearly tell the AI to return JSON only.
    expect(system.toLowerCase()).toMatch(/json/)
    expect(system.toLowerCase()).toMatch(/no commentary|no explanation|only|spec/)
  })

  it('embeds the current spec verbatim in the user message', () => {
    const { user } = buildEditPrompt(SPEC, INSTRUCTION, BASE)
    expect(user).toContain(SPEC)
  })

  it('embeds the instruction in the user message', () => {
    const { user } = buildEditPrompt(SPEC, INSTRUCTION, BASE)
    expect(user).toContain(INSTRUCTION)
  })

  it('handles empty base system prompt by still emitting the directive', () => {
    const { system } = buildEditPrompt(SPEC, INSTRUCTION, '')
    // Directive still present, even with no base.
    expect(system.toLowerCase()).toMatch(/json/)
  })

  it('does not crash on multi-line instructions', () => {
    const multi = 'add a priority field\nalso rename "title" to "headline"\nand add a deadline date'
    const { user } = buildEditPrompt(SPEC, multi, BASE)
    expect(user).toContain(multi)
  })
})

describe('extractJsonSpec', () => {
  it('returns input unchanged when already pure JSON', () => {
    const out = extractJsonSpec(SPEC)
    expect(out).toBe(SPEC)
  })

  it('strips ```json fences', () => {
    const wrapped = '```json\n' + SPEC + '\n```'
    expect(extractJsonSpec(wrapped)).toBe(SPEC)
  })

  it('strips bare ``` fences with no language tag', () => {
    const wrapped = '```\n' + SPEC + '\n```'
    expect(extractJsonSpec(wrapped)).toBe(SPEC)
  })

  it('strips leading/trailing whitespace + commentary outside the JSON block', () => {
    const wrapped =
      'Sure, here is the updated spec:\n\n```json\n' + SPEC + '\n```\n\nLet me know if you want any changes.'
    expect(extractJsonSpec(wrapped)).toBe(SPEC)
  })

  it('returns trimmed text when no fence is present', () => {
    const padded = '\n\n  ' + SPEC + '  \n\n'
    expect(extractJsonSpec(padded)).toBe(SPEC)
  })

  it('handles multi-line JSON inside fences', () => {
    const pretty = JSON.stringify(JSON.parse(SPEC), null, 2)
    const wrapped = '```json\n' + pretty + '\n```'
    expect(extractJsonSpec(wrapped)).toBe(pretty)
  })
})
