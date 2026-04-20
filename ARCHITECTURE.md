# ODS Architecture

This document describes how ODS is structured at the workspace level —
the three-layer mental model, why each layer exists, how data flows
from a spec to a rendered app, and what invariants must hold across
renderers. For contributor-level internals of each renderer, see the
per-framework `ARCHITECTURE.md` in
[Frameworks/flutter-local/](Frameworks/flutter-local/) and
[Frameworks/react-web/](Frameworks/react-web/).

## The three layers

```
                 ┌─────────────────────────┐
                 │    Specification        │   ← the contract
                 │    (JSON schema)        │
                 └──────────┬──────────────┘
                            │ spec.json
                            ▼
              ┌──────────────────────────────┐
              │        Frameworks            │   ← the renderers
              │   ┌──────────┐ ┌──────────┐  │
              │   │ React    │ │ Flutter  │  │
              │   │ (web)    │ │ (local)  │  │
              │   └──────────┘ └──────────┘  │
              └──────────────┬───────────────┘
                             │ rendered UI + data
                             ▼
                ┌──────────────────────────┐
                │      Running App         │
                └──────────────────────────┘

                 ┌─────────────────────────┐
                 │     BuildHelpers        │   ← the assistants
                 │   (AI prompts/tools)    │
                 └─────────────────────────┘
                 assists the builder in producing a valid spec.json
```

### 1. Specification — the contract

The Specification repo defines the JSON format. It has:

- `ods-schema.json` — machine-readable schema
- `spec.md` (in each framework, kept in sync) — human-readable
  reference
- `Examples/` — working apps (todo list, customer feedback, kanban,
  expense tracker, etc.) used both as documentation and as regression
  fixtures
- `Templates/` — starter specs for common app shapes
- `Themes/` — color palettes a spec can reference by name

The spec is **the contract.** Any renderer that claims ODS
conformance must render any valid spec in a way that produces
equivalent observable behavior — not pixel-perfect output, but same
data, same actions, same state transitions. See the
[conformance driver contract](docs/adr/0001-conformance-driver-contract.md)
for how "equivalent" is enforced.

### 2. Frameworks — the renderers

A framework is a runtime that parses a spec and renders it as an app.
Two are implemented today:

**React web** ([Frameworks/react-web/](Frameworks/react-web/))

- React 19 + TypeScript + Vite + Tailwind + shadcn/ui
- State: Zustand
- Persistence: PocketBase (auto-provisions collections per spec)
- Auth: PocketBase native (users collection, OAuth2 optional)
- Deploy target: any static host; PocketBase is the backend

**Flutter local** ([Frameworks/flutter-local/](Frameworks/flutter-local/))

- Flutter 3.x + Dart + Material
- State: Provider (ChangeNotifier)
- Persistence: SQLite via `sqflite` + `sqflite_common_ffi`
- Auth: in-framework (SHA-256 + salt), per-app + framework-wide users
- Deploy target: Windows/macOS/Linux desktop, iOS, Android

Both implement the same spec. That's the whole point — a builder
writes one spec and picks the runtime that fits their target.

### 3. BuildHelpers — the assistants

ODS specs are JSON. Writing them by hand is fine for developers but
friction for the "citizen developer" target audience. BuildHelpers
are AI-assistant prompts (Claude and ChatGPT variants) that turn a
conversational description of an app into a valid spec. They're not
part of the runtime; they're authoring tooling.

## Data flow — from spec to running app

```
spec.json ──▶ parser ──▶ OdsApp model ──▶ engine (state) ──▶ renderer ──▶ DOM / Widgets
                                              │
                                              ▼
                                       DataService / DataStore
                                              │
                                              ▼
                                       PocketBase / SQLite
```

Every framework follows the same pipeline:

1. **Parser** reads the JSON spec, validates against the schema,
   produces an in-memory typed tree (`OdsApp` with `OdsPage`,
   `OdsComponent`, `OdsDataSource`, etc.).
2. **Engine** owns runtime state — current page, form values, loaded
   data, auth session, last message. It reacts to actions (click,
   submit, navigate) by updating state and dispatching to the data
   layer.
3. **Renderer** walks the component tree and draws widgets / DOM. It
   reads engine state and re-renders on change. It does *not* own
   state.
4. **Data layer** — `DataService` in React, `DataStore` in Flutter —
   is the storage abstraction. It provisions collections/tables
   lazily and runs queries/mutations.

The interesting invariant: **the parser's output, the engine's state
shape, and the data layer's I/O are the same across renderers.** Only
the renderer and the data layer's backend are framework-specific.

## Why three repos?

Because they have different release cadences and audiences:

- The **Specification** changes slowly and publicly. Third parties
  (AI assistants, alternate renderers, conformance tools) all depend
  on it. It deserves its own git history and LICENSE.
- The **Frameworks** change fast internally. Multiple of them exist;
  they version independently; they must not block each other.
- **BuildHelpers** are essentially content — prompt files and example
  outputs. They evolve with the spec and don't need their own release
  cycle.

Keeping them in separate git repos lets each move at its own pace
without cross-contamination. The workspace view (this repo root)
just makes local dev pleasant.

## Key invariants

These hold across every renderer. A renderer that violates one is
non-conformant.

1. **The spec is the source of truth for behavior.** No hidden
   feature flags, no "this renderer adds a nice feature." If it's
   not in the spec, it doesn't exist for the user.
2. **Actions are declarative.** A button's `onClick` is a list of
   action objects (`navigate`, `submit`, `update`, `delete`,
   `showMessage`), not imperative code. Every renderer interprets the
   same action list.
3. **Data lives in named data sources, addressed by `dataSource`
   name.** Tables/collections are provisioned automatically; the
   spec author never sees "CREATE TABLE."
4. **Auth uses email as the primary identifier.** Display names and
   usernames are separate. Roles are a simple array on the user
   record. Row-level ownership is opt-in per data source.
5. **Multi-app isolation via `appPrefix`.** The same data-source
   name in two apps does NOT share storage. Every runtime prepends a
   sanitized app prefix to collection/table names.

## Extension points

If you want to add a new component type (e.g., `calendar`, `map`),
the path is:

1. Specify it in [Specification/ods-schema.json](Specification/ods-schema.json)
   and document in each framework's `spec.md`.
2. Add the model type to both frameworks' parsers.
3. Add the renderer widget/component to both frameworks.
4. Add a conformance capability tag (see
   [docs/adr/0001-conformance-driver-contract.md](docs/adr/0001-conformance-driver-contract.md)
   §6) and a parity scenario.

The last step is what keeps the two frameworks honest.

## Related reading

- [docs/adr/0001-conformance-driver-contract.md](docs/adr/0001-conformance-driver-contract.md)
  — how cross-framework parity is enforced
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — gotchas worth
  knowing before you hit them
- [REGRESSION_LOG.md](REGRESSION_LOG.md) — test batches + bugs found
- [docs/adr/](docs/adr/) — architecture decisions with rationale
- Per-framework internals:
  [Frameworks/flutter-local/ARCHITECTURE.md](Frameworks/flutter-local/ARCHITECTURE.md),
  [Frameworks/react-web/ARCHITECTURE.md](Frameworks/react-web/ARCHITECTURE.md)
