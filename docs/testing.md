# Testing in ODS Pages

This doc explains the test layers in this monorepo, what each one is
for, and where the boundaries are. If you're contributing a fix or
feature, the section on "where does my test go" is the practical
answer.

## Layers

From fastest + narrowest to slowest + broadest:

### 1. Unit tests

Per-module, no UI, no network, no database (or a fake one). Pure
function and class behavior.

- **React**: `Frameworks/react-web/tests/unit/`
- **Flutter**: `Frameworks/flutter-local/test/engine/`,
  `test/models/`, `test/parser/`

Run via `npm test` (React) and `flutter test test/engine ...` (Flutter).
Hundreds of tests; should take seconds.

### 2. Component tests

Render a single component in isolation against a fake data layer.
Verify the component reacts to state changes, dispatches events, and
emits the expected DOM/widget tree.

- **React**: `Frameworks/react-web/tests/component/` (Testing
  Library + Vitest jsdom env)
- **Flutter**: `test/widget/` — currently **skipped on Windows AND
  Linux CI** due to a `flutter_tools` harness hang. Tracked in
  TODO.md as "Widget-test unskip."

### 3. Integration tests (Flutter only)

Multi-module flows against the real `AppEngine` and a temp-folder
SQLite. Verifies end-to-end behavior of the framework — submit
inserts, action chains fire, cascade rename propagates, etc.

- **Flutter**: `Frameworks/flutter-local/test/integration/`
  (`batch1_*` through `batch9_*`).
- **Batch 9 is `@slow`-tagged** — perf baselines that flake on
  Windows I/O timing budgets. Excluded from `publish.sh` and CI by
  default. Run on demand with `flutter test --tags=slow`.

React doesn't have a separate "integration" tier — its component
tests + the conformance suite + E2E cover that ground.

### 4. Conformance tests (cross-framework parity)

The contract that pins behavior consistency between renderers. Each
scenario runs against every renderer's driver; a scenario that
passes in one but not the other is a parity bug.

- **Specs (shared)**: `Frameworks/conformance/specs/*.json`
- **Scenarios + assertions**: `Frameworks/conformance/src/scenarios.ts`
  (TS) and `Frameworks/flutter-local/test/conformance/scenarios.dart`
  (Dart)
- **Drivers**:
  `Frameworks/react-web/tests/conformance/react-driver.ts`
  and `Frameworks/flutter-local/test/conformance/flutter_driver.dart`

23 scenarios as of 2026-04-25, pinning ~14 capabilities. The contract
itself is documented in
[docs/adr/0001-conformance-driver-contract.md](adr/0001-conformance-driver-contract.md).

**This is the contract — write the test first.** When you change
cross-framework behavior, the scenario goes in before the
implementation. Both drivers should be red, then both should be green.
A merged feature without a failing-then-passing scenario was not built
test-first. See
[CONTRIBUTING.md → Conformance scenarios](../CONTRIBUTING.md#conformance-scenarios--contract-first)
for the full workflow.

### 5. E2E tests (React only)

End-to-end through the real React app + a real PocketBase, driven by
Playwright. Slowest, broadest coverage; gated separately in CI.

- **Location**: `Frameworks/react-web/tests/e2e/`
- **Run**: `cd Frameworks/react-web && npx playwright test --project=chromium`
- **PocketBase**: started + stopped automatically by
  `tests/e2e/global-setup.ts` and `global-teardown.ts`. No manual
  setup needed; the tests bring their own PB binary.

#### E2E folder convention

| Folder            | Purpose                                                      | Examples                                    |
| ----------------- | ------------------------------------------------------------ | ------------------------------------------- |
| `smoke/`          | "Does the app come up?" — checks at startup boundaries       | `app-loads.spec.ts`, `navigation.spec.ts`   |
| `critical/`       | Paths that *must* work — guards on routing, auth, validation | `admin-guard.spec.ts`, `routing.spec.ts`    |
| `regression/`     | Pin a previously-found bug or batch finding                  | `multi-user.spec.ts`, `app-crud.spec.ts`    |
| `workflows/`      | Multi-step user journeys that touch several screens          | *(empty — future)*                          |
| `accessibility/`  | `@axe-core/playwright` scans on key pages                    | *(empty — future)*                          |

The empty folders are intentional placeholders. Both `accessibility`
and `workflows` are tracked in TODO.md as "nice-to-haves."

When you add an E2E test, ask:
- Does it guard a startup or navigation invariant? → `smoke/`
- Does it guard a path the app cannot ship without? → `critical/`
- Does it pin a specific past bug? → `regression/` (with bug id in
  the test name when possible)
- Does it walk through a multi-screen user journey? → `workflows/`
- Is it an axe scan? → `accessibility/`

## Where does my test go?

Decision tree for new tests:

1. **Is it cross-framework behavior?** (Same spec should produce the
   same observable behavior on Flutter + React.)
   → **Conformance scenario** (`Frameworks/conformance/`).

2. **Is it framework-specific behavior with a UI?**
   - **React**: component test (`tests/component/`) if isolated;
     E2E (`tests/e2e/`) if it requires the full app + PocketBase.
   - **Flutter**: integration test (`test/integration/`) — widget
     tests are blocked until the harness hang is fixed.

3. **Is it framework-specific behavior with no UI** (engine, model,
   parser)?
   - **React**: unit test (`tests/unit/`).
   - **Flutter**: unit test under `test/engine/`, `test/models/`,
     `test/parser/`.

4. **Is it a performance baseline?** Flutter
   `test/integration/batch9_performance_test.dart` is the home for
   these (`@slow`-tagged). React doesn't have a perf gate yet.

## The local + CI gate

[publish.sh](../publish.sh) runs the same gate locally that CI runs:

- **Flutter**: `flutter test test/engine test/models test/parser test/integration test/conformance --exclude-tags=slow`
- **React**: `npm test` (vitest unit + component + conformance)

E2E tests are NOT in `publish.sh` — they're slower and live in the
`e2e` job in [.github/workflows/react.yml](../.github/workflows/react.yml).

## Test counts

Living counts (kept rough):

| Layer                 | Count |
| --------------------- | ----- |
| Flutter (excluding widget + slow) | ~810 |
| React (unit + component + conformance) | ~1145 |
| Conformance scenarios | 23 (× 2 drivers = 46 parity tests) |
| React E2E (Playwright) | ~50 |

For exact current numbers and the bugs each batch found, see
[REGRESSION_LOG.md](../REGRESSION_LOG.md).
