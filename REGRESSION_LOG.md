# ODS Regression Test Log

Running diagnostics as we build out TDD coverage across both frameworks.

## Current Test Counts

| Framework | Test Files | Test Cases | Last Updated |
|-----------|-----------|------------|--------------|
| React Web (unit + component + conformance) | 55 | 1180+ | Batches 1-6 + 2026-04-26 push |
| React Web (Playwright E2E) | 13 | 51 (49 pass + 2 skip) | Batch 8 + gap closure (2026-04-19) |
| Flutter Local (incl. widget, excl. @slow) | 50+ | 865 | Batches 1-6 + 2026-04-26 push |

**Total: ~2096 tests across both frameworks.** Widget tests
(42) joined the gate 2026-04-26 — the multi-month "harness hang on
Windows" was diagnosed as a FakeAsync vs sqflite_ffi interaction;
fix lives in
[`Frameworks/flutter-local/test/widget/_test_harness.dart`](Frameworks/flutter-local/test/widget/_test_harness.dart)
(`bootEngineFor` + `disposeAllFor` + a `runAsync`-based pump loop).

## Bugs Found by Regression Tests

| # | Bug | Severity | Found By | Framework(s) | Status |
|---|-----|----------|----------|--------------|--------|
| 1 | `withData._id` could overwrite target `_id` via FakeDataService | Medium (security-adjacent) | Batch 1 B2 | React | Fixed both frameworks |
| 2 | `onEnd` only fired on record actions, silently ignored elsewhere | Medium | Batch 2 B2-2 | Both | Fixed (Option B: universal onEnd) |
| 3 | `hasAccess` case-sensitive on required roles | Low | Batch 3 B3-1 | Both | Fixed |
| 4 | Cascade rename "old value" detection fragile | Medium-High | Batch 2 B2-1 | Both | Fixed (pre-query row) |
| 5 | Flutter cascade bailed when child DS missing | Low | Batch 2 B2-1 | Flutter | Fixed as part of #6 |
| 6 | Flutter cascade shape differed from React | Cross-framework contradiction | Batch 2 B2-1 | Flutter | Flutter adopted React form |
| 7 | Flutter `{_id}` placeholder didn't resolve | Medium | Batch 2 B2-3 | Flutter | Fixed |
| 8 | Flutter action chain didn't catch thrown exceptions | Medium | Batch 2 B2-6 | Flutter | Fixed |
| 9 | Ternary evaluator broke on empty field substitution | Medium | Batch 6 B6-4 | Both | Fixed (`\S*` regex) |
| 10 | `ActionHandler` missing `delete` case (silent no-op) | **High** (feature gap) | Batch 6 B6-2 | Flutter | Fixed |
| 11 | Select field accepted values not in `options[]` | Medium | Batch 6 B6-1 | Both | Fixed (enum validation) |
| G1 | Number field accepted non-numeric text | Medium | Batch 6 B6-1 | Both | Fixed |
| G3 | Ternary only supported `==`, not `!=`/`>`/`<` | High (spec limitation) | Batch 6 B6-4 | Both | Fixed (Option B: full operators) |
| G5 | Template syntax mismatch (spec.md `{{}}` vs engine aggregates) | **Launch blocker** (docs) | Batch 6 B6-5 | Both | Fixed (updated spec.md) |
| G8 | showMessage with empty message left lastMessage null | Low | Batch 6 B6-2 | React | Fixed |
| G9 | Navigate to missing target silently succeeded | Low | Batch 6 B6-2 | Both | Fixed (logs warning) |

**Running total: 14 bugs/gaps found, 14 fixed**

## Design Decisions Made During Fixes

