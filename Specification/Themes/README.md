# ODS Theme Catalog

ODS ships 35 named themes that any ODS app can use via `branding.theme` in the spec. Each theme defines a complete color palette, design tokens, and both light and dark mode variants.

```json
{
  "branding": {
    "theme": "nord",
    "mode": "system"
  }
}
```

## Available Themes

| Theme | Native Scheme | Tags | Description |
|-------|--------------|------|-------------|
| **Indigo** (default) | light | minimal, default | Deep indigo primary with hot pink secondary and teal accent on pure white bases |
| **Slate** | dark | minimal, default | Indigo primary with blue-tinted slate bases |
| Cupcake | light | cute, playful | Soft pinks and pastels |
| Bumblebee | light | warm, yellow | Bold yellow and amber tones |
| Emerald | light | green, nature | Rich green primary |
| Corporate | light | professional, clean | Muted blue, professional look |
| Synthwave | dark | retro, neon, 80s | Neon pink on dark purple |
| Retro | light | vintage, warm | Warm earth tones with a vintage feel |
| Cyberpunk | light | futuristic, bold | Vivid yellow and magenta |
| Valentine | light | pink, romantic | Pink and rose tones |
| Halloween | dark | spooky, orange | Orange and black |
| Garden | light | floral, nature | Soft greens and pinks |
| Forest | dark | green, nature | Deep greens on dark background |
| Aqua | dark | ocean, blue | Ocean blues and teals |
| Lo-Fi | light | minimal, monochrome | High-contrast black and white |
| Pastel | light | soft, light | Soft pastel colors |
| Fantasy | light | magical, purple | Purple and gold |
| Wireframe | light | minimal, prototype | Grayscale, no-nonsense |
| Black | dark | minimal, monochrome | Pure black background |
| Luxury | dark | elegant, gold | Gold accents on dark |
| Dracula | dark | popular, purple | The popular Dracula color scheme |
| CMYK | light | colorful, print | Bold print-inspired colors |
| Autumn | light | warm, seasonal | Warm oranges and browns |
| Business | dark | professional, corporate | Professional dark theme |
| Acid | light | bold, vibrant | High-saturation neon green |
| Lemonade | light | fresh, green | Fresh greens and yellows |
| Night | dark | blue, deep | Deep blue tones |
| Coffee | dark | warm, brown | Rich coffee and chocolate |
| Winter | light | cool, blue | Cool blues and whites |
| Dim | dark | muted, subtle | Muted dark palette |
| Nord | light | cool, scandinavian | The popular Nord color scheme |
| Sunset | dark | warm, orange | Warm sunset gradients |
| Caramel Latte | light | warm, cozy | Warm caramel and cream |
| Abyss | dark | deep, ocean | Deep ocean blues |
| Silk | light | elegant, minimal | Refined, silky tones |

## Why Not DaisyUI Directly?

