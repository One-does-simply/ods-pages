# Glossary

Vocabulary used across ODS. Each entry points to where the concept
lives in the spec or code. If a term is missing, propose it in a PR.

### Builder

The person writing an ODS spec for an application. Usually a citizen
developer or domain expert, not a software engineer. Contrast with
*framework implementer* (someone working on the renderers themselves).

### Cascade rename

When a parent record's identifying field is updated, ODS can
propagate the new value to all linked rows in child data sources.
Configured on an `update` action via the `cascade` map. Canonical
shape: `{childDataSource, childLinkField, parentField}` (flat keys).
See [CONVENTIONS.md](CONVENTIONS.md) for cross-family conventions and
the cascade conformance scenario for behavior pinning.

### Component

A renderable unit on a page. `form`, `list`, `button`, `text`,
`kanban`, `chart`, `summary`, `tabs`, `detail`. Defined in
[Specification/](Specification/); rendered by both frameworks. Not
every spec uses every component.

### Conformance scenario

A `(name, spec, capabilities, run)` tuple in
[Frameworks/conformance/](Frameworks/conformance/) that runs
identically against every renderer. Each scenario asserts an
observable behavior (e.g., "form submit inserts a row," "ownership
hides other users' rows"). Drivers that don't declare the required
capabilities skip the scenario. The contract is documented in
[docs/adr/0001-conformance-driver-contract.md](docs/adr/0001-conformance-driver-contract.md).

### Data source

A named handle for one logical table, declared under
`dataSources` in a spec. Has a `url` (typically `local://tableName`),
a `method` (`GET` / `POST` / `PUT` / `DELETE`), optional `fields`,
optional `seedData`, and optional `ownership` config. Multiple data
sources can share a URL with different methods (e.g., `tasksReader`
for GET, `tasksWriter` for POST + PUT).

### Driver (conformance)

A renderer-specific adapter that implements the
[`OdsDriver`](Frameworks/conformance/src/contract.ts) contract so
conformance scenarios can drive that renderer the same way. Today:
[ReactDriver](Frameworks/react-web/tests/conformance/react-driver.ts)
and [FlutterDriver](Frameworks/flutter-local/test/conformance/flutter_driver.dart).

### Family (ODS family)

A self-contained ODS world with its own spec schema and renderers.
Each family lives in its own monorepo: `ods-pages` (this repo) for
data-driven page apps; `ods-chat`, `ods-workflow`, `ods-game`
planned. See [CONVENTIONS.md](CONVENTIONS.md) and the
[org landing](https://one-does-simply.github.io/).

### Formula

A computed field value evaluated at render time from other fields
in the same form. `{quantity} * {unitPrice}` for number fields,
`{firstName} {lastName}` for text. Read-only; not persisted.
Implemented by `formula-evaluator.ts` (React) /
`FormulaEvaluator` (Flutter); both must produce the same output for
the same input — pinned by conformance scenario s14.

### Framework

A renderer that turns an ODS spec into a running application.
`Frameworks/flutter-local/` (Flutter + SQLite, single-user-on-device)
and `Frameworks/react-web/` (React + PocketBase, multi-user web).
Sometimes used interchangeably with *renderer*.

### Local data source

A data source whose `url` starts with `local://`. The framework
manages persistence — SQLite on Flutter, PocketBase on React. The
suffix after `local://` is the table/collection name.

### Magic default

A `default` value on a field that the renderer expands at form-fill
time. Currently: `CURRENTDATE` and `NOW` (resolved using the active
clock); `+7d` / `+1m` for relative dates;
`CURRENT_USER.NAME` / `.EMAIL` / `.USERNAME` for the logged-in user.
Pinned by conformance scenario s09 for date defaults.

### Multi-user

A spec with `auth.multiUser: true`. Triggers user-account flows:
admin setup, login, optional self-registration, role-based access.
Single-user specs (the default) skip all of this.

### Off-ramp

ODS's anti-lock-in promise: when a builder outgrows the framework,
they can export their data and generate real source code (a complete
Flutter or React project) they own outright. Implemented by
[data_exporter.dart](Frameworks/flutter-local/lib/engine/data_exporter.dart)
and [code_generator.dart](Frameworks/flutter-local/lib/engine/code_generator.dart).

### Ownership

Row-level security on a data source. With `ownership.enabled: true`,
inserts auto-tag rows with the current user id and reads filter to
the current user's rows (admins see all if `adminOverride: true`).
The owner column (default `_owner`) is auto-added to the schema by
`setupDataSources`. Pinned by conformance scenario s16.

### Renderer

Synonym for *framework* in the implementation sense. The thing that
takes a spec and turns it into pixels.

### Row action

An action attached to each row of a list (or kanban card). Examples:
"Mark Done" (update), "Delete" (delete), "Copy" (copyRows). Defined
in `list.rowActions[]`. Pinned by conformance s06 (delete) + s13
(update).

### Slug

The URL-safe identifier of a loaded app inside a multi-app
framework. React derives the slug from the app name; the React
homepage routes to `/<slug>/...`. Internal to the renderer; not
part of the spec.

### Spec

A JSON file describing an ODS application — its pages, components,
data sources, actions, and (optionally) auth + theming. The schema
is documented in `Frameworks/react-web/spec.md`. Builders typically
work in JSON directly or have an AI Build Helper draft it.

### Tour

An optional array of guided tour steps in a spec
(`tour: [{title, content, page}]`). Renderers display these as a
walkthrough overlay on first launch. Distinct from `help`, which is
an always-available reference.

### VisibleWhen

A conditional visibility rule on any component. Two shapes:
field-based (`{form, field, equals|notEquals}`) and data-based
(`{source, countEquals|countMin|countMax}`). Pinned by conformance
scenarios s07 (field) and s08 (data count). Defined in
[ods-visible-when.ts](Frameworks/react-web/src/models/ods-visible-when.ts) /
[ods_visible_when.dart](Frameworks/flutter-local/lib/models/ods_visible_when.dart).
