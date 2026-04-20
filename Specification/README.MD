# One Does Simply (ODS) - Vibe coding with guardrails

> "One does not simply do complex things, but One Does Simply do simple things."

## What is ODS?

One Does Simply (ODS) is an open-source project dedicated to a simple truth: simple applications can and should be defined simply. ODS provides a clear, concise specification for defining simple, data-driven applications using a JSON file.
This specification can then be rendered by any compatible Framework, giving citizen developers the power to create useful applications without getting bogged down by the complexities of UI/UX design, proprietary ecosystems, or vendor lock-in.

## The ODS Philosophy: Simple for the Builder

The word "simply" in ODS refers to the experience of the person building the app — the citizen developer. The spec should be easy to write, easy to understand, and easy to hand to someone else. That's the contract.

What happens behind the scenes is a different story. Frameworks are free — and encouraged — to be as sophisticated as they need to be. A builder who writes `"type": "date"` in a form field shouldn't have to think about date pickers, localization, or storage formats. The framework handles all of that. A builder who adds a `"list"` component shouldn't have to worry about pagination, empty states, or responsive layout. The framework takes care of it.

This is the core design principle: **complexity is the framework's job, simplicity is the builder's experience.** The more the framework can do automatically, the simpler the spec stays — and the more capable citizen developers become without needing to learn more. A powerful framework paired with a simple spec is not a contradiction; it's the whole point.

## The Problem

Many low-code and no-code platforms fail for a few key reasons:
 * They try to do too much. They start simple but quickly add overwhelming complexity.
 * They expect users to be designers. Good UI/UX is incredibly difficult, yet most platforms leave it to the user.
 * They create lock-in. Moving an application out of a proprietary ecosystem often means starting over from scratch.
 * They trap your data. Data is often held in expensive, proprietary data stores that are difficult to access or migrate.

Recently, many citizen developers are trying to build apps by "vibe coding" with AI. This creates another set of problems:
 * AI agents build things the citizen developer may not understand
 * AI agents build things that may not be safe
 * AI agents build things using technologies that simply may not be conducive to citizen development

Simply put, vibe coding lacks guardrails.

## The ODS Solution

ODS solves these problems by separating concerns into a clear, four-part ecosystem:
 * **The Specification:** A simple, open-source JSON schema that defines the structure and logic of an application. It's the universal blueprint. The spec stays deliberately simple — it describes *what* the app does, not *how* to render it. This is what keeps building accessible.
 * **Frameworks:** Real-time renderers for the ODS specification. A framework handles the complex parts — UI/UX, security, data management, accessibility, and platform adaptation — so the citizen developer never has to. The framework is where sophistication lives: smart defaults, polished interactions, and professional-quality output, all driven by a spec the builder can read in five minutes. Frameworks also provide an "off-ramp" code-generation feature that generates professional source code, ensuring you are never locked in.
 * **Templates:** Pre-built app patterns that turn building into a quick Q&A. A template combines a short wizard (3-5 questions) with a JSON-e template body that renders into a complete ODS spec. Pick a template, answer a few questions — like "What are you tracking?" and "What fields do you need?" — and your app is ready in seconds. No AI required, no JSON editing. Templates use the JSON-e templating language for portability across frameworks.
 * **The Build Helper:** A conversational AI tool that guides users through the process of creating an ODS JSON file, turning their ideas into a well-structured application definition. It's like vibe coding but with guardrails — the AI can only produce valid ODS specs, so the result is always safe, understandable, and portable.

## Three Ways to Build

ODS offers three paths to creating an app, from fastest to most flexible:

 1. **Quick Build (Templates):** Pick a template, answer a few questions, done. The fastest path — no coding, no AI, just a short wizard. Templates live in the `Templates/` directory. Available templates:

    | Template | Description |
    |----------|-------------|
    | **Simple Tracker** | Track anything with a form, list, and optional charts |
    | **Survey / Feedback** | Collect responses and view aggregate results with charts |
    | **Daily Log** | Date-based journal for diaries, standups, or gratitude logs |
    | **Scoreboard** | Track scores and rankings with charts and summary stats |
    | **Quiz** | Multiple-choice quiz with auto-stepping and scoring |
    | **Directory** | Searchable directory with card layout and detail view |
    | **Approval / Request** | Submit requests and track approvals with color-coded status |
    | **Inventory** | Track items, quantities, and locations with low-stock alerts |
    | **Checklist** | Run inspections with pass/fail tracking and color-coded results |
    | **Master-Detail** | Two related tables — projects & tasks, orders & line items, etc. |
    | **Booking / Sign-up** | Manage reservations or sign-ups with date tracking and status |

 2. **Build Helper (AI):** Describe what you want in plain language and the AI generates a valid ODS spec. More flexible than templates — you can build anything the spec supports. Best for custom apps that don't fit a template pattern. Build Helper prompts are in the `../BuildHelpers/` directory.

 3. **Write JSON directly:** For power users or anyone who wants full control. The spec is small enough to read in five minutes. See `ods-schema.json` for the full schema and `Examples/` for working apps.

