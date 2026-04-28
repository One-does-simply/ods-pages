// ---------------------------------------------------------------------------
// AI settings storage (ADR-0003 phase 2). Persists the user's chosen
// provider + API key + model to localStorage. The UI in
// AdminSettingsPage is a thin wrapper over these helpers; the
// EditWithAi flow reads via getAiSettings + isAiConfigured to decide
// whether to use the API or fall back to the copy/paste flow.
//
// v1: plaintext localStorage. OS-keychain integration tracked as a
// follow-up ADR (per ADR-0003 §6 "out of scope for v1").
// ---------------------------------------------------------------------------

export type AiProviderName = 'anthropic' | 'openai'

export interface AiSettings {
  /** null when AI is not configured. */
  provider: AiProviderName | null
  /** Empty string when not yet entered. Never logged or rendered un-masked. */
  apiKey: string
  /** Model id from the provider's curated list. Empty when not selected. */
  model: string
}

export const AI_SETTINGS_STORAGE_KEY = 'ods_ai_settings'

const EMPTY: AiSettings = { provider: null, apiKey: '', model: '' }

function isProvider(v: unknown): v is AiProviderName {
  return v === 'anthropic' || v === 'openai'
}

/** Read the persisted AI settings, or the empty default if missing /
 *  malformed / contains an unknown provider. Always returns a valid
 *  AiSettings — never throws. */
export function getAiSettings(): AiSettings {
  const raw = localStorage.getItem(AI_SETTINGS_STORAGE_KEY)
  if (raw == null) return { ...EMPTY }
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch {
    return { ...EMPTY }
  }
  if (typeof parsed !== 'object' || parsed === null) return { ...EMPTY }
  const p = parsed as Partial<AiSettings>
  return {
    provider: isProvider(p.provider) ? p.provider : null,
    apiKey: typeof p.apiKey === 'string' ? p.apiKey : '',
    model: typeof p.model === 'string' ? p.model : '',
  }
}

/** Persist the AI settings. Pass `clearAiSettings()` to reset. */
export function setAiSettings(settings: AiSettings): void {
  localStorage.setItem(AI_SETTINGS_STORAGE_KEY, JSON.stringify(settings))
}

/** Remove the persisted AI settings entirely. Subsequent getAiSettings
 *  calls return the empty default. */
export function clearAiSettings(): void {
  localStorage.removeItem(AI_SETTINGS_STORAGE_KEY)
}

/** True when the AI is fully configured (provider, key, and model all
 *  set). Used by the EditWithAi flow to switch between the in-app API
 *  path and the copy/paste fallback. */
export function isAiConfigured(s: AiSettings): boolean {
  return s.provider !== null && s.apiKey.length > 0 && s.model.length > 0
}