| Decision | Choice | Rationale |
|----------|--------|-----------|
| onEnd semantics | Universal (fires after any successful action) | Matches spec author intuition |
| Template syntax (`{{}}` vs `${}`) | Text content uses literal text + aggregates only; `${}` is for Quick Build templates | Matches current engine behavior; less risk |
| Ternary operators | Full set (`==`, `!=`, `>`, `<`, `>=`, `<=`) | Pre-launch — adding later would be breaking |
| Nested ternaries | Skipped (can achieve with computed fields) | Parser complexity not worth it yet |
| NOW case-insensitivity | Kept | Harmless, backward compat |
| Template escape | Skipped | Low priority |
| `_`-prefix user field names | Allowed | Consistent across frameworks |
| Field name length cap | None | Consistent with React |

## Batch History

### Batch 1 — Data flow & security fundamentals (✅)
8 scenarios × ~7 edge cases = 59 sub-tests per framework.
**Found**: Bug #1. **Fixed**: Bug #1 (both frameworks).

### Batch 2 — Action flow depth (✅)
7 scenarios × 4-6 edge cases = 31 sub-tests each.
**Found**: Bugs #2, #4, #5, #6, #7, #8. **Fixed**: All.

### Batch 3 — Auth & RBAC (✅)
6 scenarios × 5-10 edge cases.
**Found**: Bug #3. **Fixed**: Bug #3.

### Batch 4 — Edge cases (✅)
8 scenarios: empty DS, large DS, missing optionals, malformed JSON, unicode, concurrent, stale state, field name boundaries.
**Found**: 0 bugs (both frameworks very robust).

### Batch 5 — Component interactions (✅)
6 scenarios: form→list sync, recordSource nav, toggle, kanban, aggregates, expression evaluation.
**Found**: 0 bugs (both frameworks).

### Batch 6 — Spec completeness (✅)
5 scenarios: every field type, every action type, formula evaluator, expression evaluator, template engine.
**Found**: Bugs #9, #10, #11, G1, G3, G5, G8, G9. **Fixed**: All.

## What's Next

The regression suite has found and fixed 14 issues across 6 batches. Potential future work:

### Batch 7 — Flutter widget tests (in gate as of 2026-04-26)

42 widget tests covering button, chart, detail, form, kanban, list,
page renderer, summary, tabs, text. Files live in
`Frameworks/flutter-local/test/widget/`.

**Status:** All 42 in the local + CI gate. Earlier diagnosis blamed
"flutter_tools temp-dir race"; the actual root cause was
`flutter_test`'s FakeAsync zone intercepting (but never firing) the
native-bridge timers `sqflite_ffi` schedules — so `pumpAndSettle`
waited forever for "settle." Fix: setup runs inside `tester.runAsync`
to escape the FakeAsync zone (`bootEngineFor` / `disposeAllFor`),
and the harness's `pumpAndSettle` does fixed real-time pump rounds
(16 × 100ms) instead of FakeAsync settling. Plus a `pumpUntilFound`
helper for cases where fixed timing isn't enough. Diagnosis +
harness rewrite + 7 stale-test fixes (`SingleChildScrollView`
wrapping a `ListView`, headers asserted on empty data sources,
form not in pages map) all landed 2026-04-26.

### Batch 10 — Conformance parity (continuous since 2026-04-19)

Cross-framework parity contract via the ODS conformance driver
contract (ADR-0001). Shared specs live in
[`Frameworks/conformance/specs/`](Frameworks/conformance/specs/);
the TS scenario list at
[`Frameworks/conformance/src/scenarios.ts`](Frameworks/conformance/src/scenarios.ts)
mirrors the Dart side at
[`Frameworks/flutter-local/test/conformance/scenarios.dart`](Frameworks/flutter-local/test/conformance/scenarios.dart).

**Status (2026-04-26):** 26 scenarios × 2 drivers = 52 parity
tests. Both drivers green on every commit (gated by `publish.sh` +
the `flutter`/`react` GH workflows).

**Capabilities exercised:** `core`, `action:submit`, `action:update`,
`action:delete`, `action:navigate`, `action:showMessage`,
`action:recordNav`, `auth:multiUser`, `auth:selfRegistration`,
`auth:ownership`, `formulas`, `summary`, `tabs`, `chart`, `kanban`,
`detail`, `cascadeRename`, `theme`, `rowActions`.

