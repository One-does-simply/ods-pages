# ADR-0002 — Theme + Customizations Redesign

**Status:** accepted (open questions resolved 2026-04-24)
**Date:** 2026-04-24
**Tracked in:** [TODO.md](../../TODO.md) — *Theme + Customizations redesign*

---

## 1. Context

ODS Pages today carries **two adjacent concepts** for visual style:

- **Theme** ([Specification/Themes/*.json](../../Specification/Themes/),
  [ods-branding.ts](../../Frameworks/react-web/src/models/ods-branding.ts))
  — a named palette with `light` and `dark` color variants and a
  `design` block (radius, sizes, border, depth).
- **Branding**
  ([OdsBranding](../../Frameworks/react-web/src/models/ods-branding.ts)) —
  per-app overrides on top of the theme: token colors, logo, favicon,
  header style, font family.

This split has accumulated over time and now causes three concrete
problems:

### 1.1 Builder confusion

Two boxes in the wizard ask similar-looking questions. *"Pick a theme"*
and *"Customize branding"* are not distinct enough that the user knows
when to do which. The boundary is invisible to anyone who didn't help
write it.

### 1.2 Fonts in the wrong place

Font family lives on `OdsBranding`, not on the theme. So a "theme"
can't carry typography — switching from Abyss (atmospheric) to Acid
(bold) gives you new colors but the same font. Real themes carry
typography; ours don't.

The font field is also a freeform text input
([SettingsDialog.tsx:461](../../Frameworks/react-web/src/screens/SettingsDialog.tsx#L461))
with placeholder *"e.g., Inter, Georgia"* — the user has to know font
names by heart and there's no preview.

### 1.3 Runtime customizations don't persist meaningfully

Two flows save customizations differently:

- **Wizard at create-time**
  ([QuickBuildScreen.tsx:315](../../Frameworks/react-web/src/screens/QuickBuildScreen.tsx#L315))
  bakes choices into the spec → permanent + portable.
- **Settings dialog at runtime**
  ([SettingsDialog.tsx:122](../../Frameworks/react-web/src/screens/SettingsDialog.tsx#L122))
  saves to `localStorage` under `ods_branding_<appName>` → per-browser,
  per-user-on-device, lost on cache clear, not shared with teammates.

For multi-user apps where an admin wants to set company branding once
and have all users see it, there's no path that doesn't involve hand-
editing the spec JSON.

---

## 2. Decision

### 2.1 Collapse to one concept

Drop `OdsBranding` as a distinct shape. Everything visual lives on
**theme + customizations** (one concept the builder learns):

```jsonc
{
  "theme": {
    "base": "abyss",                    // named theme from catalog
    "mode": "system",                   // light | dark | system
    "headerStyle": "light",             // moves here from branding
    "overrides": {                      // per-token overrides
      "primary": "#5B21B6",             // colors
      "fontSans": "Inter"               // fonts (new)
    }
  }
}
```

### 2.2 Move app identity out

`logo` and `favicon` aren't visual style — they're *which app is
this*. Lift them to the top level alongside the existing `appName` /
`appIcon` field:

```jsonc
{
  "appName": "Sales Tracker",
  "appIcon": "📊",        // already exists
  "logo": "...",          // moves out of branding
  "favicon": "..."        // moves out of branding
}
```

### 2.3 Fonts on theme + proper picker

Theme JSON files gain an optional `fonts` block:

```jsonc
{
  "name": "abyss",
  "design": { "radiusBox": ".5rem", ... },
  "fonts": {                        // new
    "sans": "Inter",
    "serif": "Source Serif",
    "mono": "JetBrains Mono"
  },
  "light": { "colors": { ... } }
}
```

Most catalog themes leave `fonts` unset (system default). A few
signature themes (e.g., business → professional grotesk; retro →
mono; abyss → atmospheric serif) ship with matching typography.
Customizations override theme fonts via
`theme.overrides.fontSans` etc. — same mechanism as colors.

The settings UI for fonts becomes a curated dropdown of system-safe
+ Google Fonts options with live previews. A "Custom..." escape
hatch keeps the freeform input available.

### 2.4 Persistence tier: admin → spec, user → localStorage

| Context                                         | Where customizations persist |
| ----------------------------------------------- | ---------------------------- |
| Single-user app                                 | Spec                         |
| Multi-user app, admin signed in                 | Spec (all users see)         |
| Multi-user app, regular user signed in          | localStorage (personal view) |
| Wizard at create-time                           | Spec (already does this)     |

Admin writes mutate the stored app spec via the existing data layer
(PocketBase on React, SQLite on Flutter). Regular-user writes use
the existing `ods_branding_<appName>` localStorage key (renamed to
`ods_theme_<appName>` for consistency).

---

## 3. Consequences

### Good

- **One concept for builders.** "Pick a theme, customize anything."
  No invisible boundary between two boxes.
- **Real theme capability.** Themes carry typography, not just color.
- **Admin branding works as expected.** Multi-user apps can have
  team-wide branding without anyone editing JSON by hand.
- **Font picker stops being awkward.** Curated list with previews
  matches modern editors.
- **Spec gets simpler.** One nested `theme` object replaces two
  competing top-level concepts.

### Bad

- **Spec rewrite cost.** All bundled examples (4) and templates (13)
  reference `branding`; each needs a hand-rewrite to use `theme`. No
  parser shim — the legacy shape is dropped entirely (we're pre-1.0,
  so no external specs to break). [ods-schema.json](../../Specification/ods-schema.json)
  and [Themes/README.md](../../Specification/Themes/README.md)
  also need updates.
- **Admin → spec write path is new code.** Today the spec is a
  read-only artifact at runtime. Adding a write path means new error
  handling (PocketBase 4xx, conflict, optimistic concurrency) and a
  test surface that doesn't exist yet.
- **Conformance scenario churn.** Any scenario that touches
  `branding` needs to be updated. Currently only the
  `OdsBranding` parser tests reference it directly, but the
  `appIcon` reorganization will ripple through.

### Neutral

- The `OdsTheme` JSON catalog files at
  [Specification/Themes/](../../Specification/Themes/) need an
  `fonts` field added (optional, defaults to nothing). Old theme
  files keep working.
- Localstorage key migrates from `ods_branding_*` to `ods_theme_*` —
  one-time read-and-rewrite on first load to avoid losing user
  customizations.

---

## 4. Alternatives considered

### 4.1 Keep two concepts, just add fonts to theme

What I originally proposed. Cheaper but doesn't fix the builder-
confusion problem — the wizard still has two boxes asking similar
questions, and the localStorage-only persistence gap stays open.

### 4.2 Collapse into "branding" (the other direction)

Drop `OdsTheme` as a name; make everything `OdsBranding`. Less
disruptive to existing code. Rejected because *"theme"* is the
better builder-facing word ("pick a theme" is more natural than
"pick a branding"), and the named-catalog concept is centered on
themes today.

### 4.3 Per-user theme switching as a first-class feature

Let any user pick from the theme catalog independently — admin sets
the company palette but Bob can switch his to dark Abyss. Rejected
for v1 of this redesign — adds complexity without a clear ask, and
the localStorage tier already supports it implicitly (a user who
overrides every token effectively switches themes).

### 4.4 Theme as a top-level reference, customizations as a sibling

```jsonc
{
  "theme": "abyss",
  "themeOverrides": { "primary": "#...", "fontSans": "Inter" }
}
```

Two adjacent fields rather than nested. Marginally more verbose to
read; nesting feels right because the customization is conceptually
"on top of" the chosen theme.

---

## 5. Resolved questions

Resolved 2026-04-24 before acceptance.

### 5.1 Role-specific themes? — **No.**

Not pursuing. If it ever becomes a real ask, fold into the broader
role-aware-config conversation rather than retrofitting onto
themes.

### 5.2 Theme preview while editing? — **Yes, keep live preview.**

Live-preview-while-editing is the better UX and we keep it. Concrete
shape: edits apply to the running app immediately (DOM only); the
"Save" action commits — to spec for admins, to localStorage for
regular users. Discarding (closing without save) reverts to the
last committed state.

### 5.3 Per-user dark mode toggle? — **`mode: 'system'` stays the recommended default.**

Mode follows OS preference by default. Per-user override stays
possible via localStorage (same tier as other regular-user
customizations). No special-casing needed — `mode` is just another
field in `theme` that follows the admin/user persistence rules.

### 5.4 Flutter parity? — **Identical contract, mirror-edit the implementation.**

Confirmed. Every model / parser / writer / UI change on the React
side gets a mirror-edit on the Flutter side. The conformance
scenario for theme customization runs against both drivers.

### 5.5 Migration shim? — **No shim. Drop legacy `branding` and rewrite all specs.**

Pre-1.0; no external specs to break; the in-repo specs are countable
(19 files: 4 examples, 13 templates, the JSON schema, the themes
README). Hand-rewriting them is faster than maintaining a parser
shim long-term and gives us cleaner code on day one. The wizard and
settings dialog stop emitting `branding` immediately.

---

## 6. Implementation sketch (informational, not part of the decision)

| Piece | Where | Size |
| ----- | ----- | ---- |
| New `OdsTheme` model with `overrides` field; drop `OdsBranding` | Both frameworks' models | ~1 day |
| Theme JSON schema gains `fonts`; update Themes README | Specification/Themes | ~half day |
| Update bundled themes that should ship with custom typography | Specification/Themes | ~few hours |
| Move `logo`/`favicon` to top-level `OdsApp` | Both frameworks' models | ~half day |
| Font picker UI (curated dropdown + custom escape hatch) | React only | small |
| Admin-saves-to-spec write path | Both frameworks | ~1 day each |
| Rewrite 4 examples + 13 templates to use `theme` block | Specification/Examples + Templates | ~half day |
| Update [ods-schema.json](../../Specification/ods-schema.json) | Specification | small |
| Conformance: theme-customization scenario | TS + Dart | ~half day |
| Update [spec.md](../../Frameworks/react-web/spec.md), README, GLOSSARY | Docs | small |

Total: ~3-4 sessions across both frameworks. Lands as a single
breaking spec change — no parser shim. Bumps to spec v0.2 (or
whatever versioning convention we land on first).
