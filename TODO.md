# ODS TODO

Companion to [REGRESSION_LOG.md](REGRESSION_LOG.md) (test batches + bugs found).
Loose rules: drop things in freely, re-sort when you revisit. Link to code
paths the same way REGRESSION_LOG does so the list doubles as a jump-table.

---

## Now — actively being worked on

- _No focused initiative._ Day-to-day maintenance mode: when a new
  cross-framework bug comes up, add a contract-first conformance
  scenario that pins it (CONTRIBUTING.md → "Conformance scenarios —
  contract-first"). Conformance count: **26 scenarios × 2 drivers =
  52 parity tests**. Test gate (Flutter 865 + React 1180+ +
  conformance + coverage thresholds + Stryker weekly) is solid.

## Next — next 1–2 sessions

- _No queued initiative._ Pick from Later / Wishlist when a session
  starts. Strong candidates: `recordSource` default-order parity fix
  (concrete bug surfaced by s23), or deepening s17/s18 (real behavior
  vs initial-state assertions).

## Docs — priority 3 (pre-public polish)

- [ ] **`CHANGELOG.md`** — low value until releases start; relevant
      once the conformance suite pins spec versions.

## Later — important, not urgent

- [ ] **`recordSource` default-order parity** — surfaced by s23
      (record navigation). PocketBase defaults to `created` desc, so
      FakeDataService.query reverses results to mimic that; SQLite's
      default scan returns insertion order. Same spec → different
      "first record" across frameworks. The s23 scenario currently
      sidesteps this with order-agnostic assertions. Real fix: add an
      optional `sort` directive to the `firstRecord` action (and/or
      pick a single canonical default) so `firstRecord` is
      deterministic for a given spec on every renderer.
- [ ] **Conformance: deepen existing narrow scenarios** — a few
      scenarios pin only initial state or config, not behavior:
      - **s17 tabs**: only asserts initial active state; add a
        `clickTab(label)` primitive + test that switching tabs
        changes which is active, and that the snapshot only exposes
        the active tab's content (if that's the actual contract).
      - **s18 chart**: only asserts config propagation; no
        aggregation math. Add a variant that seeds rows, snapshots
        the chart's series values (would need `seriesCount` /
        `seriesData` in the snapshot, not just a hardcoded 1).
- [ ] **Conformance: scenario catalog parity check** — the scenario
      *list* (ids, names, capabilities) is duplicated between
      [scenarios.ts](Frameworks/conformance/src/scenarios.ts) and
      [scenarios.dart](Frameworks/flutter-local/test/conformance/scenarios.dart).
      Extract to `conformance/scenarios.json` (just the metadata;
      run bodies stay per-language); add a meta-test on each side
      that asserts "every scenario id in the catalog has a scenario
      implementation." Prevents the two sides from silently drifting
      in which scenarios they advertise.
