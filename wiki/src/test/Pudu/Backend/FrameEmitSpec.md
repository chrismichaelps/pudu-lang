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
loop corpora with cc -std=c11 -pedantic -Wall -Wextra -Werror. The production type-only
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

## Wide frame bridge (#506)

Use production frameTypes and frameUsesWideCells instead of a duplicated narrow-only test ABI. Select wide_value when the production layout requires it. Replace the unsupported manual 128-bit descriptor with 256-bit metadata. Resolved Grill Log: retain located refusal coverage and compile only the helpers emitted bodies require. Public source admission remains a later slice. [[Native Wide Frame Bridge]].

## Text slots (#515)

A text slot now spells `frame->slots[i].text` instead of refusing. The strict
translation check selects the text part and cell member when a program has
text, and closes dependencies through [[Native Runtime Dependencies]].

## Box flag (#521)

The body check passes `False` for boxes: its programs hold no tuples.

## Whole-program strict compile (#636)

testBodies compiles what emitFrameProgram writes for each corpus program,
not a hand-picked scalar runtime.
Resolved Grill Log: printing programs carry Result aggregates since output
Results became values, and the hand assembly had no aggregate runtime. The
real assembler is what users get, so it is what must compile strictly.
