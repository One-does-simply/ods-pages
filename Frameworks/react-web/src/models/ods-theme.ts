/**
 * Theme + customizations for an ODS app.
 *
 * Per ADR-0002, this is the single concept builders learn for visual
 * style. A theme picks a base palette from the catalog; `overrides`
 * adjusts any token (color, font, header style, etc.) on top of it.
 *
 * App identity (logo/favicon/appName/appIcon) is NOT here — it lives
 * at the top level of `OdsApp` because it's "which app is this," not
 * visual style.
 */
export interface OdsTheme {
  /** Base theme name from the catalog (e.g., 'indigo', 'abyss'). */
  base: string

  /** Color scheme: light, dark, or system (follow OS preference). */
  mode: 'light' | 'dark' | 'system'

  /** App bar style. */
  headerStyle: 'solid' | 'light' | 'transparent'

  /**
   * Per-token overrides on top of the chosen base theme. Token names
   * follow the theme JSON's color keys (`primary`, `secondary`,
   * `base100`, etc.) and font keys (`fontSans`, `fontSerif`,
   * `fontMono`).
   */
  overrides?: Record<string, string>
}

/** Default theme used when a spec omits the theme block. */
export const DEFAULT_THEME: OdsTheme = {
  base: 'indigo',
  mode: 'system',
  headerStyle: 'light',
}

export function parseTheme(json: unknown): OdsTheme {
  if (json == null || typeof json !== 'object') return { ...DEFAULT_THEME }
  const j = json as Record<string, unknown>

  let base = (j['base'] as string) ?? 'indigo'
  // Legacy color-mode aliases that some hand-edited specs may carry.
  if (base === 'light') base = 'indigo'
  if (base === 'dark') base = 'slate'

  return {
    base,
    mode: (['light', 'dark', 'system'].includes(j['mode'] as string)
      ? (j['mode'] as 'light' | 'dark' | 'system')
      : 'system'),
    headerStyle: (['solid', 'light', 'transparent'].includes(j['headerStyle'] as string)
      ? (j['headerStyle'] as 'solid' | 'light' | 'transparent')
      : 'light'),
    overrides: j['overrides'] as Record<string, string> | undefined,
  }
}
