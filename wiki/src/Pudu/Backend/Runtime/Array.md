---
type: module
path: "@root/src/Pudu/Backend/Runtime/Array.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Runtime Array]
---
# Backend Runtime Array

The item buffer behind every array: a box whose one field points at a
`pudu_items` block (length, capacity, cells). Parts: `array` (the buffer and
`pudu_array_new`), `array_reserve` (growth by doubling, for a box with one
owner), `array_offset` and `array_clamp` (index rules), `array_size`,
`int_order` and `array_join`. These parts are written after the frame types,
which they use.

## Resolved Grill Log

- The box never moves when its items grow, so slots holding it stay valid.
- One part per helper, so a program carries only what it calls and the C has
  no unused functions.

## Referenced by

[[Backend Emit Array]] · [[Native Arrays]]
