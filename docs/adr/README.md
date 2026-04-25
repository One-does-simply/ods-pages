# Architecture Decision Records

This folder captures non-obvious design decisions for ODS. An ADR
exists when the *why* behind a choice would otherwise get lost to
commit history and nobody would know whether to revisit it later.

## When to write one

Write an ADR when:

- You make a choice between two+ reasonable options and the reasoning
  isn't obvious from the code (e.g., "why Zustand over Redux").
- You introduce a pattern that touches multiple files or crosses
  framework boundaries (e.g., the conformance driver contract).
- You revisit a prior decision and want to record that you
  *deliberately* kept it or *deliberately* changed it.

Don't write one for:

- Day-to-day refactors, bug fixes, or dependency bumps.
- Decisions that are so obvious from the code they need no
  justification.

## How to write one

1. Copy [_template.md](_template.md) to `NNNN-short-kebab-title.md`
   where `NNNN` is the next unused 4-digit number.
2. Fill it in. Keep it short — prose, not essay. Code snippets only
   where they clarify the choice.
3. Mark status `draft` while in review, `accepted` when merged,
   `superseded by ADR-NNNN` if later replaced.
4. Link the ADR from [../../TODO.md](../../TODO.md) (Now / Next / etc)
   and from the code it covers if the code isn't self-explanatory.

ADRs aren't immutable — amend them when the decision evolves. Just
mark the amendment with a date and keep the original reasoning visible.

## Index

| #    | Title                                                                           | Status   |
|------|---------------------------------------------------------------------------------|----------|
| 0001 | [Conformance Driver Contract](0001-conformance-driver-contract.md)              | accepted |
| 0002 | [Theme + Customizations Redesign](0002-theme-customizations-redesign.md)        | accepted |

## Format inspiration

Loosely based on Michael Nygard's [original ADR format][nygard]
adapted for solo/small-team use. We keep only the sections that pay
for themselves.

[nygard]: https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
