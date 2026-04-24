# Conformance specs — single source of truth

Each file here is an ODS JSON spec used by one or more conformance
scenarios. **Both the TypeScript and Dart scenario runners read from
these files at test time** — don't keep parallel literals in the
language-specific scenario code.

## Why centralized

Before this split, each scenario's spec was duplicated in
`scenarios.ts` and `scenarios.dart`. That caught a real parity bug
(TS specs used `label` on list columns, both React and Flutter parsers
actually read `header`) but also represented a maintenance tax: every
new scenario had to be written twice.

Moving specs here makes the spec literally the same bytes both sides
load. Parity bugs that remain in scope are at the **parser** or
**driver** level — which is exactly what conformance is meant to
surface.

## Conventions

- One file per named spec; filename (minus `.json`) is the key both
  sides use to load it.
- Keep files human-readable: 2-space indent, `"property": "value"` form,
  nested arrays on their own lines when they cross 80 columns.
- Only add new spec files when a scenario needs a shape not already
  present. Prefer reusing specs across scenarios where the shape fits.
- Scenario `run` bodies still live per-language (in `scenarios.ts` and
  `scenarios.dart`) — they're tightly coupled to each driver's API.
