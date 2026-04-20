# One Does Simply — Workspace

This is the **development workspace** for One Does Simply (ODS) — a
spec-driven application framework. If you just want to learn about
ODS itself, start with the [Specification repo's README](Specification/README.MD).
If you're here to build or contribute to the project, this is the
right place.

## What is ODS?

ODS is an open spec + multiple renderers for simple, data-driven
apps. A **builder** writes a JSON spec describing pages, forms, lists,
charts, and actions; a **framework** renders it as a fully functional
application with persistence, auth, and a polished UI. Today, two
renderers exist: a React web app (PocketBase backend) and a Flutter
local app (SQLite backend).

The philosophy: *complexity is the framework's job, simplicity is the
builder's experience.*

## Workspace layout

Three sibling repositories are cloned under this workspace root. Each
is independently versioned and publishable.

| Folder                     | Purpose                                                              | Audience                      |
|----------------------------|----------------------------------------------------------------------|-------------------------------|
| [Specification/](Specification/)           | The ODS spec — schema, examples, templates, themes, docs | spec authors, all renderers   |
| [Frameworks/flutter-local/](Frameworks/flutter-local/) | Flutter renderer with local SQLite storage               | desktop + mobile users        |
| [Frameworks/react-web/](Frameworks/react-web/)         | React web renderer backed by PocketBase                  | web users, admin builders     |
| [BuildHelpers/](BuildHelpers/)             | AI-assistant prompts that help authors write specs       | spec authors (via Claude/GPT) |

For the mental model — how these fit together, how data flows, why
there are three — see [ARCHITECTURE.md](ARCHITECTURE.md).

## Quick start

### Run the React web framework locally

```bash
cd Frameworks/react-web
npm install
npm run dev            # Vite dev server on http://localhost:5173
```

You'll need PocketBase running on `127.0.0.1:8090` for data/auth. For
E2E tests PocketBase is auto-managed; for manual dev you can download
v0.25.9 from <https://pocketbase.io/> and run `pocketbase serve`.

### Run the Flutter local framework

```bash
cd Frameworks/flutter-local
"c:/Users/<user>/develop/flutter/bin/flutter.bat" pub get
"c:/Users/<user>/develop/flutter/bin/flutter.bat" run -d windows
```

The framework stores data locally (SQLite under a user-chosen folder;
see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for the
storage-folder bootstrap mechanism).

### Run tests

```bash
# React: unit + component tests
cd Frameworks/react-web && npm test

# React: E2E tests (auto-starts PocketBase)
cd Frameworks/react-web && npx playwright test --project=chromium

# Flutter: engine + model + parser + integration tests
cd Frameworks/flutter-local
"c:/Users/<user>/develop/flutter/bin/flutter.bat" test \
    test/engine test/models test/parser test/integration
```

For the current test counts, batches, and known skips see
[REGRESSION_LOG.md](REGRESSION_LOG.md).

## Documentation map

Start here based on what you want to do:

| If you want to...                          | Read                                                   |
|--------------------------------------------|--------------------------------------------------------|
| Understand how ODS is structured           | [ARCHITECTURE.md](ARCHITECTURE.md)                     |
| Write an ODS spec for your own app         | [Specification/README.MD](Specification/README.MD)     |
| Contribute a renderer or framework change  | [ARCHITECTURE.md](ARCHITECTURE.md) + the per-framework `ARCHITECTURE.md` |
| Diagnose a strange error                   | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)     |
| See what's planned next                    | [TODO.md](TODO.md)                                     |
| Review design decisions                    | [docs/adr/](docs/adr/)                                 |
| See the test history + bugs found          | [REGRESSION_LOG.md](REGRESSION_LOG.md)                 |

## Working on this workspace

- **Cross-repo commits:** the `publish.sh` script at the workspace
  root stages, tests, commits, and pushes all three sub-repos. See
  `./publish.sh --status` for a dry run.
- **Cross-framework parity:** renderers must agree on behavior for
  the same spec. The conformance driver contract
  ([docs/adr/0001-conformance-driver-contract.md](docs/adr/0001-conformance-driver-contract.md))
  is how we enforce that — draft under review.
- **AI-assisted development:** [CLAUDE.md](CLAUDE.md) pins workflow
  rules for Claude Code sessions. Other assistants can follow the
  same guidelines.

## Status

Pre-1.0. The spec and framework APIs are still evolving. Breaking
changes are captured in [REGRESSION_LOG.md](REGRESSION_LOG.md) and
will get a CHANGELOG once releases start being cut.

The Specification sub-repo is MIT-licensed
([Specification/LICENSE](Specification/LICENSE)). Frameworks and
BuildHelpers will inherit the same license when published; see
[TODO.md](TODO.md) for the pre-public polish list.
