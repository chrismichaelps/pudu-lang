---
type: module
path: "@root/test/Pudu/Backend/FrameEmitSpec.hs"
fidelity: Active
aliases: [Native Frame Body Tests]
---
# Native Frame Body Tests

## Purpose and interface

Export frameEmitProperties. Check generated call suspension and malformed slots,
then compile actual emitted step bodies for checked native function, integer and
loop corpora with cc -std=c11 -pedantic -Wall -Wextra -Werror. A minimal type-only
frame ABI and externally reachable dispatch wrapper make every generated body
compiled and referenced. Compile objects only: no allocator or runtime dispatcher
is implemented by this harness. Missing cc is visibly reported as a skip.
Pin three nested source calls to three call steps; all body-name references in
generated code must be definitions, and argument copies use frame-owned storage.
The test dispatch wrapper checks depth on returned call steps so call-refusal
helpers are actually referenced, matching the pending production boundary.
Reject unsupported integer descriptors with their original span as well as
Text/Never and negative-identity slots.

## Resolved Grill Log

- **Q:** Treat text matching as C portability evidence? **A:** No; compile the generated C with strict warnings as errors.
- **Q:** Claim execution parity? **A:** No; these checks prove translation and helper selection only, with runtime integration still pending.
- **Q:** Select all helpers to mask missing requirements? **A:** No; close only the roots returned by actual emission.

## Dependencies and consumers

[[Backend Frame Bodies]] · [[Backend Frame Values]] · [[Backend Runtime]] ·
[[Backend Function Programs]] · [[Backend Integer Programs]] · [[Backend Control Programs]]

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]] · [[Repository Test Runner]]
