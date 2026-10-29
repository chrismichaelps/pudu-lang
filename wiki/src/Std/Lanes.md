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
`affine3(matrix, xs, ys, zs)` with a 12-entry column-major matrix. Data-parallel control (#684): `select(mask, a, b)`, `above(lanes, threshold)` masks,
`positions(mask)` compresses to ascending indices, `scatterAdd` accumulates repeats in order,
`fromInts` and `toInts` convert index data. Collision: `overlapPairs(minX, maxX, minY, maxY, minZ,
maxZ)` from [[Runtime Broadphase]]. Audio output: `interleave(first, second)` alternates two
equal lanes (stereo frames) and `toPcm16(lanes)` writes clamped, rounded little-endian 16-bit
samples in one native pass. Host byte order; use
[[Std Buffer]] to serialize portably.

## Grill Log

- **Q:** Add domain kernels (a contact solver) natively? **A:** No; general select, compress
  and scatter-add let branchy algorithms stay in Pudu as lane programs.

- **Q:** Expose element loops over lanes? **A:** No; a loop that sets one value per step copies
  the lanes each time. Express per-frame work as whole-lane kernels.

## Referenced by

[[src/Std/_MOC]] · [[Runtime Lanes]] · [[Lanes Gate]]
