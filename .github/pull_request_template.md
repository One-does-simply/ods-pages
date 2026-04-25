<!--
Thanks for contributing! See CONTRIBUTING.md for the conformance-first +
test-first workflow this repo runs on.
-->

## Summary

<!-- What changes and why. 1–3 sentences. -->

## Test plan

<!--
Check whichever apply, and explain the rest in prose. Reviewers will
ask for missing items before approval.
-->

- [ ] **Cross-framework behavior** → covered by a conformance scenario
      (red on both drivers, then green on both). Scenario id(s):
      <!-- e.g., s22, s26 -->
- [ ] **New framework-local code** → covered by a unit/component/
      integration test that fails without the change.
- [ ] **Bug fix** → includes a regression test that captures the
      original symptom and would have failed pre-fix.
- [ ] **Refactor only** → existing tests cover the touched code paths.
- [ ] `./publish.sh "msg"` ran clean locally (analyze + tsc + tests +
      coverage thresholds all green).

## Notes for reviewer

<!-- Anything non-obvious: trade-offs, alternatives considered,
follow-ups deferred to TODO.md, parity gaps surfaced, etc. -->
