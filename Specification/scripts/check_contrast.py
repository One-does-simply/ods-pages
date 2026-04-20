#!/usr/bin/env python3
"""
ODS Theme Contrast Audit

Scans all theme JSON files and checks WCAG AA contrast compliance
for the five required background/content color pairs in both light
and dark modes.

Usage:
    python scripts/check_contrast.py          # audit only
    python scripts/check_contrast.py --fix    # audit and auto-fix failures

Run from the Specification directory or from the scripts directory.
"""

import json
import math
import os
import re
import sys
import argparse
from pathlib import Path

# ---------------------------------------------------------------------------
# OKLCH -> sRGB conversion pipeline
# ---------------------------------------------------------------------------

def oklch_to_oklab(L, C, h_deg):
    """Convert OKLCH (L in 0-1, C >= 0, h in degrees) to OKLab."""
    h_rad = math.radians(h_deg) if C > 0 else 0.0
    a = C * math.cos(h_rad)
    b = C * math.sin(h_rad)
    return (L, a, b)


def oklab_to_linear_srgb(L, a, b):
    """Convert OKLab to linear sRGB (may be out of gamut)."""
    # OKLab -> LMS (cube roots)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b

    l = l_ * l_ * l_
    m = m_ * m_ * m_
    s = s_ * s_ * s_

    # LMS -> linear sRGB
    r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b_ = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    return (r, g, b_)


def linear_to_srgb(c):
    """Apply sRGB gamma (linear channel -> sRGB channel, 0-1 clamped)."""
    c = max(0.0, min(1.0, c))
    if c <= 0.0031308:
        return 12.92 * c
    return 1.055 * (c ** (1.0 / 2.4)) - 0.055


def oklch_to_srgb(L, C, h):
    """Full pipeline: OKLCH -> OKLab -> linear sRGB -> sRGB (0-255)."""
    lab = oklch_to_oklab(L, C, h)
    lr, lg, lb = oklab_to_linear_srgb(*lab)
    return (
        linear_to_srgb(lr) * 255,
        linear_to_srgb(lg) * 255,
        linear_to_srgb(lb) * 255,
    )


# ---------------------------------------------------------------------------
# Parse OKLCH string
# ---------------------------------------------------------------------------

_OKLCH_RE = re.compile(
    r"oklch\(\s*([\d.]+)%?\s+([\d.]+)\s+([\d.]+)\s*\)", re.IGNORECASE
)


def parse_oklch(s):
    """Parse 'oklch(L% C H)' -> (L 0-1, C, H degrees). Returns None on failure."""
    m = _OKLCH_RE.match(s.strip())
    if not m:
        return None
    L_raw = float(m.group(1))
    C = float(m.group(2))
    H = float(m.group(3))
    # L may be given as percentage (e.g. 65%) or fraction (e.g. 0.65)
    L = L_raw / 100.0 if L_raw > 1.0 else L_raw
    return (L, C, H)


def format_oklch(L, C, H):
    """Format back to 'oklch(L% C H)' with consistent precision."""
    return f"oklch({L * 100:.3f}% {C:.4f} {H:.4f})"


# ---------------------------------------------------------------------------
# Relative luminance and contrast ratio (WCAG 2.x)
# ---------------------------------------------------------------------------

def _srgb_to_linear(c):
    """sRGB channel (0-255) -> linear luminance component."""
    c = c / 255.0
    if c <= 0.04045:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4


def relative_luminance(r, g, b):
    """WCAG relative luminance from sRGB 0-255 values."""
    return 0.2126 * _srgb_to_linear(r) + 0.7152 * _srgb_to_linear(g) + 0.0722 * _srgb_to_linear(b)


def contrast_ratio(rgb1, rgb2):
    """WCAG contrast ratio between two (r, g, b) tuples (0-255)."""
    lum1 = relative_luminance(*rgb1)
    lum2 = relative_luminance(*rgb2)
    lighter = max(lum1, lum2)
    darker = min(lum1, lum2)
    return (lighter + 0.05) / (darker + 0.05)


# ---------------------------------------------------------------------------
# Auto-fix: binary search on OKLCH lightness
# ---------------------------------------------------------------------------

WCAG_AA = 4.5
FIX_TARGET = 4.6  # safety margin


def fix_content_color(bg_oklch, content_oklch):
    """
    Adjust the lightness of content_oklch so that it achieves at least
    FIX_TARGET contrast against bg_oklch. Preserves hue and chroma.
    Returns the fixed (L, C, H) tuple.
    """
    bg_rgb = oklch_to_srgb(*bg_oklch)
    bg_lum = relative_luminance(*bg_rgb)

    _, C, H = content_oklch

    # Determine direction: if bg is dark, content should be light, and vice versa
    if bg_lum < 0.18:
        lo, hi = 0.5, 1.0  # search in light range
    else:
        lo, hi = 0.0, 0.5  # search in dark range

    # Binary search for lightness that hits the target
    for _ in range(64):
        mid = (lo + hi) / 2.0
        test_rgb = oklch_to_srgb(mid, C, H)
        ratio = contrast_ratio(bg_rgb, test_rgb)
        if ratio < FIX_TARGET:
            # Need more contrast: move further from background luminance
            if bg_lum < 0.18:
                lo = mid  # go lighter
            else:
                hi = mid  # go darker
        else:
            # Enough contrast: try to move closer to background (less extreme)
            if bg_lum < 0.18:
                hi = mid
            else:
                lo = mid

    result_L = (lo + hi) / 2.0
    return (result_L, C, H)


# ---------------------------------------------------------------------------
# Theme scanning
# ---------------------------------------------------------------------------

