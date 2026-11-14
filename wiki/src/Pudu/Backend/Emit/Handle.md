---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Handle.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Foreign Handle]
---
# Backend Emit Foreign Handle

`handleHelpers` emits the aggregate drop, render, type name, equality and
ordering helpers for each nominal foreign handle. The box stores an address
and a generation. Generation zero represents a borrowed result.

## Resolved Grill Log

- Dropping the last box reference frees the box. [[Native Host Foreign]] owns
  the separate release obligation and drains it at entry completion or fatal
  failure if the program did not release it explicitly.
- Render the written name and hexadecimal address in the evaluator's format.
  Equality compares address and generation within the statically known type.
  Ordering follows the evaluator's same-shape comparison for handles.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Aggregate Emission]] · [[Native Foreign Call Sites]]
