# ADR-0001 — Conformance Driver Contract

**Status:** accepted (draft recommendations from §9 adopted)
**Date:** 2026-04-19
**Tracked in:** [TODO.md](../../TODO.md) — *Path B: conformance driver contract*
**Companion:** [REGRESSION_LOG.md](../../REGRESSION_LOG.md) — parity tests land as
a new batch once the first scenarios pass.

---

## 1. Context

ODS is a spec-driven framework with **N renderer implementations** that must
all produce equivalent behavior for any valid spec. Today N=2 (Flutter
local + React web); tomorrow could be Swift/SwiftUI, a terminal UI, or
3rd-party implementations once the spec goes public.

The regression suite so far writes separate tests per framework and
compares behavior by eye. That scales badly and has already let two
cross-framework divergences slip in ([REGRESSION_LOG.md](../REGRESSION_LOG.md)
bugs #5 and #6).

**This contract defines a framework-neutral "driver" interface.** Every
renderer ships an adapter that implements the interface; one shared
scenario library runs against any adapter. Internal parity falls out;
the same contract becomes a public 3rd-party conformance suite when
the spec is ready to be called a "spec."

---

## 2. Goals and Non-Goals

### Goals

1. **Parity by construction.** One scenario, N renderers, exact-equal
   observable outputs. If a test author wants divergent behavior between
   renderers they must declare it explicitly.
2. **Spec-level abstraction.** Tests read like the spec: "fill the
   `email` field of form `signup`," not "find `<input id=email>`." A
   renderer choosing to map `email` onto a `TextField`, a `<input>`, or
   a TUI prompt is none of the test's business.
3. **Cheap 3rd-party adoption.** A new renderer implementer should be
   able to pass the smoke subset in ~1 day of work. The driver surface
   is therefore **as small as we can make it while still covering every
   feature in the spec**.
4. **Stable API.** Driver signatures change via semver; scenarios pin a
   capability set, not a major version.

### Non-Goals

- **Pixel-perfect rendering.** Fonts, spacing, exact color hex values,
  animation timing. Out of scope; renderers are free to diverge on
  presentation.
- **Performance / latency.** Batch 9 perf tests stay per-framework.
- **Platform-native a11y idioms.** ARIA roles on web, MSAA on Windows,
  VoiceOver semantic roles on iOS — each renderer meets its platform's
  a11y contract independently.
- **Error-message wording.** The **presence, severity, and target** of
  an error are asserted; exact text is not.
- **Internal implementation choices.** State stores (Zustand vs Provider
  vs plain setState), data persistence backends (SQLite vs PocketBase
  vs in-memory), routing libraries — none of these are observable
  through the driver and must not be.

---

## 3. Driver Surface

Principle: the driver speaks in **spec vocabulary**. A field is named in
the spec; the driver addresses it by that name. A button has a label in
the spec; the driver clicks it by that label. No framework concepts
(no "widget," no "component instance," no "selector") cross the
boundary.

The surface is split into five groups: **Lifecycle**, **Input**,
**Observation**, **Auth**, **Determinism**.

### 3.1 Lifecycle

```ts
interface Lifecycle {
  /** Load a spec and reach the ready state (first page rendered). */
  mount(spec: OdsSpec): Promise<void>

  /** Tear down. Safe to call after any failure. */
  unmount(): Promise<void>

  /** Clear all app data but keep the spec loaded. Must be faster than
   *  unmount + mount. Used between scenario steps. */
  reset(): Promise<void>

  /** Capabilities the driver implements (see §6). Declared at
   *  construction; scenarios tagged with a missing capability are
   *  skipped, not failed. */
  capabilities: ReadonlySet<Capability>
}
```

### 3.2 Input — user actions

```ts
interface Input {
  /** Set a value on a form field, addressed by the field's spec `name`.
   *  For forms that appear more than once on a page, `formId` is
   *  required; otherwise the single form on the page is implied. */
  fillField(fieldName: string, value: FieldValue, formId?: string): Promise<void>

  /** Click a button, addressed by its visible label. For duplicate
   *  labels, the nth occurrence (0-based) is selected. */
  clickButton(label: string, occurrence?: number): Promise<void>

  /** Click a row-level action in a list. */
  clickRowAction(
    dataSource: string,
    rowId: string,
    actionLabel: string,
  ): Promise<void>

  /** Navigate via a menu item (matches ODS menu[].label). */
  clickMenuItem(label: string): Promise<void>
}

type FieldValue =
  | string        // text, email, multiline, date, datetime, select
  | number        // number
  | boolean       // checkbox
```

> Note: `mount` plus `fillField`/`clickButton` is enough to exercise
> every built-in action (navigate, submit, update, delete, showMessage)
> — scenarios drive those indirectly through the button/menu they're
> attached to. The driver does **not** expose "execute action X
> directly"; that would let tests cheat past spec-level UI.

### 3.3 Observation — what's true right now

```ts
interface Observation {
  /** Identity of the currently shown page. */
  currentPage(): Promise<{ id: string; title: string }>

  /** Structured snapshot of everything on the current page. See §4. */
  pageContent(): Promise<ComponentSnapshot[]>

  /** All rows in a data source, sorted by `_id` asc for determinism.
   *  Filters/sorts currently applied in a list component are NOT
   *  reflected here — this is the authoritative data, not UI state. */
  dataRows(dataSource: string): Promise<Row[]>

  /** Live form field values (what would be submitted if you clicked
   *  submit right now). */
  formValues(formId: string): Promise<Record<string, FieldValue>>

  /** The most recent toast / banner / message emitted by an action.
   *  Returns null if nothing has been emitted since last reset/mount. */
  lastMessage(): Promise<Message | null>
}

interface Message {
  text: string
  level: 'info' | 'success' | 'warning' | 'error'
}

type Row = Record<string, unknown> & { _id: string }
```

### 3.4 Auth

```ts
interface Auth {
  /** Login with email + password. Returns true on success. */
  login(email: string, password: string): Promise<boolean>

  /** Logout. Safe to call when already logged out. */
  logout(): Promise<void>

  /** Create an account (for selfRegistration specs). Returns user id
   *  on success, null on failure. */
  registerUser(params: {
    email: string
    password: string
    displayName?: string
    role?: string
  }): Promise<string | null>

  /** Current authenticated user, or null for a guest session. */
  currentUser(): Promise<UserSnapshot | null>
}

interface UserSnapshot {
  id: string
  email: string
  displayName: string
  roles: ReadonlyArray<string>
}
```

### 3.5 Determinism

```ts
interface Determinism {
  /** Fix "now" for default-value resolution (CURRENTDATE, NOW, +7d). */
  setClock(isoTimestamp: string): Promise<void>

  /** Seed the RNG used for generated IDs / slugs. */
  setSeed(seed: number): Promise<void>
}
```

These MUST be honored by every driver; without them scenarios with
date defaults or relative timestamps aren't cross-run reproducible.

### 3.6 Composed interface

```ts
export interface OdsDriver
  extends Lifecycle, Input, Observation, Auth, Determinism {}
```

---

## 4. Observable State Model

The key design question: *how do we describe "what the user sees" in a
way that is the same across renderers?*

Answer: a **structural snapshot in spec vocabulary**, returned from
`pageContent()`. Each snapshot element is a discriminated union keyed
by `kind`, mirroring ODS component types 1:1 plus runtime state.

```ts
export type ComponentSnapshot =
  | TextSnapshot
  | FormSnapshot
  | ListSnapshot
  | KanbanSnapshot
  | ChartSnapshot
  | ButtonSnapshot
  | SummarySnapshot
  | TabsSnapshot
  | DetailSnapshot

interface BaseSnapshot {
  kind: string
  visible: boolean    // honors visibleWhen, role gates, etc.
}

interface TextSnapshot extends BaseSnapshot {
  kind: 'text'
  content: string     // formula-resolved
}

interface FormSnapshot extends BaseSnapshot {
  kind: 'form'
  id: string
  fields: Array<{
    name: string
    type: FieldType
    label: string
    value: FieldValue | null
    required: boolean
    error: string | null    // validation error attached to this field
  }>
}

interface ListSnapshot extends BaseSnapshot {
  kind: 'list'
  dataSource: string
  columnFields: string[]
  rowCount: number            // rows currently displayed (after filters)
  sortField: string | null
  sortDir: 'asc' | 'desc' | null
  // Row `_id`s in displayed order after the driver applies defaultSort
  // (and any future runtime sort/filter state). Distinct from
  // `dataRows`, which returns the unsorted authoritative view.
  // Empty array when the list has no rows. Added 2026-04-26 alongside
  // s26 (`list defaultSort drives displayed row order`).
  displayedRowIds: string[]
}

interface KanbanSnapshot extends BaseSnapshot {
  kind: 'kanban'
  dataSource: string
  statusField: string
  columns: Array<{ status: string; cardCount: number }>
}

interface ChartSnapshot extends BaseSnapshot {
  kind: 'chart'
  dataSource: string
  chartType: 'bar' | 'line' | 'pie'
  title: string | null
  seriesCount: number
}

interface ButtonSnapshot extends BaseSnapshot {
  kind: 'button'
  label: string
  enabled: boolean
}

interface SummarySnapshot extends BaseSnapshot {
  kind: 'summary'
  label: string
  value: string              // formula-resolved display string
}

interface TabsSnapshot extends BaseSnapshot {
  kind: 'tabs'
  tabs: Array<{ label: string; active: boolean }>
}

interface DetailSnapshot extends BaseSnapshot {
  kind: 'detail'
  dataSource: string
  fields: Array<{ name: string; label: string; value: unknown }>
}
```

**Why not just dump the rendered tree?** Because that's a framework
idiom (React's VDOM, Flutter's element tree, SwiftUI's opaque body).
Structural snapshots are the minimum *shared* vocabulary.

**Why per-component snapshot shape instead of a uniform "props" bag?**
Because scenarios should be able to say `expect(list.rowCount).toBe(3)`
without casting. Type-safe spec-level assertions are the whole point.

**What's deliberately missing from snapshots:**
- Children of nested components as free-form JSX/widget trees.
- Pixel layout, absolute positions.
- Individual row data in lists (use `dataRows()` for that — avoids
  coupling render order to test assertions).
- Tooltips, focus state, hover state (visual feedback, not logical
  state).

**Escape hatch.** Exactly one framework-specific hole: an optional
`raw: unknown` on each snapshot, populated only when a driver opts in.
Tests MUST NOT read `raw` — it exists for debugging and for
renderer-specific follow-up tests, never for conformance scenarios.

---

## 5. Scenario Format

A scenario is a named closure that takes a driver and performs actions +
assertions.

```ts
import { expect } from 'vitest'
import type { OdsDriver, Scenario } from 'ods-conformance'

export const s01_form_submit: Scenario = {
  name: 'form submit inserts a row + shows success message',
  spec: () => ({
    appName: 'Mini Todo',
    startPage: 'home',
    pages: {
      home: {
        component: 'page', title: 'Home',
        content: [
          { component: 'form', id: 'addForm', dataSource: 'tasks',
            fields: [{ name: 'title', type: 'text', label: 'Title', required: true }] },
          { component: 'button', label: 'Save',
            onClick: [
              { action: 'submit', dataSource: 'tasks', target: 'addForm' },
              { action: 'showMessage', message: 'Saved!', level: 'success' },
            ] },
          { component: 'list', dataSource: 'tasks',
            columns: [{ field: 'title', label: 'Title' }] },
        ],
      },
    },
    dataSources: {
      tasks: { url: 'local://tasks', method: 'POST',
        fields: [{ name: 'title', type: 'text' }] },
    },
  }),
  capabilities: ['form', 'list', 'action:submit', 'action:showMessage'],
  run: async (d: OdsDriver) => {
    await d.fillField('title', 'Buy milk')
    await d.clickButton('Save')

    const rows = await d.dataRows('tasks')
    expect(rows).toHaveLength(1)
    expect(rows[0].title).toBe('Buy milk')

    const msg = await d.lastMessage()
    expect(msg?.text).toBe('Saved!')
    expect(msg?.level).toBe('success')
  },
}
```

**Runner responsibilities (not the scenario's):**
- `mount(spec)` before `run`, `unmount()` after
- Skip the scenario if any `capabilities` aren't supported by the driver
- `setSeed(0)` and `setClock('2026-01-01T00:00:00Z')` before each run
- Fail cleanly if the scenario's assertions throw

**Why closures over JSON?**
- JSON steps ("action: fillField, value: X") look portable but force
  every assertion primitive into the step vocabulary. Soon you're
  reinventing expect().
- TS closures are readable, typed, and the scenarios themselves become
  the spec of what "conformant" means.
- **Portability caveat:** a non-JS driver (e.g. a pure-Rust renderer)
  needs an IPC bridge so scenarios can call into it. See §7.

---

## 6. Capabilities and Versioning

A flat set of capability tags, versioned alongside the ODS spec.

```ts
type Capability =
  // Required baseline every conforming driver must support.
  | 'core'             // pages, text, form, button, list, navigate, submit, showMessage

  // Optional feature packs.
  | 'kanban'
  | 'chart'
  | 'tabs'
  | 'detail'
  | 'summary'
  | 'formulas'         // computed fields
  | 'rowActions'       // per-row list actions
  | 'cascadeRename'
  | 'auth:multiUser'
  | 'auth:selfRegistration'
  | 'auth:ownership'   // row-level security

  // Granular action variants.
  | 'action:submit'
  | 'action:update'
  | 'action:delete'
  | 'action:navigate'
  | 'action:showMessage'
```

Drivers declare the capabilities they support; scenarios declare what
they need. The runner takes the intersection.

**Spec versioning** is separate from capabilities. A driver also
declares `supportedSpecVersion` (semver range). Scenarios that use a
newer spec feature set a `requiresSpecVersion` range; drivers not in
range skip.

Keeps the picture clean: the spec version tracks *schema*, the
capability set tracks *runtime behavior*.

---

## 7. Transport — In-Process vs Wire

Two modes, same interface.

### In-process (default, what we build first)

```ts
import { FlutterDriver } from '@ods/driver-flutter'
import { ReactDriver }   from '@ods/driver-react'
import { runScenarios, scenarios } from 'ods-conformance'

for (const driver of [new FlutterDriver(), new ReactDriver()]) {
  runScenarios(driver, scenarios)
}
```

In-process is what the JS/TS side does natively. Dart is the awkward
case — the Flutter driver will expose a JS/TS-compatible adapter that
calls into a Dart runtime. Options:
- Boot the Flutter engine in a test-only headless mode and call into
  it via `package:flutter_test` from a Dart scenario runner.
- Run the React adapter and Flutter adapter in separate processes,
  both scripted by TS.

**Decision (draft):** each driver package ships the native adapter
for its host language. The Flutter adapter's Dart scenario runner
parses the same scenario closures (transpiled to Dart) OR operates
via the wire protocol below. **This is the biggest open question in
the design** — see §9.

### Wire protocol (future, for 3rd-party + non-JS renderers)

A JSON-RPC 2.0 interface over a local websocket. Every driver method
is a request; snapshots are responses. Deliberately boring:

```json
{"jsonrpc":"2.0","id":1,"method":"mount","params":{"spec":{...}}}
{"jsonrpc":"2.0","id":2,"method":"fillField","params":{"fieldName":"title","value":"Buy milk"}}
{"jsonrpc":"2.0","id":3,"method":"pageContent"}
```

Shipping the wire protocol turns "any renderer" into "any renderer
with a 200-line JSON-RPC server." Not for MVP; documented here so the
in-process surface doesn't accidentally box us out of it.

---

## 8. Roll-Out Plan

### Phase A — internal parity (this batch + next)
1. Land this doc (reviewed, merged) as `docs/conformance-driver-contract.md`.
2. Implement `OdsDriver` TypeScript interface in `packages/ods-conformance/src/contract.ts`.
3. Implement `ReactDriver` that adapts the existing `AppEngine` state +
   `DataService` to the interface. In-process; no IPC.
4. Implement `FlutterDriver` in Dart with the equivalent surface. For
   Phase A we accept separate Dart and TS scenario runners that share
   the *spec* of the contract but run locally per language. Revisit
   unification in Phase B.
5. Port 5 of the existing Batch 1–6 scenarios to the new format,
   confirm both drivers pass.
6. A new regression batch (Batch 10: "Parity") lands in
   REGRESSION_LOG.md covering those 5.

### Phase B — language-unification + remainder of suite
1. Decide: JSON-RPC wire protocol vs. transpiled-Dart scenarios.
   (Leaning JSON-RPC; keeps the 3rd-party story on the table.)
2. Port the rest of Batches 1–6 and the "Data interactions" E2E
   scenarios into conformance scenarios.
3. Scenarios move to their own repo / package boundary.

### Phase C — public ecosystem
1. Publish `ods-conformance` + driver contract docs.
2. Conformance badge / self-certification guide.
3. Third-party drivers welcome.

---

## 9. Open Questions (decisions we need from review)

1. **Dart scenario runner** — how do Dart and TS share scenarios in
   Phase A? Three realistic options:
   - (a) Separate scenario libraries per language, maintained in sync
     (simple, brittle).
   - (b) Write scenarios in TS; the Flutter driver runs a JSON-RPC
     server and Dart is never touched by the test author (adds
     transport to Phase A).
   - (c) Start with (a), move to (b) in Phase B.
   *Draft recommendation: **c**. Pay the coordination cost upfront to
   get parity coverage quickly, wire-protocol later.*

2. **`raw` escape hatch — ship it from day one, or not?** Opinion
   splits possible: present it and tests will (eventually) misuse it;
   omit it and debugging conformance failures gets harder.
   *Draft recommendation: **omit from MVP**, add under the name
   `debugInspect()` in a separate `DebugDriver` mix-in once we know
   which callers actually need it.*

3. **Row identification in `clickRowAction`** — `rowId` assumes PB-ish
   string ids. Some future driver might use integer or composite keys.
   *Draft recommendation: keep `rowId: string` for MVP; document that
   drivers stringify native ids. Composite keys warrant a new method if
   they ever appear.*

4. **"Page snapshot order vs rendered order."** Scenarios that say
   "the list is below the form" — do we preserve that ordering in
   `pageContent()`? *Draft recommendation: **yes**, snapshots preserve
   the spec's `content[]` order exactly.*

5. **OAuth2 scenarios** — the driver surface doesn't cover them.
   *Draft recommendation: out of scope for Phase A. Add
   `loginWithOAuth2(provider, ...)` when we have a second renderer
   that supports it.*

6. **Capability naming.** `action:submit` or `submitAction`? Colons
   read nicely but hyphens are safer for shell / filename round-trips.
   *Draft recommendation: `action:submit` in code, never used as a
   filename.*

---

## 10. What this doc doesn't cover (deliberately)

- Build / publish pipeline for the conformance package.
- How scenarios get authored by the community (style guide, PR
  template) — later.
- Performance characteristics of the in-process drivers.
- Migration path for the existing React E2E suite (batch 8) — keep
  those as-is; they exercise the real browser stack, which is a
  different contract.

---

## 11. Review

To review together, focus on:

- **§3 Driver Surface** — is this the smallest surface that can carry
  every existing Batch 1–6 scenario?
- **§4 Observable State Model** — does any existing test need something
  not in a snapshot?
- **§9 Open Questions** — which of the draft recommendations do you
  want to overrule?

Once we agree on §3/§4 and close out §9, the Phase A implementation is
mostly mechanical.