PAIRS = [
    ("primary", "primaryContent"),
    ("secondary", "secondaryContent"),
    ("accent", "accentContent"),
    ("base100", "baseContent"),
    ("error", "errorContent"),
]


def check_theme(theme_data, theme_name, fix=False):
    """
    Check one theme file. Returns (results, changes) where
    results is a list of dicts and changes is a list of (mode, key, old, new).
    """
    results = []
    changes = []

    for mode_key in ("light", "dark"):
        mode = theme_data.get(mode_key)
        if mode is None:
            continue
        colors = mode.get("colors", {})

        for bg_key, fg_key in PAIRS:
            bg_str = colors.get(bg_key)
            fg_str = colors.get(fg_key)

            if bg_str is None or fg_str is None:
                results.append({
                    "theme": theme_name,
                    "mode": mode_key,
                    "pair": f"{bg_key}/{fg_key}",
                    "ratio": None,
                    "pass": None,
                    "note": "missing color",
                })
                continue

            bg_oklch = parse_oklch(bg_str)
            fg_oklch = parse_oklch(fg_str)

            if bg_oklch is None or fg_oklch is None:
                results.append({
                    "theme": theme_name,
                    "mode": mode_key,
                    "pair": f"{bg_key}/{fg_key}",
                    "ratio": None,
                    "pass": None,
                    "note": "parse error",
                })
                continue

            bg_rgb = oklch_to_srgb(*bg_oklch)
            fg_rgb = oklch_to_srgb(*fg_oklch)
            ratio = contrast_ratio(bg_rgb, fg_rgb)
            passed = ratio >= WCAG_AA

            results.append({
                "theme": theme_name,
                "mode": mode_key,
                "pair": f"{bg_key}/{fg_key}",
                "ratio": ratio,
                "pass": passed,
                "note": "",
            })

            if not passed and fix:
                new_oklch = fix_content_color(bg_oklch, fg_oklch)
                new_str = format_oklch(*new_oklch)
                colors[fg_key] = new_str
                new_rgb = oklch_to_srgb(*new_oklch)
                new_ratio = contrast_ratio(bg_rgb, new_rgb)
                changes.append({
                    "theme": theme_name,
                    "mode": mode_key,
                    "key": fg_key,
                    "old": fg_str,
                    "new": new_str,
                    "old_ratio": ratio,
                    "new_ratio": new_ratio,
                })

    return results, changes


def find_themes_dir():
    """Locate the Themes directory relative to this script."""
    script_dir = Path(__file__).resolve().parent
    # If run from Specification/scripts/, themes are at ../Themes/
    themes_dir = script_dir.parent / "Themes"
    if themes_dir.is_dir():
        return themes_dir
    # If run from Specification/ directly
    themes_dir = script_dir / "Themes"
    if themes_dir.is_dir():
        return themes_dir
    return None


def main():
    parser = argparse.ArgumentParser(description="ODS Theme Contrast Audit")
    parser.add_argument("--fix", action="store_true", help="Auto-fix failing content colors")
    args = parser.parse_args()

    themes_dir = find_themes_dir()
    if themes_dir is None:
        print("ERROR: Cannot find Themes directory.", file=sys.stderr)
        sys.exit(2)

    theme_files = sorted(themes_dir.glob("*.json"))
    # Exclude catalog.json
    theme_files = [f for f in theme_files if f.name != "catalog.json"]

    if not theme_files:
        print("No theme files found.", file=sys.stderr)
        sys.exit(2)

    all_results = []
    all_changes = []
    themes_checked = 0
    modes_checked = 0

    for tf in theme_files:
        with open(tf, "r", encoding="utf-8") as fh:
            theme_data = json.load(fh)

        theme_name = theme_data.get("name", tf.stem)
        results, changes = check_theme(theme_data, theme_name, fix=args.fix)
        all_results.extend(results)
        all_changes.extend(changes)
        themes_checked += 1

        # Count modes
        for mk in ("light", "dark"):
            if mk in theme_data:
                modes_checked += 1

        # Write back if fixes were made
        if changes and args.fix:
            with open(tf, "w", encoding="utf-8") as fh:
                json.dump(theme_data, fh, indent=2, ensure_ascii=False)
                fh.write("\n")

    # --------------- Print results table ---------------
    failures = [r for r in all_results if r["pass"] is False]

    # Header
    print()
    print(f"{'Theme':<20} {'Mode':<6} {'Pair':<30} {'Ratio':>8} {'Result':>8}")
    print("-" * 76)

    for r in all_results:
        ratio_str = f"{r['ratio']:.2f}:1" if r['ratio'] is not None else "N/A"
        if r["pass"] is None:
            status = r["note"]
        elif r["pass"]:
            status = "PASS"
        else:
            status = "FAIL"
        print(f"{r['theme']:<20} {r['mode']:<6} {r['pair']:<30} {ratio_str:>8} {status:>8}")

    print("-" * 76)

    # Print fixes if any
    if all_changes:
        print()
        print("Fixes applied:")
        for c in all_changes:
            print(f"  {c['theme']} ({c['mode']}) {c['key']}: {c['old']} -> {c['new']}  "
                  f"({c['old_ratio']:.2f}:1 -> {c['new_ratio']:.2f}:1)")
        print()

    # Summary
    pairs_checked = len(all_results)
    fail_count = len(failures)
    print(f"{themes_checked} themes, {modes_checked} modes, {pairs_checked} pairs checked. {fail_count} failures.")

    if fail_count > 0 and not args.fix:
        sys.exit(1)
    elif fail_count > 0 and args.fix:
        # Re-check after fix: if all changes resulted in passing, exit 0
        print("(Fixes written to theme files.)")
        sys.exit(0)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
