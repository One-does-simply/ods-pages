// ---------------------------------------------------------------------------
// theme-spec-writer — pure helper for the admin save-to-spec path.
//
// Given a raw spec JSON string and a desired theme + identity payload,
// returns the new spec JSON with `theme`, `logo`, `favicon` rewritten
// surgically. Unknown fields and the original formatting choices outside
// those three blocks are preserved.
//
// Extracted from SettingsDialog (ADR-0002 phase 3) so the round-trip
// semantics are unit-testable without rendering the dialog or mocking
// PocketBase. The persistence side-effect (registry.updateApp) stays in
// the dialog.
// ---------------------------------------------------------------------------

export interface SpecWriterParams {
  /** The new `theme.base` (e.g., 'nord', 'indigo'). */
  base: string
  /** Color/size token overrides written under `theme.overrides`. */
  tokenOverrides: Record<string, string>
  /** Top-level `logo` URL. Empty string removes the field. */
  logo: string
  /** Top-level `favicon` URL. Empty string removes the field. */
  favicon: string
  /** `theme.headerStyle`. 'light' is the default and is omitted from the spec. */
  headerStyle: 'light' | 'solid' | 'transparent'
  /** Folded into `theme.overrides.fontSans` when non-empty. */
  fontFamily: string
}

/**
 * Returns the updated spec JSON, or `null` if the input cannot be parsed.
 * Callers should treat null as a soft failure (log + skip the write).
 */
export function buildUpdatedSpecJson(
  rawSpecJson: string,
  params: SpecWriterParams,
): string | null {
  let spec: Record<string, unknown>
  try {
    spec = JSON.parse(rawSpecJson)
  } catch {
    return null
  }

  const themeBlock: Record<string, unknown> = { base: params.base }
  const existing = (spec['theme'] as Record<string, unknown> | undefined) ?? {}
  if (existing['mode']) themeBlock['mode'] = existing['mode']
  if (params.headerStyle !== 'light') themeBlock['headerStyle'] = params.headerStyle

  const tk: Record<string, string> = { ...params.tokenOverrides }
  if (params.fontFamily) tk['fontSans'] = params.fontFamily
  if (Object.keys(tk).length > 0) themeBlock['overrides'] = tk

  spec['theme'] = themeBlock

  if (params.logo) spec['logo'] = params.logo
  else delete spec['logo']
  if (params.favicon) spec['favicon'] = params.favicon
  else delete spec['favicon']

  return JSON.stringify(spec, null, 2)
}
