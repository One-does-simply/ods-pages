import { describe, it, expect } from 'vitest'
import { buildUpdatedSpecJson } from '@/engine/theme-spec-writer.ts'

// =========================================================================
// Pure helper extracted from SettingsDialog's admin save-to-spec path
// (ADR-0002 phase 3). Keeping this pure makes the round-trip semantics
// — what gets written, what gets dropped, what gets preserved —
// testable without rendering the dialog or mocking PocketBase.
// =========================================================================

function baseSpec(): Record<string, unknown> {
  return {
    appName: 'Spec Writer Probe',
    startPage: 'home',
    theme: { base: 'indigo', mode: 'system' },
    pages: { home: { component: 'page', title: 'Home', content: [] } },
    dataSources: {},
  }
}

function defaults() {
  return {
    base: 'nord',
    tokenOverrides: {} as Record<string, string>,
    logo: '',
    favicon: '',
    headerStyle: 'light' as const,
    fontFamily: '',
  }
}

describe('buildUpdatedSpecJson — theme block', () => {
  it('writes the new theme.base', () => {
    const out = buildUpdatedSpecJson(JSON.stringify(baseSpec()), { ...defaults(), base: 'nord' })
    const parsed = JSON.parse(out!)
    expect(parsed.theme.base).toBe('nord')
  })

  it('preserves theme.mode from the existing spec', () => {
    const out = buildUpdatedSpecJson(JSON.stringify(baseSpec()), defaults())
    const parsed = JSON.parse(out!)
    expect(parsed.theme.mode).toBe('system')
  })

  it('omits headerStyle when it is the default ("light")', () => {
    const out = buildUpdatedSpecJson(JSON.stringify(baseSpec()), { ...defaults(), headerStyle: 'light' })
    const parsed = JSON.parse(out!)
    expect(parsed.theme.headerStyle).toBeUndefined()
  })

  it('writes headerStyle when non-default', () => {
    const out = buildUpdatedSpecJson(JSON.stringify(baseSpec()), { ...defaults(), headerStyle: 'solid' })
    const parsed = JSON.parse(out!)
    expect(parsed.theme.headerStyle).toBe('solid')
  })

  it('writes token overrides under theme.overrides', () => {
    const out = buildUpdatedSpecJson(JSON.stringify(baseSpec()), {
      ...defaults(),
      tokenOverrides: { primary: 'oklch(50% 0.2 260)' },
    })
    const parsed = JSON.parse(out!)
    expect(parsed.theme.overrides.primary).toBe('oklch(50% 0.2 260)')
  })

  it('folds fontFamily into theme.overrides.fontSans', () => {
    const out = buildUpdatedSpecJson(JSON.stringify(baseSpec()), {
      ...defaults(),
      fontFamily: 'Inter',
    })
    const parsed = JSON.parse(out!)
    expect(parsed.theme.overrides.fontSans).toBe('Inter')
  })

  it('omits theme.overrides when there are no tokens or font', () => {
    const out = buildUpdatedSpecJson(JSON.stringify(baseSpec()), defaults())
    const parsed = JSON.parse(out!)
    expect(parsed.theme.overrides).toBeUndefined()
  })
})

describe('buildUpdatedSpecJson — top-level identity fields', () => {
  it('writes logo when non-empty', () => {
    const out = buildUpdatedSpecJson(JSON.stringify(baseSpec()), {
      ...defaults(),
      logo: 'https://example.com/logo.png',
    })
    const parsed = JSON.parse(out!)
    expect(parsed.logo).toBe('https://example.com/logo.png')
  })

  it('removes logo when empty string', () => {
    const start = { ...baseSpec(), logo: 'https://example.com/old.png' }
    const out = buildUpdatedSpecJson(JSON.stringify(start), { ...defaults(), logo: '' })
    const parsed = JSON.parse(out!)
    expect(parsed.logo).toBeUndefined()
  })

  it('writes favicon when non-empty', () => {
    const out = buildUpdatedSpecJson(JSON.stringify(baseSpec()), {
      ...defaults(),
      favicon: 'https://example.com/favicon.ico',
    })
    const parsed = JSON.parse(out!)
    expect(parsed.favicon).toBe('https://example.com/favicon.ico')
  })

  it('removes favicon when empty string', () => {
    const start = { ...baseSpec(), favicon: 'https://example.com/old.ico' }
    const out = buildUpdatedSpecJson(JSON.stringify(start), { ...defaults(), favicon: '' })
    const parsed = JSON.parse(out!)
    expect(parsed.favicon).toBeUndefined()
  })
})

describe('buildUpdatedSpecJson — preservation', () => {
  it('preserves unrelated top-level fields (appName, pages, dataSources)', () => {
    const out = buildUpdatedSpecJson(JSON.stringify(baseSpec()), { ...defaults(), base: 'abyss' })
    const parsed = JSON.parse(out!)
    expect(parsed.appName).toBe('Spec Writer Probe')
    expect(parsed.startPage).toBe('home')
    expect(parsed.pages.home.title).toBe('Home')
  })

  it('preserves unknown spec fields the parser would otherwise strip', () => {
    const start = { ...baseSpec(), customField: { future: 'value' } }
    const out = buildUpdatedSpecJson(JSON.stringify(start), defaults())
    const parsed = JSON.parse(out!)
    expect(parsed.customField).toEqual({ future: 'value' })
  })
})

describe('buildUpdatedSpecJson — error handling', () => {
  it('returns null on invalid JSON', () => {
    expect(buildUpdatedSpecJson('not valid json', defaults())).toBeNull()
  })
})
