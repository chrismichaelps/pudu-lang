---
type: handoff
status: ACTIVE
issue: 649
aliases: [Native Place Assignment Delivery]
---
# Native Place Assignment Delivery

Backend Engineer → Test Engineer → Forensic Guardian self-audit. Owned:
Compiler Lower Place (new), Body's assignment cases, Record's removed field
assignment, ArrayReplaceAt in Core, frame emission and the array helper,
takeReceiver, PlaceAssignmentPrograms and mirror pages. No sub-agents.
Branch feature/649-native-element-assignment on
feature/646-native-trait-method-values.

Found while probing `&mut` writeback: element assignment crashed the
compiler with a stack overflow (#649, filed and fixed here).

Evidence: every corpus program matches the tree interpreter byte for byte;
output-callable groups pass under Clang, GCC 15 and ASan/UBSan with zero
live allocations; refusal, record, array, lowering, frame, emit and module
groups pass.

Exact next action: mutable loans. A `&mut T` parameter is copy-in/copy-out:
the callee returns its result together with the final values of its loaned
parameters, and the call site stores each into its place through
lowerPlaceAssignment's rebuild, on every return path, as
`runClosureKeeping` and `storePlace` do in the evaluator.

## Referenced by

[[handoffs/_MOC]] · [[Native Place Assignment]]
