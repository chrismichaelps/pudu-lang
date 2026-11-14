---
type: handoff
status: ACTIVE
aliases: [Water Validation Delivery]
tags: [handoff, ark, water, testing]
---
# Water Validation Delivery

Ark is the active delivery track; feature/759 remains held and outside scope.
Issue #784 on feature/784-water-conformance changes verification only, leaving engine behavior intact.
Issue #735 still precedes Binary/#739 functional integration.

Architect → Verification Engineer owns test/ark-water.mjs, test/gates.sh,
.github/workflows/ci.yml, their matching mirrors and water navigation/changelog.
No engine solver, renderer, held branch or other worktree edits. Independent
review is waived for this engine loop; no delegated agents.

## Resolved Grill Log

[[Ark Water Validation]] defines current capability, independent modal reference,
small-amplitude bounds and future physical tracks. [[Ark Water Gate]] defines the
source adapter and actual production-step execution. Both complete pages precede
implementation. Register the same gate locally and in hosted compiler checks.

Focused gate passes 48 case executions; maximum error 1.735e-17 against a 1e-10
limit. Every step rejects nonfinite absolute sums and peaks at or above 0.01.
All clean optimized local gates pass, including full suite, formatting, engine,
package, residency, editor and documentation checks. Four private mutation trials
reject adapter drift, a periodic wall, lost damping and reversed wave sign.
Verification Engineer → Forensic Guardian: mirrors, MOCs, backlinks and changelog
match this verification-only slice; review size is below 400 changed lines.
Exact next action: commit and publish the slice, then require hosted checks before
merging to dev.

## Referenced by

[[handoffs/_MOC]] · [[Ark Water Validation]] · [[Ark Water Gate]]
