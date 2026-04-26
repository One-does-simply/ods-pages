# Contributing to ODS Pages

Thanks for your interest. ODS Pages is part of the [One Does Simply](https://github.com/One-does-simply)
family of spec-driven frameworks; this repo is the
[`ods-pages`](https://github.com/One-does-simply/ods-pages) family
(specification + Flutter renderer + React renderer + AI build helpers).

This file covers the practical mechanics of contributing here. For the
mental model and architecture, start with [README.md](README.md) and
[ARCHITECTURE.md](ARCHITECTURE.md). For cross-family conventions,
see [CONVENTIONS.md](CONVENTIONS.md).

## What kinds of changes go where

The repo layout determines the blast radius of a change. Most changes
touch one of these:

- **Specification change** — adding a field type, an action, or a
  component kind. Touches [Specification/](Specification/) and almost
  always *both* renderers (`Frameworks/flutter-local/` and
  `Frameworks/react-web/`). Should land as a single atomic commit
  with a matching conformance scenario (see below).
- **Framework change** — bug fix, refactor, or feature inside a
  single renderer. Touches one of `Frameworks/flutter-local/` or
  `Frameworks/react-web/`. Usually no spec change; usually no
  cross-framework concern.
- **AI Build Helper change** — touches
  [BuildHelpers/](BuildHelpers/). Independent of the renderers.
- **Docs / tooling** — `README.md`, `docs/`, `publish.sh`, CI
  workflows, etc. Self-contained.

When a change crosses these (e.g., spec + both frameworks +
conformance scenario), keep it as one commit. The
[publish.sh](publish.sh) flow gates this naturally — see below.

## Local setup

Per-framework setup lives in [README.md → Quick start](README.md#quick-start).
Short version:

- **React web:** `cd Frameworks/react-web && npm install && npm run dev`
- **Flutter local:** `cd Frameworks/flutter-local && flutter pub get && flutter run -d windows`
- **Both:** see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) if
  PocketBase, Flutter SDK paths, or storage folders trip you up on
  first run.

## The test gate

[publish.sh](publish.sh) is the canonical way to commit + push. It:

1. Runs `flutter test test/engine test/models test/parser test/integration test/conformance --exclude-tags=slow`
2. Runs `npm test` in `Frameworks/react-web/`
3. Stages all changes and creates a commit
4. Pushes to `main`

Use `./publish.sh --status` for a dry-run summary of pending changes.
Use `./publish.sh "msg" --skip-tests` only when a flake is known and
documented. Tests must pass before pushing — that's the whole point.

CI mirrors the same gate (see [.github/workflows/](.github/workflows/)).
If a test passes locally but fails in CI (or vice versa), that
divergence is a bug.

## Conformance scenarios — contract-first

The cross-framework parity contract lives in
[Frameworks/conformance/](Frameworks/conformance/). It is **the**
contract for any behavior that should be observably the same across
both renderers — not coverage applied after the fact.

**The rule:** when you change cross-framework behavior, write the
scenario *before* the implementation. Red on both drivers, then green
on both drivers, in that order. A merged feature without a failing-then-
passing scenario was not built test-first.

The workflow:

1. **Write the spec.** Drop a JSON file into
   [Frameworks/conformance/specs/](Frameworks/conformance/specs/). Both
   runners load from the same bytes — that's how spec divergence is
   prevented.
2. **Write the assertions twice — TS first, Dart mirror.** Add a
   `Scenario` to
   [Frameworks/conformance/src/scenarios.ts](Frameworks/conformance/src/scenarios.ts)
   and the equivalent in
   [Frameworks/flutter-local/test/conformance/scenarios.dart](Frameworks/flutter-local/test/conformance/scenarios.dart).
   If the contract needs a new driver method, add it to both
   `contract.ts` and `contract.dart` *before* implementing.
3. **Run both suites and confirm red.** A scenario that passes
   immediately on an empty implementation is testing the wrong thing.
   `cd Frameworks/react-web && npx vitest run tests/conformance` and
   `cd Frameworks/flutter-local && flutter test test/conformance`.
4. **Implement on each framework until both go green.** Pick the order
   that fits, but don't ship until both drivers pass the same scenario.
5. **Refactor with the contract as a safety net.** The scenario stays;
   internals are free to move.

Concrete recent example: ADR-0002 added theme + customizations
(shipped 2026-04-25/26 across both frameworks; phases 1-5 complete).
The `themeConfig()` driver method, `ThemeConfig` type, and
`s21_theme_config_round_trips` scenario landed alongside the parser
changes — both frameworks were verified against the same assertions
before the migration was considered done.

**When NOT to use conformance:** purely framework-specific concerns
(React's PocketBase wiring, Flutter's SQLite paths, UI rendering
details that have no spec equivalent). Those go in framework-local
unit/component/integration tests. If you can't decide, ask "would two
renderers of the same spec disagree on this?" — if yes, it belongs in
conformance.

## Bug fixes are test-first too

Every bug fix lands with a test that would have failed before the fix.
The rule:

1. **Reproduce as a test first.** Write a failing unit, integration, or
   conformance test that captures the bug's observable symptom — a
   wrong value, a missing component, a divergent behavior between
   renderers. Run it and confirm it fails.
2. **Fix the underlying cause.** Make the test go green.
3. **Don't delete the test after.** It stays as the regression guard.

This is the same red→green flow as new features, applied retroactively.
A bug-fix PR without a failing test that becomes a passing test is
incomplete review-wise; reviewers should ask for the test before
approving.

If the bug crossed framework boundaries (a parity divergence), the
regression test belongs in the conformance suite — see the
[recordSource order parity](TODO.md) note for an example of a parity
bug filed during a contract-first session.

## Tests beyond conformance

- **Unit tests** — small, fast, per-module. React: `tests/unit/`.
  Flutter: `test/engine/`, `test/models/`, `test/parser/`.
- **Component tests** — render React components in isolation
  (`tests/component/`).
- **Integration tests** — exercise multi-module flows (Flutter:
  `test/integration/`).
- **E2E tests (React only)** — Playwright against a real PocketBase
  (`tests/e2e/`). Slower; gated separately in CI.

[REGRESSION_LOG.md](REGRESSION_LOG.md) tracks the test batches that
have been run, the bugs they found, and the fix decisions.
[TODO.md](TODO.md) tracks active work and known gaps.

## Code style

- React: ESLint with the project config (`npm run lint`). Vitest +
  Testing Library for tests; Playwright for E2E.
- Flutter: `dart analyze` (CI runs it with
  `--no-fatal-warnings --no-fatal-infos`). `flutter_lints` baseline.
  Use `flutter format` before committing if your editor doesn't.
- Both: prefer plain functions over deep abstractions. Comment the
  *why* when it isn't obvious; don't comment the *what*.

## Pull request expectations

- Branch from `main`; small, focused changes are easier to review.
- Title: terse summary. Description: motivation + what changed.
- Make sure local tests pass (`./publish.sh --status` then
  `./publish.sh "..."`). Don't push around the test gate without a
  reason in the PR description.
- For cross-framework changes, name the parity guarantee in the PR
  body (e.g., "covered by new conformance scenario s21"). For
  framework-specific changes, mention which framework.

## Reporting bugs and proposing features

- File issues in the [ods-pages repo](https://github.com/One-does-simply/ods-pages/issues).
- Bug reports: clear title, steps to reproduce, expected vs actual,
  and which framework(s) are affected. If you can isolate it to a
  spec, attach the spec.
- Feature proposals: explain why it fits the ODS mantra of "complexity
  is the framework's job, simplicity is the builder's experience."
  Most rejections come from over-flexibility leaking into the spec.

## Code of Conduct

By participating you agree to follow the
[Contributor Code of Conduct](CODE_OF_CONDUCT.md).
