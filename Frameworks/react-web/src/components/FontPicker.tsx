import { useState } from 'react'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

// ---------------------------------------------------------------------------
// FontPicker — curated dropdown of font choices with a Custom… escape hatch.
//
// Per ADR-0002, font selection used to be a freeform textbox where the user
// had to know font names by heart. This component replaces that with a
// curated list. System-safe fonts always work; the listed Google Fonts get
// loaded on-demand via an injected <link> tag the first time the user picks
// them. "Custom…" reveals the freeform input for power users.
// ---------------------------------------------------------------------------

const SYSTEM_FONT_VALUE = '__system__'
const CUSTOM_FONT_VALUE = '__custom__'

interface FontOption {
  /** Display label shown in the dropdown. */
  label: string
  /** Value passed to the consumer (the actual font-family name). */
  value: string
  /** CSS family list to use for the live preview in the menu. */
  preview: string
  /** When set, lazy-load this Google Fonts URL on first selection. */
  googleFontsUrl?: string
}

const SYSTEM_FONTS: FontOption[] = [
  { label: 'System default', value: SYSTEM_FONT_VALUE, preview: 'system-ui, sans-serif' },
  { label: 'Georgia', value: 'Georgia', preview: '"Georgia", serif' },
  { label: 'Times New Roman', value: 'Times New Roman', preview: '"Times New Roman", serif' },
  { label: 'Courier New', value: 'Courier New', preview: '"Courier New", monospace' },
  { label: 'Verdana', value: 'Verdana', preview: '"Verdana", sans-serif' },
  { label: 'Tahoma', value: 'Tahoma', preview: '"Tahoma", sans-serif' },
  { label: 'Trebuchet MS', value: 'Trebuchet MS', preview: '"Trebuchet MS", sans-serif' },
]

const GOOGLE_FONTS: FontOption[] = [
  { label: 'Inter', value: 'Inter', preview: '"Inter", sans-serif',
    googleFontsUrl: 'https://fonts.googleapis.com/css2?family=Inter:wght@400;600&display=swap' },
  { label: 'Roboto', value: 'Roboto', preview: '"Roboto", sans-serif',
    googleFontsUrl: 'https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap' },
  { label: 'Open Sans', value: 'Open Sans', preview: '"Open Sans", sans-serif',
    googleFontsUrl: 'https://fonts.googleapis.com/css2?family=Open+Sans:wght@400;700&display=swap' },
  { label: 'Lato', value: 'Lato', preview: '"Lato", sans-serif',
    googleFontsUrl: 'https://fonts.googleapis.com/css2?family=Lato:wght@400;700&display=swap' },
  { label: 'Source Serif 4', value: 'Source Serif 4', preview: '"Source Serif 4", serif',
    googleFontsUrl: 'https://fonts.googleapis.com/css2?family=Source+Serif+4:wght@400;700&display=swap' },
  { label: 'Playfair Display', value: 'Playfair Display', preview: '"Playfair Display", serif',
    googleFontsUrl: 'https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&display=swap' },
  { label: 'Merriweather', value: 'Merriweather', preview: '"Merriweather", serif',
    googleFontsUrl: 'https://fonts.googleapis.com/css2?family=Merriweather:wght@400;700&display=swap' },
  { label: 'JetBrains Mono', value: 'JetBrains Mono', preview: '"JetBrains Mono", monospace',
    googleFontsUrl: 'https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap' },
]

const ALL_OPTIONS = [...SYSTEM_FONTS, ...GOOGLE_FONTS]

/** Inject the Google Fonts <link> tag for a font, idempotent. */
function ensureGoogleFontLoaded(option: FontOption): void {
  if (!option.googleFontsUrl) return
  const id = `google-font-${option.value.replace(/\s+/g, '-').toLowerCase()}`
  if (document.getElementById(id)) return
  const link = document.createElement('link')
  link.id = id
  link.rel = 'stylesheet'
  link.href = option.googleFontsUrl
  document.head.appendChild(link)
}

export function FontPicker({
  value,
  onChange,
  label = 'Font',
}: {
  /** Current font family. Empty string = system default. */
  value: string
  onChange: (value: string) => void
  label?: string
}) {
  // Match the current value to a known option, else show as Custom.
  const matched = ALL_OPTIONS.find((o) => o.value === value)
  const isCustom = value !== '' && !matched && value !== SYSTEM_FONT_VALUE
  const initialDropdown = value === '' ? SYSTEM_FONT_VALUE : matched ? value : CUSTOM_FONT_VALUE

  const [dropdownValue, setDropdownValue] = useState<string>(initialDropdown)
  const [customValue, setCustomValue] = useState<string>(isCustom ? value : '')

  function handleDropdownChange(raw: string | null) {
    const next = raw ?? SYSTEM_FONT_VALUE
    setDropdownValue(next)
    if (next === SYSTEM_FONT_VALUE) {
      onChange('')
    } else if (next === CUSTOM_FONT_VALUE) {
      // Don't emit yet — wait for the input to receive a value.
      onChange(customValue)
    } else {
      const opt = ALL_OPTIONS.find((o) => o.value === next)
      if (opt) ensureGoogleFontLoaded(opt)
      onChange(next)
    }
  }

  function handleCustomChange(next: string) {
    setCustomValue(next)
    onChange(next)
  }

  return (
    <div className="space-y-1">
      <Label className="text-xs">{label}</Label>
      <Select value={dropdownValue} onValueChange={handleDropdownChange}>
        <SelectTrigger className="h-8 text-xs">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {SYSTEM_FONTS.map((o) => (
            <SelectItem key={o.value} value={o.value}>
              <span style={{ fontFamily: o.preview }}>{o.label}</span>
            </SelectItem>
          ))}
          <SelectItem value={CUSTOM_FONT_VALUE}>Custom…</SelectItem>
          {GOOGLE_FONTS.map((o) => (
            <SelectItem key={o.value} value={o.value}>
              <span style={{ fontFamily: o.preview }}>{o.label}</span>
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      {dropdownValue === CUSTOM_FONT_VALUE && (
        <Input
          value={customValue}
          onChange={(e) => handleCustomChange(e.target.value)}
          placeholder="e.g., Inter, Comic Sans MS"
          className="h-8 text-xs"
        />
      )}
    </div>
  )
}