- [ ] **Generator code honors SettingsStore** — `code_generator.dart`
      still uses `getApplicationDocumentsDirectory()` directly in its
      emitted code (see [code_generator.dart:475](Frameworks/flutter-local/lib/engine/code_generator.dart#L475)).
      Low priority because the generated app runs on *someone else's*
      machine, but worth revisiting for consistency.

## Wishlist — ideas; not scheduled

- [ ] **Mutation testing — Dart side** — Stryker for React landed
      (2026-04-26: `Frameworks/react-web/stryker.config.json`, weekly
      [.github/workflows/mutation.yml](.github/workflows/mutation.yml),
      `npm run mutation`). Mirror with `mutation_test` package on the
      Flutter side once the React baseline stabilises and we know
      whether it's catching real gaps.
- [ ] **Visual regression tests** for theme rendering. Playwright snapshots
      or Percy. CLAUDE.md flags theming as a historical pain point; worth
      it once the API churn settles.
- [ ] **Property-based tests — formula evaluator + further parser
      coverage** — first slice landed 2026-04-26: spec-parser totality /
      soundness / minimal-valid in
      [tests/unit/parser/spec-parser-properties.test.ts](Frameworks/react-web/tests/unit/parser/spec-parser-properties.test.ts)
      (fast-check) and the Dart mirror in
      [test/parser/spec_parser_properties_test.dart](Frameworks/flutter-local/test/parser/spec_parser_properties_test.dart)
      (seeded RNG). Next: round-trip properties for the formula
      evaluator and aggregate evaluator.
- [ ] **Accessibility tests** — `@axe-core/playwright` is already a
      devDep, [tests/e2e/accessibility/](Frameworks/react-web/tests/e2e/accessibility/)
      is empty. A pass on key flows (login, dashboard, app home) would
      catch a lot cheaply.
- [ ] **Third renderer** — Swift/SwiftUI mobile-native, or a terminal-UI
      renderer for scripting/piping. Drives real pressure on the
      conformance driver contract (Path B).
- [ ] **GitHub Issues migration** — when the ODS spec goes public, the
      "drop it in TODO.md" loop becomes the wrong interface for external
      contributors. Move Later/Wishlist items to Issues, pin a Roadmap,
      keep Now/Next here.
- [ ] **Public conformance badge** — once Path B lands + the contract
      stabilizes, publish `ods-conformance` and let 3rd-party frameworks
      self-certify. Ecosystem play.

---

## Done — recent (trim quarterly)

### 2026-04-26 — TDD discipline push (sessions 12+ commits)

- [x] **Conformance-first workflow doc** in
      [CONTRIBUTING.md](CONTRIBUTING.md#conformance-scenarios--contract-first)
      and [docs/testing.md](docs/testing.md) — scenario goes in red
      on both drivers before implementation. ADR-0002 used as the
      worked example.
- [x] **6 new conformance scenarios** (s21–s26): theme config
      round-trip, detail fields, record navigation
      (firstRecord/nextRecord/onEnd), clickMenuItem, CURRENT_USER
      magic defaults, list defaultSort drives displayed row order.
      3 of them surfaced real driver/parity gaps — driver methods
      added, gaps closed in the same flow.
      [scenarios.ts](Frameworks/conformance/src/scenarios.ts).
- [x] **CI ↔ local parity tightened**: workflows trigger on
      `Frameworks/conformance/**` (was a hidden path-filter gap);
      `publish.sh` adds `npx tsc -b` + `flutter analyze` so the
      static checks CI runs also fail locally. Conformance count
      bumped to 26 scenarios × 2 drivers = 52 parity tests.
- [x] **Coverage thresholds enforced** locally + in CI: vitest
      per-folder (`models` 90%, `parser` 90%, `engine` 50%) plus a
      Dart `tool/coverage_check.dart` that parses `lcov.info` and
      enforces `lib/engine` 60% / `lib/models` 85% / `lib/parser`
      80%. Both fail-non-zero on regression.
- [x] **Pure helper extraction**: `buildUpdatedSpecJson` on both
      frameworks
      ([theme-spec-writer.ts](Frameworks/react-web/src/engine/theme-spec-writer.ts)
      / [theme_spec_writer.dart](Frameworks/flutter-local/lib/engine/theme_spec_writer.dart))
      replaces inline JSON munging in the admin save-to-spec path.
      28 unit tests added (14 per framework).
- [x] **Property-based parser tests** on both frameworks: fast-check
      for React (5 properties), seeded RNG for Flutter (5 properties)
      — totality / soundness / minimal-valid invariants pinned over
      ~600 random inputs.
- [x] **Flutter widget tests un-skipped + 42 in the gate**.
      Diagnosed the multi-month "harness hang on Windows" as a
      FakeAsync-vs-sqflite_ffi interaction: the native-bridge timers
      sqflite_ffi schedules are intercepted by FakeAsync but never
      fired, so `pumpAndSettle` waits forever. Fix: `bootEngineFor` /
      `disposeAllFor` wrap setup in `tester.runAsync` to escape the
      FakeAsync zone; `pumpAndSettle` does fixed real-time pump
      rounds (16 × 100ms) instead. Plus a `pumpUntilFound` helper
      for cases where fixed timing isn't enough.
      [_test_harness.dart](Frameworks/flutter-local/test/widget/_test_harness.dart).
- [x] **Stale widget tests fixed**: 7 tests had real bugs that
      compounded in the run-skip gap — `SingleChildScrollView`
      around a `ListView` (nested viewports), assertions for column
      headers / search inputs that the renderer hides under the
      "No data yet" empty state, a form referencing a `formId` not
      in the spec's pages.
- [x] **Pre-commit + CI gate** now runs Flutter widget tests too;
      total Flutter ~810 → 865.
- [x] **Eliminate widget-test flake**: bumped pump rounds to
      16 × 100ms (1.6s worst case) after a 5-run validation showed
      ~20% flake at the 8 × 75ms tuning. 5 / 5 consecutive full-gate
      runs now green.
- [x] **Mutation testing scaffolded (React side)**: Stryker config,
      `npm run mutation`, `.gitignore` updates, weekly
      [.github/workflows/mutation.yml](.github/workflows/mutation.yml)
      + `workflow_dispatch`. Threshold gate is `break: 0` for now —
      switch to a real break threshold after 2-3 weekly runs settle.
- [x] **Process docs**: regression-scenario rule in CONTRIBUTING
      (every bug fix lands with a failing-then-passing test) +
      [.github/pull_request_template.md](.github/pull_request_template.md)
      with a Test plan checklist.

### 2026-04-25 — ADR-0002 (Theme + Customizations redesign) shipped

- [x] **Phase 1**: dropped `OdsBranding` entirely; replaced with
      `OdsTheme { base, mode, headerStyle, overrides }`. Logo /
      favicon / appIcon lifted to top-level `OdsApp`. Fonts moved
      onto the theme. Both parsers + 17 in-repo specs +
      `ods-schema.json` rewritten to the new shape — no parser shim.
- [x] **Phase 2**: replaced the freeform font textbox with
      [FontPicker.tsx](Frameworks/react-web/src/components/FontPicker.tsx)
      — curated dropdown of system fonts + Google Fonts (lazy-loaded
      via injected `<link>` tags). UI label moved to "App identity
      & typography".
- [x] **Phase 3**: admins save theme back to the spec via PocketBase
      (React) — `currentAppId` + `rawSpecJson` plumbed through the
      app store; non-admins continue to write per-app `localStorage`.
- [x] **Phase 4**: `themeConfig()` driver method + `ThemeConfig`
      type added to both contracts; conformance scenario s21 verifies
      both parsers produce the same `{base, mode, headerStyle,
      overrides, logo, favicon}` shape from the same spec.
- [x] **Phase 5**: Flutter mirror of admin save-to-spec —
      `AppEngine.loadedAppId` + `rawSpecJson` + `hotReplaceSpec`,
      `LoadedAppsStore.findById`, dual-write in
      [settings_screen.dart](Frameworks/flutter-local/lib/screens/settings_screen.dart#L657)
      to update the spec via `LoadedAppsStore.updateApp` and
      hot-replace the in-memory model so the UI reflects the change
      immediately.

### 2026-04-24 — Docs pass

- [x] [CONTRIBUTING.md](CONTRIBUTING.md) at root — explains the
      monorepo layout (where changes go by blast radius), local
      setup, the `publish.sh` test gate, when to add a conformance
      scenario, the test layers, and PR expectations. Refers to
      ARCHITECTURE / CONVENTIONS / TROUBLESHOOTING rather than
      duplicating.
- [x] [GLOSSARY.md](GLOSSARY.md) at root — one-page reference for
      ODS vocabulary (spec, framework, builder, data source,
      ownership, cascade rename, formula, magic default, off-ramp,
      slug, visibleWhen, conformance scenario, etc.). Each entry
      points to where the concept lives in the spec or code.
- [x] [docs/testing.md](docs/testing.md) — covers all five test
      layers (unit, component, integration, conformance, E2E),
      explains the React E2E folder convention
      (smoke/critical/regression/workflows/accessibility) and what
      goes where, includes the "where does my test go?" decision
      tree.
- [x] Cleaned up pre-monorepo leftovers: moved
      `Specification/CODE_OF_CONDUCT.md` to root; removed the stale
      `Specification/CONTRIBUTING.md`.
- [x] Updated [README.md](README.md) docs map to surface
      CONTRIBUTING / GLOSSARY / docs/testing.md / CONVENTIONS to
      visitors.

### 2026-04-24 — Ownership column auto-schema fix (both frameworks)

- [x] Fixed Flutter `DataStore.setupDataSources` + React
      `DataService.setupDataSources` to auto-append the ownership
      column (`ds.ownership.ownerField`) to a data source's fields
      when `ds.ownership.enabled` is true, unless the builder
      already declared it manually. Each has a small
      `_fieldsWithOwnership` / `fieldsWithOwnership` helper mirroring
      the other. Idempotent on re-runs because `ensureTable` /
      `ensureCollection` handle the "column already exists" case
      non-destructively.
- [x] Removed the `_owner`-in-fields workaround from
      [ownershipPerUser.json](Frameworks/conformance/specs/ownershipPerUser.json) —
      s16 now passes against the canonical spec shape (ownership
      config + no explicit `_owner` field).
- [x] Unblocks bundled examples like
      [team-tasks-app.json](Specification/Examples/team-tasks-app.json)
      which use the canonical shape and would otherwise fail on
      both Flutter (SQLite "no such column") and React (PocketBase
      rejects unknown create fields).

### 2026-04-24 — Path B Session L (cascade parity fix + s20)

- [x] **Fixed cascade-rename parity bug.** Flutter parser no
      longer converts flat-key cascade to nested shorthand — it
      preserves the canonical form as-is. Flutter runtime in
      [AppEngine.executeActions](Frameworks/flutter-local/lib/engine/app_engine.dart)
      now detects flat-key shape and reads `parentField` /
      `childDataSource` / `childLinkField` directly (instead of
      using `cascadeMatchField` as parentField, which broke when
      matchField differed from the renamed field). Legacy nested
      form kept as fallback.
- [x] [ActionHandler](Frameworks/flutter-local/lib/engine/action_handler.dart)
      updated to prefer `cascade.parentField` over its withData-key
      deduction when computing `cascadeOldValue`.
- [x] **s20**: cascade update renames matching children after
      renaming the parent. Uses matchField='id' + withData={name:
      'Projects'} + cascade with explicit parentField='name' — the
      pattern that failed before the fix. Passes on both drivers.
- [x] Updated the legacy-flat-key model test to match the new
      canonical preservation behavior.
- [x] `cascadeRename` capability declared on FlutterDriver; React
      already had it. Conformance total: 19 → 20 scenarios. React
      1145 → 1146; Flutter 808 → 809. Test-count bump also
      reflects the batch-2 integration tests which now compile/run
      against the updated cascade runtime.

### 2026-04-24 — Later list rearrangement (document deferred coverage)

- [x] Moved remaining untested conformance capabilities to the
      Later list with full fix direction: `detail` scenario,
      deepening `tabs` (clickTab primitive) and `chart` (series
      math) from initial-state to behavior, scenario-catalog
      parity check. Each kept as a standalone Later item so the
      Now/Next lists stay focused.

### 2026-04-24 — Path B Session K (s18 chart config + s19 kanban drag)

- [x] **s18**: chart component snapshot preserves `chartType`,
      `title`, and `dataSource` config from spec. Narrow parity check
      — no aggregation math verified. `ChartSnapshot` added to the
      Dart contract; `chart` capability on FlutterDriver.
- [x] **s19**: dragging a kanban card updates the row's status
      field and the kanban snapshot counts shift accordingly.
      Introduced new driver primitive
      [`dragCard(dataSource, rowId, toStatus)`](Frameworks/conformance/src/contract.ts)
      on both OdsDriver contracts; both drivers implement it via the
      PUT data source (or fall back to the kanban's own dataSource).
- [x] `KanbanSnapshot` + `KanbanColumn` added to Dart contract;
      FlutterDriver emits it. `kanban` capability declared on
      FlutterDriver.
- [x] Conformance total: 17 → 19 scenarios. React 1143 → 1145;
      Flutter 806 → 808.

### 2026-04-24 — Path B Session J (s17 tabs initial state)

- [x] **s17**: tabs component snapshot reports labels in spec order
      with the first tab active by default. Pins the tabs snapshot
      contract across both frameworks.
- [x] Added `TabsSnapshot` + `TabsTab` to the Dart contract;
      FlutterDriver now emits a `TabsSnapshot` for `OdsTabsComponent`.
- [x] `tabs` capability declared on FlutterDriver (already on React).
- [x] Conformance total: 16 → 17 scenarios. React 1142 → 1143;
      Flutter 805 → 806.

### 2026-04-24 — Path B Session I (s16 row-level ownership + Flutter schema bug surfaced)

- [x] **s16**: ownership-enabled data source hides rows owned by
      other users. Alice + Bob each register + submit; each sees
      only their own rows in the list snapshot; `dataRows` (the
      god view) sees all rows regardless of session.
- [x] Both drivers' list snapshots now route through
      `queryDataSource` (React store) / `engine.queryDataSource`
      (Flutter) — so `rowCount` reflects what the current user
      would actually see, including ownership filtering. Previously
      both used the raw unfiltered query.
- [x] `auth:ownership` capability declared on FlutterDriver (was
      already on React).
- [x] **Flutter schema bug surfaced** (see Next list) — writing
      s16 revealed that Flutter's DataStore doesn't auto-add the
      `_owner` column for ownership-enabled data sources; the
      insert then fails on SQLite's strict schema. Workaround in
      the scenario spec: declare `_owner` explicitly in `fields`.
- [x] Conformance total: 15 → 16 scenarios. React 1141 → 1142;
      Flutter 804 → 805.

### 2026-04-24 — Path B Session H (s15 summary aggregates + cascade bug surfaced)

- [x] **s15**: summary component `value` resolves aggregate
      expressions (`{COUNT(tasks)}`) against the data source; label
      passes through from spec. Exercises the `summary` capability
      on both drivers and the `AggregateEvaluator` /
      `resolveAggregates` cross-framework equivalence.
- [x] Fixed ReactDriver's `snapshotComponent` summary branch —
      previously read non-existent `s.defaultValue` and returned ''.
      Now uses `s.value` and resolves aggregates via the real
      `AggregateEvaluator`. Added `SummarySnapshot` to the Dart
      contract + `summary` capability on FlutterDriver.
- [x] Seeded-data support added to
      [FakeDataService.setupDataSources](Frameworks/react-web/tests/helpers/fake-data-service.ts) —
      mirrors the real `DataService.setupDataSources` so scenarios
      can declare `seedData` on local data sources.
- [x] **Cascade parity bug surfaced** (see Next list) — writing a
      cascade scenario revealed that React's `handleCascade` and
      Flutter's `AppEngine.executeActions` disagree on which cascade
      shape is canonical. No spec satisfies both. Scenario deferred
      until the bug is fixed; new Next-list item captures the work.
- [x] Conformance total: 14 → 15 scenarios. React 1140 → 1141;
      Flutter 803 → 804.

### 2026-04-24 — Path B Session G (s14 formulas)

- [x] **s14**: formula fields compute from their dependencies and
      update on change. Tests both number formulas (`{quantity} *
      {unitPrice}`) and text interpolation (`{firstName}
      {lastName}`), plus the "any empty dependency → empty result"
      guard both evaluators enforce.
- [x] Both drivers now evaluate formulas in `formValues` using their
      native `evaluateFormula` / `FormulaEvaluator` — the same
      evaluator the form renderer uses, so driver output mirrors
      what a user would see in the UI.
- [x] `formulas` capability declared on both drivers. Conformance
      total: 13 → 14 scenarios. React 1139 → 1140; Flutter 802 → 803.

### 2026-04-24 — Path B Session F (s12 onEnd + s13 update rowAction)

- [x] **s12**: submit action with `onEnd` navigate — pins Bug #2
      fix (universal onEnd). New
      [submitThenNavigate.json](Frameworks/conformance/specs/submitThenNavigate.json).
- [x] **s13**: rowAction with `action: update` writes literal
      `values` to the matched row. Forces both drivers to extend
      `clickRowAction` beyond delete-only — the ReactDriver now
      dispatches update via `executeActions`, the FlutterDriver
      via `engine.executeRowAction`. New
      [rowActionUpdate.json](Frameworks/conformance/specs/rowActionUpdate.json).
- [x] `action:update` capability declared on both drivers.
      Conformance total: 11 → 13 scenarios. React 1137 → 1139;
      Flutter 800 → 802.

### 2026-04-24 — Path B Session E (shared scenario specs)

- [x] Extracted 7 scenario specs to
      [Frameworks/conformance/specs/](Frameworks/conformance/specs/)
      as pure JSON files — the single source of truth for both
      drivers. Kills the "write every scenario spec twice" tax that
      caused the `label` vs `header` parity bug earlier today.
- [x] TS loader at
      [Frameworks/conformance/src/load-spec.ts](Frameworks/conformance/src/load-spec.ts);
      Dart loader at
      [Frameworks/flutter-local/test/conformance/load_spec.dart](Frameworks/flutter-local/test/conformance/load_spec.dart).
      Both read the same bytes.
- [x] Scenario definitions shrank: `scenarios.ts` dropped 260+
      lines, `scenarios.dart` dropped ~270 lines. Run bodies stay
      per-language — the per-driver assertion code is what needs
      to diverge.
- [x] 22 parity tests still green (11 scenarios × 2 drivers).

### 2026-04-24 — Path B Session D (FlutterDriver full parity)

- [x] FlutterDriver ported s06-s11 to full parity with ReactDriver.
      `clickRowAction` (delete), full `visibleWhen` evaluation (field
      + data), `setClock` via a driver-local `_fakeNow` that
      `formValues` lazily consults for `CURRENTDATE`/`NOW` defaults,
      and `login` / `registerUser` / `currentUser` / `logout` wired
      through the real `AuthService` + SQLite `_ods_users` table.
- [x] Driver's `_boot` now only sets `skipAppAuth=true` for
      single-user specs, so multi-user scenarios get proper
      `AuthService.initialize()` — creating `_ods_users` +
      `_ods_user_roles` tables.
- [x] Conformance total: **11 scenarios × 2 drivers = 22 parity
      tests green.** Flutter suite 794 → 800.

### 2026-04-24 — Path B Session C (FlutterDriver MVP + parity bug caught)

- [x] New
      [FlutterDriver](Frameworks/flutter-local/test/conformance/flutter_driver.dart)
      mirroring the Dart contract
      ([contract.dart](Frameworks/flutter-local/test/conformance/contract.dart)),
      scenarios s01-s05 ported
      ([scenarios.dart](Frameworks/flutter-local/test/conformance/scenarios.dart)),
      runner at
      [conformance_test.dart](Frameworks/flutter-local/test/conformance/conformance_test.dart).
- [x] Passes against the real `AppEngine` + SQLite (temp-dir per
      scenario). Flutter suite 789 → 794 tests.
- [x] **First parity bugs caught and fixed:** (a) TS scenario specs
      used `label` on list columns; both React and Flutter parsers
      actually read `header` — TS silently accepted `undefined`,
      Flutter parser threw. Fixed specs to use `header` on both
      sides. (b) Dart `OdsAction` was missing the `level` field
      (TS had it after s03); added to the Dart model + `fromJson`.
- [x] Flutter CI + `publish.sh` gates now include
      `test/conformance`. Parity drift between frameworks will
      block merges.

### 2026-04-24 — Path B Session B (auth in the driver + 2 scenarios)

- [x] New
      [FakePocketBase](Frameworks/react-web/tests/helpers/fake-pocketbase.ts)
      — in-memory stand-in implementing the subset of `pb` that
      `AuthService` touches (authStore, `collection('users')` CRUD
      + `authWithPassword`). Replaces the old `mockPb()` in
      conformance so the real `AuthService` runs against it —
      no parallel auth implementation.
- [x] ReactDriver `login` + `registerUser` wired through
      `AuthService` (was throwing). Role defaults to the spec's
      `auth.defaultRole` when caller omits it.
- [x] **s10** — register then login flow (no auto-login, correct
      credentials succeed, roles populated, logout returns to guest).
- [x] **s11** — login with wrong password returns `false`, session
      untouched; subsequent correct password succeeds.
- [x] Conformance total: 9 → 11 scenarios; React suite 1135 → 1137.

### 2026-04-24 — Path B Session A (ReactDriver stubs + 4 scenarios)

- [x] `clickRowAction` implemented — delegates to
      `executeDeleteRowAction` on the store; resolves non-`_id`
      matchFields by looking up the row first. Non-delete actions
      still throw (MVP scope). Pinned by **s06**
      ([scenarios.ts](Frameworks/conformance/src/scenarios.ts)).
- [x] `visibleWhen` evaluation in snapshots — mirrors the React
      renderer's logic: field-based conditions read form state,
      data-based conditions query the data service for row counts.
      Pinned by **s07** (field) + **s08** (data count).
- [x] `setClock` uses `vi.setSystemTime` + `useFakeTimers`; restored
      on `unmount`. `formValues` now lazily resolves
      `CURRENTDATE`/`NOW` defaults for unset fields using the current
      clock. Pinned by **s09**.
- [x] Conformance total: 5 → 9 scenarios; React suite 1131 → 1135.

### 2026-04-24 — Org-level landing page

- [x] Created `One-does-simply/one-does-simply.github.io` repo with a
      standalone `index.html` — now live at
      <https://one-does-simply.github.io/>. Inherits the indigo/purple
      brand palette from
      [Specification/index.html](Specification/index.html); lists
      active (`ods-pages`) + planned (`ods-chat`, `ods-workflow`,
      `ods-game`) families.
- [x] Updated the org's public URL (`blog` field in the API) to the
      new landing page. Old stale URL
      (`one-does-simply.github.io/Specification/`) is now fully dead
      everywhere: org URL, repo homepages, runtime code.

### 2026-04-24 — Pages migration

- [x] Enabled GitHub Pages on `ods-pages` (main branch, `/` root);
      URL base moves from
      `https://one-does-simply.github.io/Specification/...`
      (stale archived snapshot, can't update) to
      `https://one-does-simply.github.io/ods-pages/Specification/...`
      (tracks `main`).
- [x] Updated 13 tracked files (Flutter + React source, Flutter
      README) — runtime fetches for Examples, Templates, Themes, and
      the Build Helper prompt all point at the new URL. Old URL
      intentionally left to die.
- [x] Seeded
      [Specification/build-helper-prompt.txt](Specification/build-helper-prompt.txt)
      (copy of the Flutter bundled asset) — the URL was a latent 404
      on both old and new deployments; the React "Edit with AI"
      screen had been broken. Now resolves.

### 2026-04-24 — Cross-family setup (Session 2)

- [x] [CONVENTIONS.md](CONVENTIONS.md) at root — documents patterns
      every ODS family should copy (monorepo layout, `publish.sh`,
      TODO/REGRESSION_LOG format, ADR convention, CI pattern,
      CLAUDE.md) and what stays per-family. Calls the duplicate-
      don't-extract decision explicitly.
- [x] `One-does-simply/.github` repo created with
      `profile/README.md`. Visitors landing on
      [github.com/One-does-simply](https://github.com/One-does-simply)
      now see an ODS family overview with active/planned siblings.

### 2026-04-24 — Public polish pass (Session 1)

- [x] Root `LICENSE` (MIT) — mirrors
      [Specification/LICENSE](Specification/LICENSE). Fixes "No
      license" label visitors see in the GitHub sidebar.
- [x] Root [SECURITY.md](SECURITY.md) — points to private
      vulnerability reporting + lays out scope.
- [x] README rewritten to reflect monorepo reality (dropped the
      "three sibling repositories" framing) + CI badges + framing as
      first family in the ODS ecosystem
      ([README.md](README.md)).
- [x] Repo description + 8 topics set via `gh repo edit`
      (`spec-driven`, `low-code`, `react`, `flutter`, `pocketbase`,
      `typescript`, `dart`, `monorepo`) — improves discoverability.
- [x] Flutter CI aligned with `publish.sh`: runs
      `test/engine test/models test/parser test/integration
      --exclude-tags=slow` instead of the whole tree. Widget tests
      were hanging on GH Linux runners (same root cause as the
      local Windows skip).

### 2026-04-24 — Monorepo consolidation closed out

- [x] Upstream repos (`Specification`, `Frameworks`, `BuildHelpers`)
      archived on GitHub. Physical consolidation itself landed in
      commit `d5c165e` (2026-04-20) as a single bulk-add rather than a
      history-preserving `git subtree add` — original sub-tree
      histories now live in the archived upstreams.

### 2026-04-24 — TS strict gate restored

- [x] Cleared pre-existing TS errors: `_token` rename in
      [ColorCustomizer.tsx](Frameworks/react-web/src/components/ColorCustomizer.tsx);
      `_app`/`_page` mis-prefix in
      [code-generator.ts](Frameworks/react-web/src/engine/code-generator.ts)
      (8 errors from one signature); `SendOptions` type on the
      `pb.send` wrapper in
      [pocketbase.ts](Frameworks/react-web/src/lib/pocketbase.ts);
      removed dead `cardRotation` helper + unused `rotation` memo in
      [KanbanComponent.tsx](Frameworks/react-web/src/renderer/components/KanbanComponent.tsx).
- [x] Re-added `npx tsc -b` step to
      [.github/workflows/react.yml](.github/workflows/react.yml) so
      type regressions block CI.

### 2026-04-24 — Root-level CI workflows

- [x] Moved Flutter + React workflows to root `.github/workflows/`
      ([flutter.yml](.github/workflows/flutter.yml), [react.yml](.github/workflows/react.yml)).
      The nested copies under `Frameworks/*/.github/workflows/` were
      orphaned after the monorepo consolidation (GitHub Actions only
      reads workflows from repo-root `.github/workflows/`) — neither
      framework had working CI. Adjusted paths for the new layout
      (single checkout, no separate Specification clone).
- [x] Flutter workflow excludes `slow`-tagged Batch 9 perf tests
      (`flutter test --exclude-tags=slow`) so I/O-bound perf tests
      don't flake the gate on cold runners.
- [x] React E2E job preserved (Playwright + PocketBase via
      `tests/e2e/global-setup.ts`).

### 2026-04-23 — Small-win sweep

- [x] `OdsAction` parser preserves `level` on `showMessage`
      ([ods-action.ts](Frameworks/react-web/src/models/ods-action.ts));
      conformance s03 tightened to assert `level: 'success'`; driver
      dropped its unsafe cast
      ([react-driver.ts](Frameworks/react-web/tests/conformance/react-driver.ts)).
- [x] Batch 9 perf tests tagged `slow` via library-level `@Tags(['slow'])`
      in [batch9_performance_test.dart](Frameworks/flutter-local/test/integration/batch9_performance_test.dart);
      `dart_test.yaml` declares the tag; `publish.sh` runs with
      `--exclude-tags=slow`.
- [x] Stale `A couple of comments.txt` TODO entry removed (file was
      already gone).
- [x] `appPrefix` isolation unit tests — pin the multi-app collection
      contract at the real `DataService` boundary
      ([data-service.test.ts](Frameworks/react-web/tests/unit/engine/data-service.test.ts)).
- [x] `LoginScreen` signup-clears-both-gates regression test — renders
      `<LoginScreen>` with `needsAdminSetup=true`, runs signup,
      asserts both `needsLogin` and `needsAdminSetup` clear; failure
      path leaves gates intact
      ([LoginScreen.test.tsx](Frameworks/react-web/tests/component/screens/LoginScreen.test.tsx)).
- [x] `pocketbase.ts` module-init guard — source-level test fails if
      `pb.authStore.clear()` creeps back into
      [pocketbase.ts](Frameworks/react-web/src/lib/pocketbase.ts)
      ([pocketbase.test.ts](Frameworks/react-web/tests/unit/lib/pocketbase.test.ts)).

### 2026-04-19 — Batch 8 E2E + gap closure + storage/auth infra + docs pass

- [x] Batch 8: 22 Playwright regression tests on real PB (see
      [REGRESSION_LOG.md](REGRESSION_LOG.md))
- [x] Automated PB startup in Playwright globalSetup — no manual steps
- [x] PB `users` collection auto-create
      ([AuthService.ensureUsersCollection](Frameworks/react-web/src/engine/auth-service.ts))
- [x] Fixed LoginScreen `needsAdminSetup`-on-signup latent bug
- [x] Kanban drag-and-drop E2E coverage with `data-ods-kanban-*` attrs
- [x] Removed `pb.authStore.clear()` from [pocketbase.ts](Frameworks/react-web/src/lib/pocketbase.ts)
      so admin sessions persist across navigation
- [x] Unified Flutter user list — extracted
      [FrameworkUserList](Frameworks/flutter-local/lib/widgets/framework_user_list.dart),
      removed per-app `_InlineUserList` + `UserManagementScreen`
- [x] `CURRENT_USER.EMAIL` token in Flutter form resolver + `currentEmail`
      on AuthService / FrameworkAuthService
- [x] Storage folder bootstrap + first-run picker + Move Data UX
- [x] OneDrive removal + migration to `c:\Apps\One-does-simply`
- [x] `.claude/settings.json` allowlist tuned (fewer permission prompts)
- [x] Workspace [README.md](README.md) + [ARCHITECTURE.md](ARCHITECTURE.md)
- [x] [docs/adr/](docs/adr/) folder + ADR convention; conformance-driver
      doc lined up as ADR-0001 (physical move deferred until review lands)
- [x] [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — 8 gotchas,
      symptom/cause/fix format
- [x] Per-framework ARCHITECTURE.md for
      [flutter-local](Frameworks/flutter-local/ARCHITECTURE.md) and
      [react-web](Frameworks/react-web/ARCHITECTURE.md)
