---
type: module
path: "@root/lib/Std/Lanes.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, performance, lanes]
aliases: [Std Lanes]
---

# Std Lanes

## Purpose and interface

`Lanes` holds contiguous binary64 values with value semantics. Construction: `filled`, `ramp`,
`fromArray`, `fromBytes -> Option`, `toArray`, `toBytes`. Access: `count`, `get`, `set` (copies:
an edit, not a loop primitive), `slice`, `concat`, `gather`, `scatter`. Arithmetic, each one
native pass: `add`, `subtract`, `multiply`, `divide`, `minimum`, `maximum` (elementwise,
`Option` on length mismatch), `addScalar`, `scale`, `clamp`, `axpy(y, a, x)`, `fma(a, b, c)`,
`abs`, `negate`, `sqrt`, `floor`. Reductions: `sum`, `dot`, `smallest`, `largest`. Geometry:
`affine3(matrix, xs, ys, zs)` with a 12-entry column-major matrix. Host byte order; use
[[Std Buffer]] to serialize portably.

## Grill Log

- **Q:** Expose element loops over lanes? **A:** No; a loop that sets one value per step copies
  the lanes each time. Express per-frame work as whole-lane kernels.

## Referenced by

[[src/Std/_MOC]] · [[Runtime Lanes]] · [[Lanes Gate]]
