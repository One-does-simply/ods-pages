# One Does Simply — Project Instructions

## Workflow / General Rules

Wait for all user context (including screenshots and images) before starting implementation. If the user mentions they will provide additional context, wait for it rather than beginning work immediately.

## Architecture / Multi-Repo

This project uses TypeScript (React) and Flutter (Dart) across multiple repos. When making changes, always check for cascading side effects — especially around shared state, authentication state, theme rendering, and spec/config syncing. Run the full test suite after changes, not just targeted tests.

## External APIs / PocketBase

When working with PocketBase APIs, always verify the exact API version and endpoint format before making calls. Known gotchas: auto-cancellation requires `requestKey` param, auth endpoints differ between versions, collection schema field types vary by version. Never assume endpoint structure — check PocketBase docs or existing working code first.

## Debugging

When debugging issues, exhaust the most likely root cause by reading the actual runtime error and relevant code BEFORE hypothesizing. Do not cycle through multiple wrong diagnoses (auth, routing, stale build) — instead, trace the actual data flow from the error backward. If the first fix doesn't work, re-read the error output carefully before trying another approach.

## Content Generation

When asked to generate original content (descriptions, acceptance criteria, documentation), write fresh content based on source requirements and context — NEVER copy from existing work items or prior content unless explicitly asked to reuse it.

## Flutter-Specific

When working with Flutter Color APIs, values use floats (0.0-1.0) not ints (0-255). Always verify color value ranges and WCAG contrast calculations use the correct scale. Test theme rendering with widget recycling in mind (ListView reuse can cause stale rendering).
