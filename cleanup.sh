#!/bin/bash
# cleanup.sh — Reset build caches and (optionally) runtime data so the
# React + Flutter dev environments are fresh.
#
# Useful after a history rewrite, after pulling a big change, when
# fighting stale dependencies, or before a clean test run.
#
# Usage:
#   ./cleanup.sh                  # --deps (build caches + reinstall)
#   ./cleanup.sh --deps           # explicit
#   ./cleanup.sh --reset-data     # only nuke runtime DBs / fixtures
#   ./cleanup.sh --all            # both
#   ./cleanup.sh --dry-run        # show what would be removed (with --all)
#   ./cleanup.sh --help
#
# What --deps does:
#   React (Frameworks/react-web/):
#     - rm node_modules, dist, coverage, .stryker-tmp, playwright-report,
#       test-results, tests/e2e/.pb-e2e
#     - npm install
#   Flutter (Frameworks/flutter-local/):
#     - flutter clean (build/, .dart_tool/, ephemeral plugin symlinks)
#     - rm coverage, .dart_tool, build (belt-and-braces)
#     - flutter pub get
#
# What --reset-data does:
#   Flutter:
#     - rm <Documents>/One Does Simply/* (SQLite DBs, settings, logs,
#       loaded apps index). Honors a custom bootstrap path if one exists
#       in %APPDATA%/com.onedoessimply/ods_flutter_local/ods_bootstrap.json.
#   React:
#     - rm tests/e2e/.pb-e2e (Playwright PocketBase cache + per-run data)
#     - Note: localStorage in your browser must be cleared manually
#       (DevTools → Application → Storage → Clear).

set -euo pipefail

ODS_ROOT="$(cd "$(dirname "$0")" && pwd)"
FLUTTER="${FLUTTER:-$(command -v flutter.bat 2>/dev/null || command -v flutter 2>/dev/null || echo flutter)}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
GRAY='\033[0;37m'
NC='\033[0m'

# ── flag parsing ─────────────────────────────────────────────────────────────

DEPS=0; DATA=0; DRY=0
case "${1:-}" in
  --all)         DEPS=1; DATA=1 ;;
  --reset-data)  DEPS=0; DATA=1 ;;
  --deps|"")     DEPS=1; DATA=0 ;;
  --dry-run)     DEPS=1; DATA=1; DRY=1 ;;
  -h|--help)
    sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
    ;;
  *)
    echo "Unknown flag: $1"
    echo "Try ./cleanup.sh --help"
    exit 1
    ;;
esac
# Allow --dry-run as a second flag with --all / --deps / --reset-data.
case "${2:-}" in --dry-run) DRY=1 ;; esac

[[ $DRY -eq 1 ]] && echo -e "${YELLOW}DRY RUN — nothing will actually be deleted${NC}"

# ── helpers ──────────────────────────────────────────────────────────────────

# nuke <path>: remove <path> if it exists, with size + dry-run support.
nuke() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo -e "  ${GRAY}skip${NC} $path (absent)"
    return
  fi
  local size
  size=$(du -sh "$path" 2>/dev/null | cut -f1)
  if [[ $DRY -eq 1 ]]; then
    echo -e "  ${YELLOW}[dry]${NC} would remove $path ($size)"
  else
    echo -e "  ${RED}rm${NC}    $path ($size)"
    rm -rf "$path"
  fi
}

