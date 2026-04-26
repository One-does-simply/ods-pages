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
DART="c:/Users/<user>/develop/flutter/bin/dart.bat"

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
  echo -e "${YELLOW}Flutter${NC} — analyzing..."
  cd "$ODS_ROOT/Frameworks/flutter-local"
  # Mirrors flutter.yml's analyze step. Errors are fatal; warnings/infos
  # are not (large existing baseline of style nits).
  if ! "$FLUTTER" analyze --no-fatal-warnings --no-fatal-infos 2>&1 | tail -10; then
    echo -e "${RED}Flutter${NC} — analyze failed"
    return 1
  fi

  echo -e "${YELLOW}Flutter${NC} — running tests (incl. widget) with coverage..."
  # Widget tests now in the gate: the FakeAsync-vs-sqflite_ffi hang was
  # diagnosed and fixed in test/widget/_test_harness.dart (use
  # bootEngineFor + tester.runAsync, see harness comments).
  # Perf tests live in test/integration/batch9_performance_test.dart and
  # are tagged `slow` — excluded because their Windows I/O timing budgets
  # flake. Run them on demand with `flutter test --tags=slow`.
  if ! "$FLUTTER" test test/engine test/models test/parser test/integration test/conformance test/widget \
      --exclude-tags=slow --coverage --reporter compact 2>&1 | tail -20; then
    echo -e "${RED}Flutter${NC} — tests failed"
    return 1
  fi

  echo -e "${YELLOW}Flutter${NC} — enforcing coverage thresholds..."
  if ! "$DART" run tool/coverage_check.dart 2>&1; then
    echo -e "${RED}Flutter${NC} — coverage thresholds failed"
    return 1
  fi
  echo -e "${GREEN}Flutter${NC} — analyze + tests + coverage passed"
}

run_react_tests() {
  echo -e "${YELLOW}React${NC} — typechecking..."
  cd "$ODS_ROOT/Frameworks/react-web"
  # Mirrors react.yml's TypeScript check step. tsc -b respects project
  # references (tsconfig.app.json + tsconfig.node.json).
  if ! npx tsc -b 2>&1 | tail -10; then
    echo -e "${RED}React${NC} — typecheck failed"
    return 1
  fi

  echo -e "${YELLOW}React${NC} — running unit + component tests with coverage..."
  # `test:coverage` runs vitest with --coverage. Per-folder thresholds
  # in vitest.config.ts gate the run (models 90%, parser 90%, engine 50%).
  if ! npm run test:coverage 2>&1 | tail -8; then
    echo -e "${RED}React${NC} — tests or coverage thresholds failed"
    return 1
  fi
  echo -e "${GREEN}React${NC} — typecheck + tests + coverage passed"
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
