# Security Policy

## Reporting a Vulnerability

If you discover a security issue in any ODS framework or spec, please
**do not** open a public GitHub issue. Instead, use
[GitHub's private vulnerability reporting](https://github.com/One-does-simply/ods-pages/security/advisories/new)
to file a private advisory.

We'll acknowledge receipt within a week and keep you updated on the fix.

## Supported Versions

ODS is pre-1.0. Fixes land on `main`; there is no LTS or back-porting
commitment yet. Once stable releases begin (tracked in
[CHANGELOG.md](CHANGELOG.md) when it exists), this section will list the
versions that receive security fixes.

## Scope

In scope for reports:

- The ODS frameworks in [Frameworks/](Frameworks/) (Flutter + React).
- The ODS specification in [Specification/](Specification/).
- The AI Build Helpers in [BuildHelpers/](BuildHelpers/) (prompt-injection
  concerns for spec-authoring flows).

Out of scope:

- Vulnerabilities in upstream dependencies (PocketBase, Flutter SDK, Vite,
  etc.) — report those to their respective projects.
- Denial-of-service from user-authored specs (specs are trusted input by
  design; spec authors control their own apps).
