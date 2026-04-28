import { describe, it, expect, beforeEach } from 'vitest'
import {
  getAiSettings,
  setAiSettings,
  clearAiSettings,
  isAiConfigured,
  AI_SETTINGS_STORAGE_KEY,
} from '@/engine/ai-settings.ts'

// =========================================================================
// AI settings storage layer (ADR-0003 phase 2). Pure data layer over
// localStorage; the UI in AdminSettingsPage is a thin wrapper.
// =========================================================================

beforeEach(() => {
  localStorage.removeItem(AI_SETTINGS_STORAGE_KEY)
})

describe('getAiSettings — defaults + parse', () => {
  it('returns the empty default when nothing is stored', () => {
    const s = getAiSettings()
    expect(s.provider).toBe(null)
    expect(s.apiKey).toBe('')
    expect(s.model).toBe('')
  })

  it('falls back to defaults when storage holds invalid JSON', () => {
    localStorage.setItem(AI_SETTINGS_STORAGE_KEY, 'not-json{')
    const s = getAiSettings()
    expect(s.provider).toBe(null)
    expect(s.apiKey).toBe('')
  })

  it('falls back to defaults when storage holds an unknown provider', () => {
    localStorage.setItem(
      AI_SETTINGS_STORAGE_KEY,
      JSON.stringify({ provider: 'cohere', apiKey: 'x', model: 'y' }),
    )
    const s = getAiSettings()
    expect(s.provider).toBe(null)
  })
})

describe('setAiSettings — persistence', () => {
  it('round-trips a configured Anthropic profile', () => {
    setAiSettings({
      provider: 'anthropic',
      apiKey: 'sk-ant-roundtrip',
      model: 'claude-sonnet-4-6',
    })
    const s = getAiSettings()
    expect(s.provider).toBe('anthropic')
    expect(s.apiKey).toBe('sk-ant-roundtrip')
    expect(s.model).toBe('claude-sonnet-4-6')
  })

  it('round-trips a configured OpenAI profile', () => {
    setAiSettings({
      provider: 'openai',
      apiKey: 'sk-openai-roundtrip',
      model: 'gpt-4o-mini',
    })
    const s = getAiSettings()
    expect(s.provider).toBe('openai')
    expect(s.model).toBe('gpt-4o-mini')
  })

  it('overwrites previous settings', () => {
    setAiSettings({ provider: 'anthropic', apiKey: 'a', model: 'claude-sonnet-4-6' })
    setAiSettings({ provider: 'openai', apiKey: 'b', model: 'gpt-4o' })
    expect(getAiSettings().provider).toBe('openai')
    expect(getAiSettings().apiKey).toBe('b')
  })
})

describe('clearAiSettings', () => {
  it('removes the stored entry so getAiSettings returns defaults', () => {
    setAiSettings({ provider: 'anthropic', apiKey: 'x', model: 'claude-haiku-4-5' })
    clearAiSettings()
    expect(getAiSettings().provider).toBe(null)
    expect(getAiSettings().apiKey).toBe('')
  })

  it('is a no-op when nothing is stored', () => {
    expect(() => clearAiSettings()).not.toThrow()
    expect(getAiSettings().provider).toBe(null)
  })
})

describe('isAiConfigured', () => {
  it('false when provider is null', () => {
    expect(isAiConfigured(getAiSettings())).toBe(false)
  })

  it('false when provider is set but apiKey is empty', () => {
    setAiSettings({ provider: 'anthropic', apiKey: '', model: 'claude-sonnet-4-6' })
    expect(isAiConfigured(getAiSettings())).toBe(false)
  })

  it('false when provider + key set but model is empty', () => {
    setAiSettings({ provider: 'anthropic', apiKey: 'sk-ant-x', model: '' })
    expect(isAiConfigured(getAiSettings())).toBe(false)
  })

  it('true when provider, apiKey, and model are all set', () => {
    setAiSettings({ provider: 'anthropic', apiKey: 'sk-ant-x', model: 'claude-sonnet-4-6' })
    expect(isAiConfigured(getAiSettings())).toBe(true)
  })
})
