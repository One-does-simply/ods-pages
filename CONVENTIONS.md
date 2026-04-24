# ODS Family Conventions

A *family* in ODS is a distinct spec + its renderers. Today the only
family is [`ods-pages`](https://github.com/One-does-simply/ods-pages).
Planned siblings: `ods-chat` (conversational agents authoring specs),
`ods-workflow` (orchestration between specs), `ods-game` (game-app
specs + renderers).

This file documents patterns every family is expected to share, and
things deliberately kept per-family. It describes the *current shape*
of `ods-pages` — future families are free to copy it, diverge from it,
or propose changes.

## Monorepo structure

Each family is a single GitHub repo with this top-level layout:

```text
<family>/
├── Specification/           # the JSON schema, examples, templates, themes
├── Frameworks/              # renderers — one subfolder per implementation
│   ├── <impl-1>/            # e.g. flutter-local, react-web
│   ├── <impl-2>/
│   └── conformance/         # cross-framework parity driver + scenarios
├── BuildHelpers/            # AI-assistant prompts for spec authors
├── docs/
│   ├── adr/                 # Architecture Decision Records
│   ├── TROUBLESHOOTING.md
│   └── <other cross-cutting docs>
├── .github/workflows/       # CI per framework (path-filtered)
├── ARCHITECTURE.md
├── CLAUDE.md                # AI-assistant workflow rules
├── CONVENTIONS.md           # this file (in ods-pages, optional in siblings)
├── LICENSE                  # MIT
├── README.md
├── REGRESSION_LOG.md        # test batches + bugs found
├── SECURITY.md
├── TODO.md
└── publish.sh               # stage/test/commit/push helper
```

## Cross-family conventions

These patterns are worth copying into every family because the cost of
divergence is higher than the cost of consistency.

### `publish.sh`

A bash script at the repo root that:

- Runs the framework-level test suites (Flutter + whatever else the
  family has).
- Stages all changes, creates a commit, and pushes.
- Supports `--status` (dry-run) and `--skip-tests` (bypass gate when
  flakes are known).
- Commits are co-authored with the AI assistant when applicable.

See [publish.sh](publish.sh) in `ods-pages`.

### `TODO.md` format

A single `TODO.md` at the repo root, structured as:

```markdown
## Now — actively being worked on
## Next — next 1–2 sessions
## Docs — priority 3 (pre-public polish)
## Docs — nice-to-haves
## Later — important, not urgent
## Wishlist — ideas; not scheduled
---
## Done — recent (trim quarterly)
### YYYY-MM-DD — <short theme>
- [x] Item with [file links](path) and rationale
```

Items should include links to code paths so the list doubles as a
jump-table.

### `REGRESSION_LOG.md`

Companion to `TODO.md`. Every test batch gets an entry with counts,
bugs found, and links to the fixes. Older entries trim down to
summaries over time.

### ADR convention

Architecture Decision Records live in `docs/adr/NNNN-kebab-name.md`,
numbered sequentially starting at 0001. A `_template.md` in the same
folder captures the expected shape. Status values: `draft`,
`accepted`, `superseded`, `deprecated`.

### CI workflows

One workflow file per framework under `.github/workflows/`, each with
`paths:` filters so framework-specific changes don't run sibling
framework suites. CI runs **mirror** the `publish.sh` gate — if
`publish.sh` excludes widget tests or `@slow`-tagged perf tests, CI
should too. Divergence between "what local treats as the gate" and
"what CI treats as the gate" is a bug.

### AI-assistant workflow (`CLAUDE.md`)

A root `CLAUDE.md` captures:

- Workflow rules specific to the project (what to verify, what to
  avoid, what to always re-read).
- Pointers to the current spec + regression log.
- Historical pain points that future sessions should know about.

Other AI assistants can follow the same file.

### Public-repo basics

Every family's public repo carries at minimum: `LICENSE` (MIT),
`SECURITY.md`, `README.md` with CI badges, non-empty repo description,
relevant topics on the repo.

### Naming + tagline

Every family has two names and a tagline:

- **Repo / code name**: lowercase kebab, matches the repo URL —
  `ods-pages`, `ods-chat`, `ods-workflow`, `ods-game`. Used in code,
  URLs, file paths.
- **Display name**: proper-cased two-word brand — `ODS Pages`,
  `ODS Chat`, etc. Used in titles, hero copy, marketing.
- **Tagline**: follows the shape
  *"Vibe Coding [domain phrase] with Guardrails"* — the umbrella
  `One Does Simply` uses the unqualified *"Vibe Coding with
  Guardrails"*, and each family specializes the middle:
  - ODS Pages → *Vibe Coding data-driven apps with Guardrails*
  - ODS Chat → *Vibe Coding conversational agents with Guardrails*
  - ODS Workflow → *Vibe Coding automation with Guardrails*
  - ODS Game → *Vibe Coding games with Guardrails*

Keep the shape consistent across families; choose the domain phrase
carefully (plural, concrete, ≤4 words).

## Deliberately per-family

These stay separate in each family's repo, even when they'd be
technically similar:

- **The specification** — each family's JSON schema is its own thing.
  `ods-pages` specs describe pages/forms/lists; `ods-game` specs will
  describe scenes/entities/rules. They may share primitives
  eventually, but the source of truth for each family's spec lives in
  that family.

- **The frameworks (renderers)** — implementations are family-specific.
  A React renderer for `ods-pages` is not the same code as a React
  renderer for `ods-game`.

- **BuildHelpers prompts** — AI prompts that teach an LLM to author
  specs are family-specific.

- **Conformance scenarios** — each family has its own parity driver
  contract. The *shape* of the conformance driver pattern is copyable;
  the scenarios themselves are family-specific.

- **Dependencies** — families may use different toolchains, SDK
  versions, and dependency pins. No shared lockfile or package
  hoisting.

## When to extract

The umbrella `ods` repo is deferred until a second family demonstrates
non-trivial shared content that is painful to duplicate. Candidates to
watch for:

- A cross-family specification primitive (e.g. theming tokens used by
  both `ods-pages` and `ods-game`).
- Tooling that all families want (e.g. a spec-validator CLI).
- Long-form docs about ODS as a whole (not just one family).

Until that threshold is crossed, **duplicate** rather than extract.
The duplication tax is low while things are in flux; the premature-
abstraction tax is much higher.
