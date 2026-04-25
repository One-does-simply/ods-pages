import { describe, it, expect } from 'vitest'
import { parseTheme, DEFAULT_THEME } from '../../../src/models/ods-theme.ts'

// ===========================================================================
// OdsTheme model tests (ADR-0002)
// ===========================================================================

describe('parseTheme', () => {
  // -------------------------------------------------------------------------
  // Null / missing input
  // -------------------------------------------------------------------------

  it('returns defaults for null input', () => {
    const result = parseTheme(null)
    expect(result.base).toBe('indigo')
    expect(result.mode).toBe('system')
    expect(result.headerStyle).toBe('light')
  })

  it('returns defaults for undefined input', () => {
    const result = parseTheme(undefined)
    expect(result).toEqual(DEFAULT_THEME)
  })

  it('returns defaults for non-object input', () => {
    const result = parseTheme('not-an-object')
    expect(result.base).toBe('indigo')
    expect(result.mode).toBe('system')
  })

  it('returns defaults for number input', () => {
    const result = parseTheme(42)
    expect(result.base).toBe('indigo')
  })

  // -------------------------------------------------------------------------
  // Valid theme object
  // -------------------------------------------------------------------------

  it('parses a full valid theme object', () => {
    const result = parseTheme({
      base: 'nord',
      mode: 'dark',
      headerStyle: 'solid',
      overrides: {
        primary: 'oklch(50% 0.2 260)',
        fontSans: 'Inter',
      },
    })
    expect(result.base).toBe('nord')
    expect(result.mode).toBe('dark')
    expect(result.headerStyle).toBe('solid')
    expect(result.overrides?.primary).toBe('oklch(50% 0.2 260)')
    expect(result.overrides?.fontSans).toBe('Inter')
  })

  it('parses minimal theme with only base', () => {
    const result = parseTheme({ base: 'corporate' })
    expect(result.base).toBe('corporate')
    expect(result.mode).toBe('system')
    expect(result.headerStyle).toBe('light')
    expect(result.overrides).toBeUndefined()
  })

  // -------------------------------------------------------------------------
  // Default values
  // -------------------------------------------------------------------------

  it('defaults base to indigo', () => {
    expect(parseTheme({}).base).toBe('indigo')
  })

  it('defaults mode to system', () => {
    expect(parseTheme({}).mode).toBe('system')
  })

  it('defaults headerStyle to light', () => {
    expect(parseTheme({}).headerStyle).toBe('light')
  })

  it('falls back to system for invalid mode', () => {
    expect(parseTheme({ mode: 'invalid-mode' }).mode).toBe('system')
  })

  it('falls back to light for invalid headerStyle', () => {
    expect(parseTheme({ headerStyle: 'glowing' }).headerStyle).toBe('light')
  })

  // -------------------------------------------------------------------------
  // Color-mode aliases
  // -------------------------------------------------------------------------

  it('migrates legacy color-mode alias "light" → "indigo"', () => {
    expect(parseTheme({ base: 'light' }).base).toBe('indigo')
  })

  it('migrates legacy color-mode alias "dark" → "slate"', () => {
    expect(parseTheme({ base: 'dark' }).base).toBe('slate')
  })

  it('preserves valid theme names unchanged', () => {
    expect(parseTheme({ base: 'nord' }).base).toBe('nord')
  })

  // -------------------------------------------------------------------------
  // Mode values
  // -------------------------------------------------------------------------

  it('accepts mode light', () => {
    expect(parseTheme({ mode: 'light' }).mode).toBe('light')
  })

  it('accepts mode dark', () => {
    expect(parseTheme({ mode: 'dark' }).mode).toBe('dark')
  })

  it('accepts mode system', () => {
    expect(parseTheme({ mode: 'system' }).mode).toBe('system')
  })
})
