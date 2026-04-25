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

## Conformance scenarios

The cross-framework parity contract lives in
[Frameworks/conformance/](Frameworks/conformance/). When you change
behavior that should be observably the same across both renderers,
**add a conformance scenario**. The pattern:

1. Drop the spec into [Frameworks/conformance/specs/](Frameworks/conformance/specs/)
   as JSON. Both runners load from this single source.
2. Add a `Scenario` to
   [Frameworks/conformance/src/scenarios.ts](Frameworks/conformance/src/scenarios.ts)
   with the assertions the React side runs.
3. Add a mirroring `Scenario` to
   [Frameworks/flutter-local/test/conformance/scenarios.dart](Frameworks/flutter-local/test/conformance/scenarios.dart)
   with the same assertions in Dart.
4. Verify both run green.

Conformance has caught real cross-framework bugs already — every new
scenario adds future regression coverage and exposes drift early.

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
