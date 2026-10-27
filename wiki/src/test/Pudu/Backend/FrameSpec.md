---
type: module
path: "@root/test/Pudu/Backend/FrameSpec.hs"
fidelity: Active
aliases: [Native Frame Lowering Tests]
---
# Native Frame Lowering Tests

## Purpose and interface

Expose frameProperties to the ordinary runner. Explicit Core graphs pin local
snapshots, call resume/destination slots, guarded logical calls, abrupt transfer
suppression and located malformed-input failures. Compile existing native
function/integer corpora through checked Core and lowerFrames; check that all
jump/call destinations exist. Passing these tests does not imply native dispatch.
Pin nested call destinations across two suspensions and outer-loop transfers
inside while conditions and break operands against literal expected graphs.

## Resolved Grill Log

- **Q:** Compare only with the pass itself? **A:** No; assert concrete ordering and destinations from independently constructed Core inputs.
- **Q:** Skip checked input? **A:** No; reuse the native corpus without executing its pressure program.
- **Q:** Claim native stack safety? **A:** No; runtime dispatch and its permanent regression remain pending.

## Dependencies and consumers

[[Compiler Frame Lowering]] · [[Core Frame IR]] · [[Backend Function Programs]] ·
[[Backend Integer Programs]] · [[Repository Test Runner]]

## Closures (#555)

Resolved Grill Log: the module literal carries no closures, and a call through a value resumes like a call.

## Computed help (#558)

Matches `FrameFailText{}` by record syntax, so new operands don't break it.

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]]
