#!/bin/bash
# publish.sh — Stage, commit, and push changes in the ods-pages monorepo.
#
# Usage:
#   ./publish.sh "commit message"     # run tests, commit, push
#   ./publish.sh "commit message" --skip-tests   # bypass test gate
#                                                  (use when flakes are known-flaky)
#   ./publish.sh --status             # show current working-tree state
#
# Runs Flutter + React unit tests before committing; aborts on failure
# unless --skip-tests is passed. E2E tests are NOT run here (they're
# slower and live in CI).

set -euo pipefail

ODS_ROOT="c:/Apps/One-does-simply"
FLUTTER="c:/Users/<user>/develop/flutter/bin/flutter.bat"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── helpers ──────────────────────────────────────────────────────────────────

show_status() {
  cd "$ODS_ROOT"
  local changes
  changes="$(git status --porcelain)"
  if [[ -n "$changes" ]]; then
    echo -e "${YELLOW}ods-pages${NC} — has changes:"
    echo "$changes" | sed 's/^/  /'
  else
    echo -e "${GREEN}ods-pages${NC} — clean"
  fi
}

run_flutter_tests() {
  echo -e "${YELLOW}Flutter${NC} — running non-widget tests..."
  cd "$ODS_ROOT/Frameworks/flutter-local"
  # Widget tests are skipped on Windows (flutter_tools temp-dir race).
  # Perf tests live in test/integration/batch9_performance_test.dart and
  # are known to flake on slow I/O; exclude them from the test gate.
  if ! "$FLUTTER" test test/engine test/models test/parser test/integration --reporter compact 2>&1 | tail -20; then
    echo -e "${RED}Flutter${NC} — tests failed"
    return 1
  fi
  echo -e "${GREEN}Flutter${NC} — tests passed"
}

run_react_tests() {
  echo -e "${YELLOW}React${NC} — running unit + component tests..."
  cd "$ODS_ROOT/Frameworks/react-web"
  if ! npm test 2>&1 | tail -5; then
    echo -e "${RED}React${NC} — tests failed"
    return 1
  fi
  echo -e "${GREEN}React${NC} — tests passed"
}

# ── main ─────────────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--status" ]]; then
  show_status
  exit 0
fi

if [[ -z "${1:-}" ]]; then
  echo "Usage: ./publish.sh \"commit message\" [--skip-tests]"
  echo "       ./publish.sh --status"
  exit 1
fi

MESSAGE="$1"
SKIP_TESTS=0
if [[ "${2:-}" == "--skip-tests" ]]; then
  SKIP_TESTS=1
  echo -e "${YELLOW}Warning:${NC} --skip-tests passed; publishing without running tests."
fi

cd "$ODS_ROOT"

if [[ -z "$(git status --porcelain)" ]]; then
  echo -e "${GREEN}ods-pages${NC} — nothing to publish"
  exit 0
fi

if [[ $SKIP_TESTS -eq 0 ]]; then
  run_flutter_tests || { echo -e "${RED}aborting publish${NC}"; exit 1; }
  run_react_tests   || { echo -e "${RED}aborting publish${NC}"; exit 1; }
fi

cd "$ODS_ROOT"
echo -e "${YELLOW}ods-pages${NC} — staging and committing..."
git add -A
git commit -m "$MESSAGE

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"

echo -e "${YELLOW}ods-pages${NC} — pushing..."
git push

echo -e "${GREEN}ods-pages${NC} — published ✓"
