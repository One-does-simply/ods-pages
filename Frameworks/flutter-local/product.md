# ODS Flutter Local — Product Overview

## What Is This?

ODS Flutter Local is a cross-platform native app framework that transforms JSON specifications into fully functional applications with local SQLite storage. It is the reference implementation of the **One Does Simply** (ODS) platform.

No internet, no server, no account required. Load a JSON spec and the app is instantly usable with persistent local data.

## Who Is It For?

- **Business teams** needing offline-capable custom tools
- **Developers** building native app prototypes rapidly
- **AI assistants** generating specs via the Build Helper prompt

## Key Capabilities

### App Rendering
- 9 component types: Form, List, Button, Chart, Text, Summary, Detail, Tabs, Kanban
- Dynamic page routing with navigation stack
- Conditional visibility (`visibleWhen` rules)
- Role-based page and component access
- Exhaustive rendering via Dart 3 sealed classes

### Data Management
- SQLite local storage (auto-schema, no migrations needed)
- CRUD operations with form validation
- Row-level ownership and security
- Data export (JSON, CSV, SQL)
- Backup/restore with HMAC integrity verification

### Authentication & Authorization
- Multi-user mode with local user management
- Role-based access control (RBAC): admin, user, guest, custom roles
- Email-based identity (aligned with React Web for portability)
- PBKDF2 password hashing (100,000 iterations) with constant-time verification
- Framework-level auth (separate from per-app auth)
- Session timeout (30 min idle)
- Login rate limiting (5 attempts / 5 min)

### Theming & Branding
- 42 built-in themes (DaisyUI-derived, WCAG AA compliant)
- Light/dark/system mode
- Custom color overrides with contrast validation
- Per-app branding (logo, font, header style)

### Developer Tools
- Debug panel (debug-mode only) with app state inspection
- Structured logging service with file persistence
- Security audit logging (`[SECURITY]` events)
- Code generator: export app as standalone Flutter project

### Administration
- Framework-level admin for managing loaded apps
- App lifecycle: load, switch, remove
- User management with role assignment
- Framework settings (storage, themes)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.6+ |
| Language | Dart 3.6+ |
| State | Provider (ChangeNotifier) |
| Database | SQLite (sqflite + FFI) |
| Charts | fl_chart |
| Design | Material Design |

## Supported Platforms

- Windows
- macOS
- Linux
- iOS
- Android

## Quick Start

```bash
flutter pub get
flutter run             # Run on current platform
flutter run -d windows  # Run on Windows specifically
```

## Commands

| Command | Description |
|---------|-------------|
| `flutter run` | Run in debug mode |
| `flutter run -d windows` | Run on Windows |
| `flutter build windows` | Production build |
| `flutter test` | Run all tests |
| `flutter test --reporter compact` | Compact test output |

## Test Coverage

- **~865 test cases** across engine, models, parser, integration,
  widget, and conformance suites. Widget tests (42) joined the gate
  on 2026-04-26 after a FakeAsync vs sqflite_ffi diagnosis — see
  [`test/widget/_test_harness.dart`](test/widget/_test_harness.dart).
- Per-directory line-coverage thresholds enforced in CI via
  [`tool/coverage_check.dart`](tool/coverage_check.dart) — `lib/engine`
  60%, `lib/models` 85%, `lib/parser` 80%.
- For the canonical, regularly-updated count and full layered breakdown
  see [REGRESSION_LOG.md](../../REGRESSION_LOG.md) and
  [docs/testing.md](../../docs/testing.md).

## Data Storage

Each app gets its own SQLite database file at `~/.ods/ods_<appname>.db`. Columns are TEXT type with auto-schema — tables and columns are created on demand, never dropped. Record IDs (`_id`) are 15-character alphanumeric strings, matching PocketBase's format for cross-framework data portability.

## Project Structure

```
lib/
  main.dart         — App entry point, Provider setup, framework shell
  engine/           — Core services (state, auth, data, evaluators, logging)
  models/           — Pure Dart interfaces for ODS spec types
  parser/           — JSON parsing and validation
  renderer/         — Flutter widgets mapping ODS types to Material UI
  screens/          — Full-page screens (login, settings, admin, help)
  widgets/          — Shared widgets (color picker, theme picker)
  loader/           — Spec loading (file, URL)
  debug/            — Debug panel overlay
test/
  engine/           — Engine service tests
  models/           — Model parsing tests
  parser/           — Parser and validator tests
  regression/       — Example spec validation
assets/
  themes/           — 42 pre-built theme JSON files
  build-helper-prompt.txt — AI Build Helper system prompt
```