**Bugs / parity gaps surfaced and fixed by this contract:**

- `OdsAction` parser dropped `level` on `showMessage` (s03) — fixed.
- React/Flutter cascade rename used different shapes (s20) — fixed,
  Flutter parser now preserves the canonical flat shape and runtime
  reads `parentField` directly.
- Flutter ownership column auto-schema missing (s16) — fixed, both
  frameworks now auto-append `ds.ownership.ownerField` to fields.
- React driver detail snapshot returned empty `fields: []` (s22) —
  fixed, both drivers now project the latest row into the snapshot.
- Both drivers explicitly punted on `CURRENT_USER.*` magic defaults
  (s25) — fixed, drivers now resolve via auth state.

**Open parity gaps:** `recordSource` default-order parity (s23) —
PocketBase defaults to `created` desc; SQLite returns insertion
order. s23 sidesteps this with order-agnostic assertions. Real fix
(optional `sort` directive on `firstRecord`) tracked in
[TODO.md](TODO.md).

**Workflow:** the conformance suite is now treated as the contract,
not coverage applied after the fact. Cross-framework changes go in
red on both drivers, then green on both — see
[CONTRIBUTING.md → Conformance scenarios — contract-first](CONTRIBUTING.md#conformance-scenarios--contract-first).

### Batch 8 — E2E browser tests (implemented 2026-04-19)
Expanded Playwright coverage from the 3-smoke starter to **22 regression tests** (21 passing, 1 skipped) across 5 new spec files, plus the 5 critical + 3 smoke specs already in place. Full run is **47 passed, 3 skipped in ~1.6 min** on a single worker (serial, one shared PB instance).

**Infrastructure added (`Frameworks/react-web/tests/e2e/`):**
- `global-setup.ts` / `global-teardown.ts` — manages a dedicated PocketBase process per test run.
- `helpers/pocketbase-server.ts` — downloads + caches the PB v0.25.9 binary to `.pb-e2e/`, starts it on `127.0.0.1:8090`, wipes `pb_data/` every run.
- `helpers/pocketbase-admin.ts` — CLI-based `superuser upsert` for the `admin@e2e.local` superadmin.
- `helpers/pb-client.ts` — SDK client + `withSuperadmin` privileged-call wrapper.
- `helpers/app-seed.ts` — `seedApp(name, spec)` that inserts an `_ods_apps` record AND pre-creates the per-app data-source collections so guest pages don't hit 401 on ensureCollection.
- `helpers/fixtures.ts` — `adminPage` fixture that authenticates through the real login card and handles the first-run onboarding screen.

**New specs in `tests/e2e/regression/`:**
- `admin-workflow.spec.ts` — 6 tests: unauthenticated login card, sign-in flow (incl. wrong-password), seeded-dashboard rendering, empty-dashboard onboarding, quick-build navigation.
- `app-crud.spec.ts` — 5 tests: active-app slug routing, unknown-slug 404, archived-app notice, form submit → list refresh round-trip, dashboard context-menu + archive flow.
- `multi-user.spec.ts` — 5 tests: login screen for guests, sign-up form visibility (selfRegistration on/off), password-mismatch validation. Full sign-up → home flow is **skipped** pending a `users` collection bootstrap step in globalSetup.
- `data-interactions.spec.ts` — 3 tests: kanban renders a column per status option, kanban handles empty dataSources, data-export dialog exposes JSON/CSV/SQL options.
- `admin-settings.spec.ts` — 3 tests: settings route renders all sections, theme-mode segmented control, log-level dropdown.

**Related product-code changes:**
- Removed `pb.authStore.clear()` from `src/lib/pocketbase.ts` — it was clearing the admin session on every navigation, which hurt UX and made E2E auth untestable. Sessions now persist until explicit logout (standard PB SDK behavior).
- CI wiring in `.github/workflows/test.yml` — E2E job now enabled alongside the unit job; Playwright's globalSetup handles PB startup, so no extra CI steps required.

**Gap closure (same-day follow-up):**

- **PB `users` collection auto-creation** — product fix. `AuthService.ensureUsersCollection()` ([auth-service.ts](Frameworks/react-web/src/engine/auth-service.ts)) creates the auth collection on first admin load; wired into `AdminGuard` tryAuth + handleLogin ([AdminGuard.tsx](Frameworks/react-web/src/screens/AdminGuard.tsx)). Also fixed a latent sign-up bug in `LoginScreen.handleSignUp` ([LoginScreen.tsx](Frameworks/react-web/src/screens/LoginScreen.tsx)) where `needsAdminSetup: true` kept the sign-up form visible after a non-admin self-registered. Sign-up end-to-end test unskipped and passing.
- **Kanban drag-and-drop coverage** — added `data-ods-kanban-column={status}` and `data-ods-kanban-card={rowId}` attributes to [KanbanComponent.tsx](Frameworks/react-web/src/renderer/components/KanbanComponent.tsx), plus `seedRows`/`readRow` helpers in [app-seed.ts](Frameworks/react-web/tests/e2e/helpers/app-seed.ts). New test `dragging a card to another column persists the new status` uses `locator.dragTo()` and polls PB to confirm the `status` field actually updated. Ran 3× back-to-back with zero flake (~5s each); fallback to manual `mouse.down`/`move`/`up` stayed unused.
- **Firefox** — still chromium-only per scope; revisit once the suite is considered stable enough to justify the 2× runtime.

**Post-closure totals: 49 passing + 2 skipped in ~1.3 min.** Unit suite untouched (1117 passing).

### Batch 9 — Performance tests (implemented, 5 flaky on slow Windows)
`Frameworks/flutter-local/test/integration/batch9_performance_test.dart` covers parse speed, data-service throughput (insert/query/filter), action chain speed, engine reactivity.

**Status on Windows/c:\Apps:** P1 parsing, P3 spec loading, P5 reactivity all pass. P2 data-service (insert/query/filter 10k rows) and P4 action chains (100 sequential submits) occasionally exceed their generous budgets on this dev machine's slow I/O. 794/800 integration+engine tests pass; the 5 flaky P2/P4 cases are timing-only, not correctness regressions.

---

## 2026-04-19 — Off-OneDrive move + architecture cleanup (not a numbered batch)

Not test work, but the moves that followed the project migration to `c:\Apps\One-does-simply`:

- **Storage-folder bootstrap**: `lib/engine/settings_store.dart` now resolves `getOdsDirectory()` via a bootstrap file at `getApplicationSupportDirectory()/ods_bootstrap.json` (AppData, not OneDrive-redirected). First-run prompt in `_OdsFrameworkAppState._showFirstRunStoragePrompt` lets the user pick/accept a folder. `SettingsStore.moveStorageFolder` / `resetStorageFolder` move existing data when the folder is changed. `log_service.dart` now honors the bootstrap.
- **Unified user list**: extracted `FrameworkUserList` to `lib/widgets/framework_user_list.dart`; both Framework Settings and per-app Settings (when `isMultiUserEnabled`) now render the same list backed by `FrameworkAuthService`. Per-app user management is hidden (with a hint) when framework multi-user is off. `UserManagementScreen` and `_InlineUserList` were removed as dead code.
- **User identity fields**: `AuthService` and `FrameworkAuthService` now track `currentEmail` alongside `currentUsername` / `currentDisplayName`. `AppEngine.frameworkEmail` propagates through `injectFrameworkAuth(email: ...)`. `form_component.dart` resolves `CURRENT_USER.EMAIL` (previously only NAME/USERNAME). Admin-setup screens collect a separate Name field instead of defaulting display_name to email.