## Example Apps

The `Examples/` directory contains 12 working example specs that demonstrate the full range of ODS features:

| Example | Key Features Showcased |
|---------|----------------------|
| **To-Do List** | Row coloring by priority, displayMap, colorMap on columns, row actions |
| **Expense Tracker** | Formula fields (computed totals), currency formatting, aggregate text, validation |
| **Habit Tracker** | Dependent dropdowns (optionsFrom with filter), multiple lists |
| **My Chores** | Master-detail pattern with dependent dropdowns, status coloring |
| **Personal Journal** | Card layout, datetime fields, mood-based row coloring (9 colors) |
| **Reading List** | Row actions with hideWhen conditions, card layout |
| **Recipe Book** | Card layout, searchable lists |
| **Customer Feedback** | Detail component (fromForm), rating system |
| **Team Survey** | Conditional visibility (visibleWhen), aggregate expressions in text |
| **Quiz Master** | Record cursor (firstRecord/nextRecord), computedFields, readOnly fields |
| **Team Wiki** | **Markdown text** rendering, seed data with rich formatted content |
| **Project Dashboard** | **Tabs component**, multiple charts, row coloring by status |

## Feature Overview

ODS specs support the following capabilities:

### Field Types
`text`, `email`, `number`, `date`, `datetime`, `multiline`, `select` (with options), `checkbox`, `hidden` (carries data without rendering), `user` (dropdown of users in multi-user mode, plain text otherwise)

### Components
 * **text** — Static or data-aware text; supports `"format": "markdown"` for rich rendering
 * **form** — Data entry with fields, validation, defaults, formulas, and conditional visibility
 * **list** — Table or card layout with search, sort, filter, row coloring, row actions, and onRowTap navigation
 * **kanban** — Drag-and-drop board view where a select field's options define columns. Cards show configurable fields with a sticky-note aesthetic. Drag between columns auto-updates the status field.
 * **button** — Triggers action chains (navigate, submit, update, showMessage)
 * **chart** — Bar, line, or pie charts from aggregated data
 * **summary** — KPI card with label, aggregate value, and icon
 * **tabs** — Tabbed layout grouping multiple component arrays
 * **detail** — Read-only field/value card from a data source or form state

### Actions
 * `navigate` — Change page, optionally populating a form with row data (`populateForm`)
 * `submit` — POST form data to a data source (creates a new record)
 * `update` — PUT form data to a data source (updates an existing record by `matchField`)
 * `showMessage` — Display a toast/snackbar notification
 * `firstRecord` / `nextRecord` / `previousRecord` / `lastRecord` — Step through records in a form (with optional `filter` and `onEnd` action)

### Data Features
 * `local://` storage convention — all data stays on the user's device
 * `seedData` — Pre-populated rows loaded on first app launch
 * `fields` on dataSources — Explicit table schema (alternative to form-inferred schema)
 * Formula fields — `"formula": "{qty} * {price}"` for computed values (number math or text interpolation)
 * Aggregate expressions — `{SUM(ds, field)}`, `{COUNT(ds)}`, `{AVG(ds, field)}`, `{MIN}`, `{MAX}`, `{PCT}`
 * Data export — Off-ramp: export all app data as JSON, CSV, or SQL

### Layout & Visibility
 * `searchable` lists with full-text search across columns
 * `sortable` columns with tap-to-sort headers
 * `filterable` columns with dropdown filters
 * `defaultSort` — Initial sort order on lists (`{ "field": "date", "direction": "desc" }`)
 * `displayAs: "cards"` for card-based list layout
 * `rowColorField` / `rowColorMap` for color-coded rows
 * `displayMap` / `colorMap` on individual list columns
 * `visibleWhen` — Show/hide components based on form state or data source count
 * `visible` — Expression-based visibility (`{field} == 'value'`)
 * `hideWhen` on row actions — Supports `equals` and `notEquals` for conditional action buttons

