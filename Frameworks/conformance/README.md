# ods-conformance

Cross-framework conformance driver contract + parity scenarios for ODS.

**Design:** [../../docs/adr/0001-conformance-driver-contract.md](../../docs/adr/0001-conformance-driver-contract.md)
(ADR-0001, accepted 2026-04-19).

## What lives here

- `src/contract.ts` — the `OdsDriver` interface every renderer must
  implement, plus the framework-neutral `ComponentSnapshot` types
  returned by driver observation methods.
- `src/capabilities.ts` — the flat set of capability tags. Drivers
  declare which capabilities they support; scenarios declare which
  they need.
- `src/scenarios.ts` — the shared library of parity scenarios. Each
  scenario is a closure taking an `OdsDriver` and performing actions +
  assertions. The runner is framework-specific (see below).

## What does NOT live here

- Any actual driver. Each renderer ships its own driver adapter. The
  React driver lives in
  [`Frameworks/react-web/tests/conformance/`](../react-web/tests/conformance/);
  the Flutter driver will land in
  [`Frameworks/flutter-local/test/conformance/`](../flutter-local/)
  (dart source, separate scenario library per the Phase A plan).
- Scenario runners. Each driver's host package wires scenarios into
  its test framework (vitest for React, `flutter test` for Flutter).

## Phase A status (current)

- TypeScript contract + scenarios live here.
- React driver consumes them in-process.
- Flutter driver uses a Dart-transpiled mirror of the scenarios (Phase
  A decision — see ADR-0001 §9).

Phase B will consolidate via JSON-RPC so Dart and TS share one
scenario library over the wire.

## Adding a scenario

1. Pick a capability set (`core` always applies; add feature tags as
   needed — see `src/capabilities.ts`).
2. Author the scenario in `src/scenarios.ts` — a `Scenario` object
   with `name`, `spec`, `capabilities`, and `run(driver)`.
3. Run `npm test` in `Frameworks/react-web/` — vitest picks up the
   new scenario via the conformance test file and runs it against
   the React driver.
4. Mirror to Dart when touching Flutter (Phase A sync is manual;
   Phase B fixes this).

## Why this lives outside the renderer packages

Because it's the contract, not any one renderer. When the ODS spec
goes public and 3rd-party renderers appear, this package is what they
pull to prove conformance. Keeping it framework-agnostic from day one
is the bet.