ODS themes are *derived from* the [DaisyUI](https://daisyui.com/) theme collection, but they are not used directly. There are three reasons:

### 1. Accessibility compliance

The original DaisyUI themes prioritize visual aesthetics, which sometimes comes at the cost of text readability. We audited every theme's color/content pairs against the [WCAG AA contrast standard](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html) (minimum 4.5:1 ratio for normal text) and found **79 failures across 40 themes**.

The worst offenders included pastel (7 failures), valentine (6), retro (5), bumblebee (5), and the original "dark" theme (4). Most failures were in the `primary`/`primaryContent` pair, where the text color intended to sit on top of a primary-colored button was too close in luminance to be readable.

We fixed every failure by adjusting the OKLCH lightness of the `*Content` color (the text that sits on top of the colored element) until it met a 4.6:1 ratio (slightly above the 4.5:1 minimum for safety margin). Hue and chroma were preserved so the color tint stays consistent with the theme's design intent.

**All 35 ODS themes now pass WCAG AA for every color/content pair in both light and dark modes.**

The five audited pairs per mode are:

| Background Color | Text Color | Where It Appears |
|-----------------|------------|-----------------|
| `primary` | `primaryContent` | Text on primary buttons, links |
| `secondary` | `secondaryContent` | Text on secondary buttons, tags |
| `accent` | `accentContent` | Text on accent elements, badges |
| `base100` | `baseContent` | Body text on page background |
| `error` | `errorContent` | Error message text |

### 2. Framework independence

DaisyUI is a Tailwind CSS plugin. ODS is framework-agnostic — the same theme must work in Flutter (which has no CSS), React, and any future framework. By extracting themes into standalone JSON files with OKLCH color values, any framework can resolve the tokens into its native theming system:

- **Flutter** converts OKLCH to Flutter `Color` objects via OKLab/linear sRGB math
- **React** maps tokens to CSS custom properties (bridging DaisyUI tokens to shadcn/ui variables)
- **Future frameworks** can implement their own resolver with no CSS dependency

### 3. Dual-mode guarantee

Every ODS theme ships with both a `light` and `dark` variant, regardless of its `nativeScheme`. DaisyUI themes only define one mode (whichever they were designed for). ODS auto-generates the missing mode by flipping base colors and adjusting primary lightness, then audits both modes for contrast compliance. This means `branding.mode: "system"` always works with every theme.

## Theme Architecture

### File Structure

Each theme is a JSON file in `Specification/Themes/`:

```
Themes/
  catalog.json        # Index of all themes with metadata
  indigo.json         # Default light theme
  slate.json          # Default dark theme
  nord.json
  dracula.json
  ...
```

### Theme File Format

```json
{
  "name": "indigo",
  "displayName": "Indigo",
  "author": "daisyui",
  "nativeScheme": "light",
  "design": {
    "radiusSelector": ".5rem",
    "radiusField": ".25rem",
    "radiusBox": ".5rem",
    "sizeSelector": ".25rem",
    "sizeField": ".25rem",
    "border": "1px",
    "depth": 1,
    "noise": 0
  },
  "light": {
    "colorScheme": "light",
    "colors": {
      "primary": "oklch(45% .24 277)",
      "primaryContent": "oklch(93% .034 273)",
      "secondary": "oklch(65% .241 354)",
      "secondaryContent": "oklch(23% .028 342)",
      "accent": "oklch(77% .152 182)",
      "accentContent": "oklch(38% .063 188)",
      "neutral": "oklch(14% .005 286)",
      "neutralContent": "oklch(92% .004 286)",
      "base100": "oklch(100% 0 0)",
      "base200": "oklch(98% 0 0)",
      "base300": "oklch(95% 0 0)",
      "baseContent": "oklch(21% .006 286)",
      "info": "oklch(74% .16 233)",
      "infoContent": "oklch(29% .066 243)",
      "success": "oklch(76% .177 163)",
      "successContent": "oklch(37% .077 169)",
      "warning": "oklch(82% .189 84)",
      "warningContent": "oklch(41% .112 46)",
      "error": "oklch(71% .194 13)",
      "errorContent": "oklch(27% .105 12)"
    }
  },
  "dark": {
    "colorScheme": "dark",
    "colors": { "..." : "same structure with dark-mode values" }
  }
}
```

### Color Tokens

Colors are organized in **pairs** — a background color and the text/content color designed to sit on top of it:

| Token | Content Token | Purpose |
|-------|--------------|---------|
| `primary` | `primaryContent` | Main action color (buttons, links, active states) |
| `secondary` | `secondaryContent` | Supporting actions (secondary buttons, tags) |
| `accent` | `accentContent` | Highlights (badges, notifications, emphasis) |
| `neutral` | `neutralContent` | Neutral elements (borders, subtle backgrounds) |
| `base100` | `baseContent` | Page background and body text |
| `base200` | — | Slightly darker background (cards, sidebars) |
| `base300` | — | Borders, dividers, input outlines |
| `info` | `infoContent` | Informational messages |
| `success` | `successContent` | Success states |
| `warning` | `warningContent` | Warning states |
| `error` | `errorContent` | Error states |

### OKLCH Color Space

All colors use the **OKLCH** format: `oklch(L% C H)` where:
- **L** (Lightness): 0% = black, 100% = white
- **C** (Chroma): 0 = gray, higher = more saturated
- **H** (Hue): 0-360 degree color wheel (0=red, 120=green, 240=blue)

OKLCH is perceptually uniform — equal steps in L produce equal perceived brightness changes. This makes contrast calculations reliable and color adjustments predictable. It's the same color space used by modern CSS (`oklch()` is supported in all major browsers).

### Design Tokens

The `design` object controls non-color visual properties:

| Token | Purpose | Example |
|-------|---------|---------|
| `radiusSelector` | Border radius for buttons, tabs | `.5rem` |
| `radiusField` | Border radius for input fields | `.25rem` |
| `radiusBox` | Border radius for cards, containers | `.5rem` |
| `sizeSelector` | Padding/spacing for selectable elements | `.25rem` |
| `sizeField` | Padding/spacing for input fields | `.25rem` |
| `border` | Default border width | `1px` |
| `depth` | Shadow depth (0 = flat, 1 = subtle, 2 = raised) | `1` |
| `noise` | Background texture (0 = none, 1 = subtle grain) | `0` |

## Creating a Custom Theme

We encourage you to create and share new themes! Here's how:

### Step 1: Start from a Template

The easiest approach is to copy an existing theme and modify it. Pick a theme close to what you want:

```bash
cp indigo.json my-theme.json
```

### Step 2: Define Your Colors

Edit the color values in both `light` and `dark` sections. You can use any OKLCH color tool to pick colors:

- [OKLCH Color Picker](https://oklch.com/) — interactive picker with CSS output
- Browser DevTools — modern browsers support `oklch()` in the color picker

**Start with `primary`** — it's the most visible color (buttons, links, active states). Then work outward:

```json
{
  "name": "ocean",
  "displayName": "Ocean",
  "author": "your-name",
  "nativeScheme": "light",
  "design": {
    "radiusSelector": ".5rem",
    "radiusField": ".25rem",
    "radiusBox": ".75rem",
    "sizeSelector": ".25rem",
    "sizeField": ".25rem",
    "border": "1px",
    "depth": 1,
    "noise": 0
  },
  "light": {
    "colorScheme": "light",
    "colors": {
      "primary": "oklch(50% .18 230)",
      "primaryContent": "oklch(95% .02 230)",
      "secondary": "oklch(60% .15 180)",
      "secondaryContent": "oklch(20% .03 180)",
      "accent": "oklch(75% .12 160)",
      "accentContent": "oklch(25% .03 160)",
      "neutral": "oklch(20% .01 230)",
      "neutralContent": "oklch(85% .01 230)",
      "base100": "oklch(99% .005 230)",
      "base200": "oklch(96% .008 230)",
      "base300": "oklch(92% .01 230)",
      "baseContent": "oklch(20% .02 230)",
      "info": "oklch(74% .16 233)",
      "infoContent": "oklch(29% .066 243)",
      "success": "oklch(76% .177 163)",
      "successContent": "oklch(37% .077 169)",
      "warning": "oklch(82% .189 84)",
      "warningContent": "oklch(41% .112 46)",
      "error": "oklch(71% .194 13)",
      "errorContent": "oklch(27% .105 12)"
    }
  },
  "dark": {
    "colorScheme": "dark",
    "colors": {
      "primary": "oklch(65% .18 230)",
      "primaryContent": "oklch(20% .03 230)",
      "...": "define all tokens for dark mode"
    }
  }
}
```

### Step 3: Check Contrast Compliance

Every `*Content` color must have a contrast ratio of **at least 4.5:1** against its paired background color. This is a hard requirement — ODS themes must be accessible.

**Quick rule of thumb:** If the background is dark (L < 50%), the content should be light (L > 80%). If the background is light (L > 50%), the content should be dark (L < 30%).

You can verify contrast with:
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- The ODS Quick Build wizard (which shows contrast warnings in the color picker)
- Run the audit script: `python scripts/check_contrast.py` from the Specification directory. Use `--fix` to auto-correct failing pairs.

The five pairs that must pass WCAG AA (4.5:1) in **both** light and dark modes:

| Must Pass | Background | Text |
|-----------|-----------|------|
| 1 | `primary` | `primaryContent` |
| 2 | `secondary` | `secondaryContent` |
| 3 | `accent` | `accentContent` |
| 4 | `base100` | `baseContent` |
| 5 | `error` | `errorContent` |

### Step 4: Create Both Modes

Every theme must have both a `light` and `dark` object. Tips for creating the opposite mode:

- **Flip bases:** Light mode `base100` is near-white (L ~98-100%); dark mode is near-black (L ~20-28%). Keep the same hue and low chroma for tinted backgrounds.
- **Adjust primary lightness:** Increase L by ~10-15% for dark mode so it stands out against dark backgrounds.
- **Flip content colors:** Content that was dark (for light backgrounds) becomes light (for dark backgrounds).
- **Keep info/success/warning/error** the same in both modes if they already have good contrast with their content colors in both contexts.

Set `nativeScheme` to whichever mode you designed first (`"light"` or `"dark"`).

### Step 5: Register in the Catalog

Add your theme to `catalog.json`:

```json
{
  "name": "ocean",
  "displayName": "Ocean",
  "file": "ocean.json",
  "nativeScheme": "light",
  "tags": ["cool", "blue", "nature"]
}
```

### Step 6: Test It

1. **Quick Build wizard:** Create an app with your theme and check the preview
2. **Existing app:** Change an app's `branding.theme` to your theme name
3. **Both modes:** Toggle between light and dark mode to verify both variants

### Contributing a Theme

We'd love to include community themes in the catalog! To contribute:

1. Follow the steps above to create your theme
2. Ensure all contrast pairs pass WCAG AA (4.5:1) in both modes
3. Submit a pull request adding your theme file and catalog entry
4. Include a brief description of the color palette's inspiration

## Per-Token Overrides

If you like a theme but want to tweak a few colors, you don't need to create a whole new theme. Use `branding.overrides`:

```json
{
  "branding": {
    "theme": "nord",
    "overrides": {
      "primary": "oklch(55% .20 250)",
      "primaryContent": "oklch(95% .02 250)"
    }
  }
}
```

Overrides are applied on top of the selected theme. Only the tokens you specify are changed; everything else comes from the theme. This is the recommended approach for brand-color matching without maintaining a full custom theme.

**Important:** If you override a color, also override its content pair to maintain contrast compliance.
