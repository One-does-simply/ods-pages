# ODS TODO

Companion to [REGRESSION_LOG.md](REGRESSION_LOG.md) (test batches + bugs found).
Loose rules: drop things in freely, re-sort when you revisit. Link to code
paths the same way REGRESSION_LOG does so the list doubles as a jump-table.

---

## Now — actively being worked on

- [ ] **Path B — FlutterDriver + remaining driver surface** — Phase A
      MVP landed (ADR-0001 accepted; 9 passing scenarios in
      [Frameworks/conformance/](Frameworks/conformance/); ReactDriver at
      [Frameworks/react-web/tests/conformance/react-driver.ts](Frameworks/react-web/tests/conformance/react-driver.ts)).
      **Session A landed 2026-04-24**: ReactDriver gained
      `clickRowAction`, real `visibleWhen` evaluation (field + data
      conditions), and real `setClock` (via vitest fake timers) +
      lazy `CURRENTDATE`/`NOW` default resolution; 4 new scenarios
      (s06-s09) pin the behavior. Remaining work: (a) FlutterDriver
      in Dart mirroring the same surface, (b) `login` +
      `registerUser` stubs (needs an auth harness design), (c) port
      more Batch 1–6 scenarios into conformance format.

## Next — next 1–2 sessions

<!-- empty; drop new items here as they come up -->

## Docs — priority 3 (pre-public polish)

- [ ] **Root `CONTRIBUTING.md`** — LICENSE + SECURITY landed
      2026-04-24; CONTRIBUTING still open. Should explain the
      "one monorepo per ODS family" model, the `publish.sh` flow,
      and how to propose spec vs framework changes.
- [ ] **`CHANGELOG.md`** — low value until releases start; relevant
      once the conformance suite pins spec versions.

## Docs — nice-to-haves

- [ ] **`GLOSSARY.md`** — one page defining "spec," "framework,"
      "builder," "data source," "ownership," "cascade rename," "slug"
      in ODS vocabulary. Could also live at the top of ARCHITECTURE.md.
- [ ] **Testing guide per framework** — React E2E has five folders
      (smoke/critical/regression/accessibility/workflows) with no doc
      explaining when to use which. Could fold into a future
      `docs/testing.md`.

## Later — important, not urgent

- [ ] **Widget-test unskip** — the Flutter widget suite is excluded
      from `publish.sh` and the GH CI workflow because it hangs on
      both Windows (flutter_tools temp-dir race, AV/FS interference)
      and on the GH Linux runners (new finding 2026-04-24 — a 21-min
      hang on `ods-pages` commit `406be96`). Options: (a) migrate
      widget tests to `integration_test` which uses a real
      device/emulator, (b) debug the harness hang directly.
- [ ] **Coverage thresholds in CI** — vitest's `test:coverage` already
      exists; pick a baseline after 2–3 stable runs, enforce in CI to
      prevent regression.
- [ ] **Generator code honors SettingsStore** — `code_generator.dart`
      still uses `getApplicationDocumentsDirectory()` directly in its
      emitted code (see [code_generator.dart:475](Frameworks/flutter-local/lib/engine/code_generator.dart#L475)).
      Low priority because the generated app runs on *someone else's*
      machine, but worth revisiting for consistency.

## Wishlist — ideas; not scheduled

- [ ] **Mutation testing** — Stryker (React) / `test_mutation` (Dart).
      Catches "tests exist but don't assert enough." High value eventually;
      premature before the Now/Next items land.
- [ ] **Visual regression tests** for theme rendering. Playwright snapshots
      or Percy. CLAUDE.md flags theming as a historical pain point; worth
      it once the API churn settles.
- [ ] **Property-based tests** — `fast-check` (JS) / `glados` (Dart) for
      the spec parser and formula evaluator. Natural fit for generated
      input spaces; complements Batch 4/6.
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