### UX
 * `help` — Overview text and per-page help tips
 * `tour` — Guided walkthrough steps for onboarding
 * `settings` — User-configurable app settings with defaults (persisted locally)
 * Toast notifications via `showMessage` action
 * `default` on fields — Magic values: `"NOW"` (current datetime), `"CURRENTDATE"` (current date), `"+7d"` (relative offset), `"CURRENT_USER.NAME"` (display name), `"CURRENT_USER.EMAIL"` (email, web only), `"CURRENT_USER.USERNAME"`

### Branding & Theming
 * `branding.theme` — Named theme from the catalog (e.g., `"corporate"`, `"nord"`, `"dracula"`). 40 themes available, each with light and dark variants. Default: `"indigo"`. See `Themes/catalog.json`.
 * `branding.mode` — `"light"`, `"dark"`, or `"system"` (follows OS preference)
 * `branding.logo` — URL to logo image for sidebar/drawer header
 * `branding.favicon` — URL to browser tab icon (web frameworks)
 * `branding.headerStyle` — `"solid"` (filled), `"light"` (default), or `"transparent"`
 * `branding.fontFamily` — Custom font (e.g., `"Inter"`, `"Georgia"`)
 * `branding.overrides` — Per-token overrides (e.g., `{"primary": "oklch(58% .158 242)"}`) for custom theming on top of a named theme

 **Theme origins and accessibility:** ODS themes are derived from the [DaisyUI](https://daisyui.com/) theme collection, but they are not used directly. Each theme has been audited and corrected to meet **WCAG AA contrast requirements** (minimum 4.5:1 ratio) for all color/content pairs (primary/primaryContent, secondary/secondaryContent, accent/accentContent, background/baseContent, error/errorContent). The original DaisyUI themes had 79 contrast violations across 40 themes — every one has been fixed by adjusting the `*Content` color lightness while preserving hue and chroma. Colors use the **OKLCH** color space for perceptually uniform color definitions. See [`Themes/README.md`](Themes/README.md) for the full theme catalog, architecture details, and instructions for creating custom themes.

### Multi-User & RBAC
 * `auth.multiUser` — Enable login, user management, and role-based access control
 * `auth.multiUserOnly` — Require admin setup before the app can run
 * `auth.roles` — Custom roles beyond the built-in guest, user, and admin
 * `auth.defaultRole` — Role assigned to newly created users (default: `"user"`)
 * `auth.selfRegistration` — Allow users to sign up on the login screen (web frameworks)
 * `roles` arrays on menu items, pages, components, columns, fields, and row actions
 * `ownership` on dataSources — Row-level security with `ownerField` and `adminOverride`

## Available Frameworks

ODS specs are rendered by **frameworks** — each framework targets a different platform and storage model:

| Framework | Platform | Storage | Auth | Best For |
|-----------|----------|---------|------|----------|
| **Flutter Local** | Desktop (Win/Mac/Linux), iOS, Android | SQLite (on-device) | Per-app user tables | Personal/single-user apps, offline-first |
| **React Web** | Web browsers | PocketBase (server) | PocketBase auth + RBAC | Multi-user web apps, team collaboration |

### Flutter Local Framework
A native Flutter app that renders ODS specs on desktop and mobile. All data stays on the user's device in SQLite. User management is per-app with admin-created accounts. Self-registration is not supported (local-only).

### React Web Framework
A React 19 + TypeScript + Vite web application backed by PocketBase. Designed for multi-user applications with:
 * PocketBase for data storage and built-in auth
 * Self-registration support (`auth.selfRegistration`)
 * Default app concept — non-admin users visiting the root URL get redirected to a configured app
 * Admin dashboard with app management, user management, and PocketBase settings
 * shadcn/ui components with Tailwind CSS for a polished UI
 * Charts via Recharts (bar, line, pie)

## Minimal Spec Example

The simplest valid ODS spec — one page, one text component:

```json
{
  "appName": "Hello ODS",
  "startPage": "homePage",
  "pages": {
    "homePage": {
      "component": "page",
      "title": "Home",
      "content": [
        {
          "component": "text",
          "content": "Welcome to your first ODS app."
        }
      ]
    }
  }
}
```

A more realistic example with a form, list, and data source:

```json
{
  "appName": "My Notes",
  "startPage": "listPage",
  "pages": {
    "listPage": {
      "component": "page",
      "title": "Notes",
      "content": [
        {
          "component": "list",
          "dataSource": "notesReader",
          "searchable": true,
          "columns": [
            { "header": "Title", "field": "title", "sortable": true },
            { "header": "Date", "field": "date", "sortable": true }
          ]
        },
        {
          "component": "button",
          "label": "Add Note",
          "onClick": [{ "action": "navigate", "target": "addPage" }]
        }
      ]
    },
    "addPage": {
      "component": "page",
      "title": "Add Note",
      "content": [
        {
          "component": "form",
          "id": "noteForm",
          "fields": [
            { "name": "title", "label": "Title", "type": "text", "required": true },
            { "name": "date", "label": "Date", "type": "date", "default": "CURRENTDATE" },
            { "name": "content", "label": "Content", "type": "multiline" }
          ]
        },
        {
          "component": "button",
          "label": "Save",
          "onClick": [
            { "action": "submit", "dataSource": "notesStore", "target": "noteForm" },
            { "action": "navigate", "target": "listPage" },
            { "action": "showMessage", "message": "Note saved!" }
          ]
        }
      ]
    }
  },
  "dataSources": {
    "notesStore": { "url": "local://notes", "method": "POST" },
    "notesReader": { "url": "local://notes", "method": "GET" }
  }
}
```

A kanban board with drag-and-drop:

```json
{
  "appName": "Sprint Board",
  "startPage": "board",
  "pages": {
    "board": {
      "component": "page",
      "title": "Sprint Board",
      "content": [
        {
          "component": "kanban",
          "dataSource": "taskReader",
          "statusField": "status",
          "titleField": "title",
          "cardFields": ["title", "assignee", "priority"],
          "searchable": true
        }
      ]
    }
  },
  "dataSources": {
    "taskReader": { "url": "local://tasks", "method": "GET" },
    "taskWriter": { "url": "local://tasks", "method": "PUT" }
  }
}
```

The `statusField` must reference a `select`-type field. Its options become the board columns. Dragging a card to a new column automatically updates the status via the PUT dataSource. See `Examples/project-kanban.json` for a full working example.

## Schema Reference

The authoritative schema is `ods-schema.json` in this directory. All valid ODS specs must conform to it. Framework authors should validate incoming specs against this schema (or its equivalent model layer) before rendering.

For template authors, `ods-template-schema.json` defines the schema for Quick Build templates, including the wizard questions and JSON-e template body.

## Aggregate Expression Syntax

Aggregate expressions can be used in text components and summary card values to compute live totals from a data source:

```
{FUNC(dataSourceId, fieldName)}
```

Supported functions: `SUM`, `COUNT`, `AVG`, `MIN`, `MAX`, `PCT`.

An optional filter narrows the rows before aggregation:

```
{COUNT(tasksReader)}              -- count all rows
{COUNT(tasksReader, status=Done)} -- count rows where status is "Done"
{SUM(expenses, amount)}           -- sum the amount field
{PCT(tasksReader, status=Done)}   -- percentage of rows matching filter
```

`PCT` returns the percentage of matching rows out of total rows. All functions operate on the current local data at render time.

## For Framework Builders

If you are building a new ODS framework (a renderer for ODS specs), the recommended approach is:

 1. **Parse the spec JSON into a model layer.** Create typed classes or structs for each spec concept (app, page, component, field, action, dataSource). Validate early — reject malformed specs at parse time, not at render time.
 2. **Implement component renderers.** ODS has a closed set of component types: text, form, list, button, chart, summary, tabs, detail. A sealed or exhaustive pattern (sealed classes, tagged unions, or switch/match) ensures every type is handled and new types cause compile-time errors.
 3. **Implement the action handler.** Actions include: `navigate` (change page), `submit` (POST to dataSource), `update` (PUT with matchField), `showMessage` (toast notification), and record navigation (`firstRecord`, `nextRecord`, `previousRecord`, `lastRecord`). Actions are arrays — a single button click can trigger multiple actions in sequence.
 4. **Implement local data storage.** The `local://` URL convention means the framework manages storage locally (SQLite, IndexedDB, or equivalent). Tables are created on first write; the schema is inferred from form fields unless the dataSource specifies explicit `fields`. Support GET, POST, PUT, and DELETE methods.
 5. **Test against the example specs.** Every spec in the `Examples/` directory should parse and render without errors. This is the primary conformance test for a new framework.

## Contributing

We are excited to build a community around this project. Please read our CONTRIBUTING.md to learn how you can get involved.

## Code of Conduct

This project and everyone participating in it is governed by the ODS CODE_OF_CONDUCT.md. By participating, you are expected to uphold this code.