# Resolve the Flutter ODS data folder. Honors a custom bootstrap path if
# present; otherwise walks the documented default candidates.
# Uses $HOME (msys-style /c/Users/<user>) rather than $USERPROFILE
# (windows-style C:\Users\<user>) so bash globs work correctly.
resolve_ods_data_dir() {
  local appdata_msys="$HOME/AppData/Roaming"
  local bootstrap="$appdata_msys/com.onedoessimply/ods_flutter_local/ods_bootstrap.json"
  if [[ -f "$bootstrap" ]]; then
    # Bootstrap is JSON: {"customPath": "C:\\..."}; extract via grep+sed.
    local custom
    custom=$(grep -oE '"customPath"[[:space:]]*:[[:space:]]*"[^"]*"' "$bootstrap" 2>/dev/null \
             | sed -E 's/.*"customPath"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' \
             | sed 's|\\\\|/|g; s|^\([A-Za-z]\):|/\L\1|')
    if [[ -n "$custom" && -d "$custom" ]]; then
      echo "$custom"
      return
    fi
  fi
  # Default candidates. The array-literal + nullglob form is what makes
  # paths-with-spaces work — each glob match is a single array element,
  # so "OneDrive - PPG …/Documents/One Does Simply" stays one element
  # rather than getting word-split on every space.
  shopt -s nullglob
  local candidates=(
    "$HOME/Documents/One Does Simply"
    "$HOME"/OneDrive*/Documents/"One Does Simply"
  )
  shopt -u nullglob
  for resolved in "${candidates[@]}"; do
    if [[ -d "$resolved" ]]; then
      echo "$resolved"
      return
    fi
  done
}

# ── --deps: build / dependency caches ────────────────────────────────────────

if [[ $DEPS -eq 1 ]]; then
  echo -e "${YELLOW}== React: build & cache ==${NC}"
  for d in node_modules dist coverage .stryker-tmp playwright-report test-results tests/e2e/.pb-e2e; do
    nuke "$ODS_ROOT/Frameworks/react-web/$d"
  done

  echo -e "${YELLOW}== Flutter: build & cache ==${NC}"
  if [[ $DRY -eq 1 ]]; then
    echo -e "  ${YELLOW}[dry]${NC} would run: flutter clean (in Frameworks/flutter-local)"
  else
    (cd "$ODS_ROOT/Frameworks/flutter-local" && "$FLUTTER" clean 2>&1 | tail -5) || true
  fi
  # Belt-and-braces: flutter clean misses ephemeral symlinks on Windows
  # if the build directory was renamed/moved (CMake cache mismatch). Take
  # the explicit removal pass too.
  for d in build .dart_tool coverage \
           linux/flutter/ephemeral macos/Flutter/ephemeral windows/flutter/ephemeral; do
    nuke "$ODS_ROOT/Frameworks/flutter-local/$d"
  done
fi

# ── --reset-data: runtime app data ───────────────────────────────────────────

if [[ $DATA -eq 1 ]]; then
  echo -e "${YELLOW}== Flutter: runtime data ==${NC}"
  ods_dir="$(resolve_ods_data_dir)"
  if [[ -n "$ods_dir" ]]; then
    echo -e "  ${GRAY}detected${NC} $ods_dir"
    nuke "$ods_dir"
  else
    echo -e "  ${GRAY}skip${NC} (no ODS data folder detected — running app has never written data here)"
  fi

  echo -e "${YELLOW}== React: runtime / E2E fixtures ==${NC}"
  nuke "$ODS_ROOT/Frameworks/react-web/tests/e2e/.pb-e2e"
  echo -e "  ${GRAY}note${NC} localStorage in the browser is per-domain — clear manually:"
  echo -e "  ${GRAY}     ${NC} DevTools → Application → Storage → Clear (keys: ods_theme_<app>, ods_default_app_*)"
fi

# ── --deps: reinstall after clean ────────────────────────────────────────────

if [[ $DEPS -eq 1 && $DRY -eq 0 ]]; then
  echo -e "${YELLOW}== React: npm install ==${NC}"
  (cd "$ODS_ROOT/Frameworks/react-web" && npm install 2>&1 | tail -5) || true

  echo -e "${YELLOW}== Flutter: pub get ==${NC}"
  (cd "$ODS_ROOT/Frameworks/flutter-local" && "$FLUTTER" pub get 2>&1 | tail -5) || true
fi

echo -e "${GREEN}Done.${NC}"
