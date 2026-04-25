# One Does Simply (ODS) — Pages

[![Flutter](https://github.com/One-does-simply/ods-pages/actions/workflows/flutter.yml/badge.svg)](https://github.com/One-does-simply/ods-pages/actions/workflows/flutter.yml)
[![React](https://github.com/One-does-simply/ods-pages/actions/workflows/react.yml/badge.svg)](https://github.com/One-does-simply/ods-pages/actions/workflows/react.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**ODS is an open spec plus multiple renderers for simple, data-driven
apps.** A *builder* writes a JSON spec describing pages, forms, lists,
charts, and actions; a *framework* renders it as a fully functional
application with persistence, auth, and a polished UI.

The philosophy: *complexity is the framework's job, simplicity is the
builder's experience.*

This repository — `ods-pages` — is the first family in the ODS
ecosystem. Future families (`ods-chat`, `ods-workflow`, `ods-game`)
will live in sibling repositories under the same org.

## Repository layout

Everything lives in a single monorepo so the spec and its renderers
stay in lockstep.

| Folder                                                 | Purpose                                                    | Audience                        |
| ------------------------------------------------------ | ---------------------------------------------------------- | ------------------------------- |
| [Specification/](Specification/)                       | The ODS spec — schema, examples, templates, themes, docs   | spec authors, all renderers     |
| [Frameworks/flutter-local/](Frameworks/flutter-local/) | Flutter renderer with local SQLite storage                 | desktop + mobile users          |
| [Frameworks/react-web/](Frameworks/react-web/)         | React web renderer backed by PocketBase                    | web users, admin builders       |
| [Frameworks/conformance/](Frameworks/conformance/)     | Cross-framework parity driver + scenarios                  | renderer implementers           |
| [BuildHelpers/](BuildHelpers/)                         | AI-assistant prompts that help authors write specs         | spec authors (via Claude/GPT)   |
| [docs/](docs/)                                         | Architecture decisions, troubleshooting, ADRs              | anyone digging in               |

For the mental model — how these fit together, how data flows — see
[ARCHITECTURE.md](ARCHITECTURE.md).

## Quick start

### Run the React web framework locally

```bash
cd Frameworks/react-web
npm install
npm run dev            # Vite dev server on http://localhost:5173
```

You'll need PocketBase running on `127.0.0.1:8090` for data/auth. For
E2E tests PocketBase is auto-managed; for manual dev download v0.25.9
from <https://pocketbase.io/> and run `pocketbase serve`.

### Run the Flutter local framework

```bash
cd Frameworks/flutter-local
flutter pub get
flutter run -d windows      # or macos, linux, ios, android
```

The framework stores data locally (SQLite under a user-chosen folder;
see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for the
storage-folder bootstrap mechanism).

### Run tests

```bash
# React: unit + component
cd Frameworks/react-web && npm test

# React: E2E (auto-starts PocketBase)
cd Frameworks/react-web && npx playwright test --project=chromium

# Flutter: everything except @slow perf tests
cd Frameworks/flutter-local && flutter test --exclude-tags=slow
```

For current test counts, batches, and known skips see
[REGRESSION_LOG.md](REGRESSION_LOG.md).

## Documentation map

| If you want to...                          | Read                                                                       |
| ------------------------------------------ | -------------------------------------------------------------------------- |
| Understand how ODS is structured           | [ARCHITECTURE.md](ARCHITECTURE.md)                                         |
| Write an ODS spec for your own app         | [Specification/README.MD](Specification/README.MD)                         |
| Contribute a renderer or framework change  | [CONTRIBUTING.md](CONTRIBUTING.md) + per-framework `ARCHITECTURE.md`       |
| Look up an ODS term                        | [GLOSSARY.md](GLOSSARY.md)                                                 |
| Add or run tests                           | [docs/testing.md](docs/testing.md)                                         |
| Diagnose a strange error                   | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)                         |
| See cross-family conventions               | [CONVENTIONS.md](CONVENTIONS.md)                                           |
| See what's planned next                    | [TODO.md](TODO.md)                                                         |
| Review design decisions                    | [docs/adr/](docs/adr/)                                                     |
| See the test history + bugs found          | [REGRESSION_LOG.md](REGRESSION_LOG.md)                                     |

## Working on this monorepo

- **Publishing changes:** the [publish.sh](publish.sh) script at the
  repo root stages, tests, commits, and pushes. Use
  `./publish.sh --status` for a dry run.
- **Cross-framework parity:** renderers must agree on behavior for the
  same spec. The conformance driver contract
  ([docs/adr/0001-conformance-driver-contract.md](docs/adr/0001-conformance-driver-contract.md))
  is how we enforce that.
- **AI-assisted development:** [CLAUDE.md](CLAUDE.md) pins workflow
  rules for Claude Code sessions. Other assistants can follow the same
  guidelines.

## Status

Pre-1.0. The spec and framework APIs are still evolving. Breaking
changes are captured in [REGRESSION_LOG.md](REGRESSION_LOG.md); a
CHANGELOG will arrive once releases start being cut.

## License

[MIT](LICENSE).
