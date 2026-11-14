---
type: handoff
status: ACTIVE
issue: 497
aliases: [Native Signed Integer Delivery]
---
# Native Signed Integer Delivery

## Validated local checkpoint

Compiler Engineer → Test Engineer → Delivery Owner for a local commit only.
All 19 clean GHC 9.14.1 -Werror gates and 669 groups pass, including 254 strict
C11 frame translations. The initial 20-group native run against the tree
evaluator passes under AddressSanitizer/UBSan; the two expanded integer groups
also pass after adding deferred-boundary settlement and normalization checks.
Six actual CLI entry cases and eight loop-boundary cases match both evaluators
and independent expected outputs/statuses. Cross-kind argument/arithmetic and
narrow shift-count probes retain ordinary E3001 checking. No checker, runtime
ABI or arithmetic-helper change was needed.

Evidence: ~/.codex/tmp/pudu-497/validation/ contains gates.log, 4.log,
sanitized-integers.log, cli-status.json and loop-boundaries.json; the earlier
tree run is ../sanitized-tree.log. Every observed process exits 0. Fixed
property repetitions are not independent generated cases. No subagents, push,
PR or merge; independent reviews and additional platform evidence remain open.
Numeric families stay Partial, so README progress remains 4/14 areas (28%).
Exact next action: create and resolve the unsigned-through-64-bit admission
issue, checking canonical identity and unsigned/deferred arithmetic before
implementation. Preserve Int128, BigInt, floats, Decimal and every other full
emission obligation rather than treating these four widths as completion.

## Ownership and branch

Delivery Owner → Language Architect → Compiler Engineer → Test Engineer.
Direct owner covers Lower.Types, Lower.Signature, Lower.Body, Lower.Scalar and
Lower.Control plus bounded native signed-width tests, registration and matching
mirrors. Runtime/frame contracts are reused; any discovered helper defect must
be specified before changing its owner. No subagents execute. Preserve unrelated
dist-ticky and all existing work.

[[Native Signed Integers]] resolves the design and replaces #497's obsolete
int64_t assumption with the revision-5 exact carrier. Implementation starts on
a fresh feature/497-native-signed-widths stacked on abe127cd because the required
ABI is not yet on dev. This continuation exception does not authorize merging
unreviewed work. Prior #499 validation is recorded in [[Native Frame Pressure Repair]].

## Acceptance and next action

Canonical identity, width-specific semantics, deferred values, evaluation order,
exact diagnostics and independent mathematical outputs must agree with both
evaluators. Full numeric coverage remains Partial. Independent reviews and
supported-platform evidence remain required before promotion.

Exact next action: implement the documented canonical admission predicates and
width-aware lowering, then run the new signed corpus through actual native
execution without weakening any existing refusal or conformance assertions.

## Referenced by

[[handoffs/_MOC]] · [[Native Signed Integers]] · [[Native C11 Backend Delivery]]
