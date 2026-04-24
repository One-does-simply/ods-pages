# ODS TODO

Companion to [REGRESSION_LOG.md](REGRESSION_LOG.md) (test batches + bugs found).
Loose rules: drop things in freely, re-sort when you revisit. Link to code
paths the same way REGRESSION_LOG does so the list doubles as a jump-table.

---

## Now — actively being worked on

- [ ] **Path B — FlutterDriver + remaining driver surface** — Phase A
      MVP landed (ADR-0001 accepted; `OdsDriver` contract + 5 passing
      conformance scenarios in
      [Frameworks/conformance/](Frameworks/conformance/); ReactDriver at
      [Frameworks/react-web/tests/conformance/react-driver.ts](Frameworks/react-web/tests/conformance/react-driver.ts)).
      Remaining work: (a) FlutterDriver in Dart mirroring the same
      surface, (b) fill in the MVP driver's "not yet implemented"
      corners (`clickRowAction`, `login`, `registerUser`, real
      `setClock`, proper `visibleWhen` evaluation in snapshots),
      (c) port more Batch 1–6 scenarios into conformance format.
- [ ] **Consolidate to `ods-pages` monorepo** — current three repos
      (`Specification`, `Frameworks`, `BuildHelpers`) + homeless
      workspace docs collapse into a single new `ods-pages` monorepo
      via `git subtree add` (preserves history). Name locks in the
      family-centric structure for the future ODS ecosystem
      (`ods-pages`, `ods-chat`, `ods-workflow`, `ods-game`). Umbrella
      `ods` repo is deferred until a second family appears and there's
      actual cross-family content to host. Transition plan captured in
      the git-structure discussion; ~2-hour dedicated session when
      ready. Blocks: (a) docs being backed up, (b) atomic
      cross-framework commits (important for Path B conformance work).

## Next — next 1–2 sessions

- [ ] **Flutter CI workflow** — GitHub Actions running
      `flutter test test/engine test/models test/parser test/integration`
      on Linux (where the widget-test harness hang doesn't apply). React
      side already has [.github/workflows/test.yml](Frameworks/react-web/.github/workflows/test.yml);
      Flutter side has none. Single highest-ROI item.

## Docs — priority 3 (pre-public polish)

- [ ] **Workspace-root `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`** —
      Specification repo has them; workspace root doesn't. Only matters
      when this workspace itself goes public as a monorepo-style view.
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

- [ ] **Windows widget-test unskip** — all 10 Flutter widget tests are
      skipped on Windows due to a `flutter_tools` temp-dir race (AV/FS
      interference). Options: (a) migrate widget tests to `integration_test`
      which uses a real device/emulator, (b) run them in WSL. Tests pass
      cleanly on Linux/macOS.
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
