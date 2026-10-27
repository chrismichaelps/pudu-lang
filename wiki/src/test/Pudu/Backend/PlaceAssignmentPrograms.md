---
type: module
path: "@root/test/Pudu/Backend/PlaceAssignmentPrograms.hs"
fidelity: Active
aliases: [Backend Place Assignment Programs]
---
# Backend Place Assignment Programs

Export placeAssignmentSuccessPrograms and placeAssignmentRefusalPrograms.
Successes assign fields, elements and nested elements, keep the old array
for another binding, mix field and element steps, and replace owned text
elements 300 times, including an element assigned from itself. Refusals
cover a negative index (E7004 at the root name) and an outer index out of
range after the indices and the value ran.

## Resolved Grill Log

Expectations come from the tree interpreter and are rechecked against the
compiled evaluator; healthy programs also run under counted allocation, and
ASan covers the self-assignment that retains before it releases.

## Dependencies and consumers

[[Backend Output Callable Programs]] · [[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[Native Place Assignment]] · [[src/Pudu/Backend/_MOC]]
