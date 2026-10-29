---
type: module
path: "@root/src/Pudu/Runtime/Lanes.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, performance, lanes]
aliases: [Runtime Lanes]
---

# Runtime Lanes

## Purpose and interface

Whole-lane kernels over a ByteString of host-order binary64 values. `laneMap`, `laneZip`,
`laneZip3` and `laneFold` make one pass with explicit index loops over raw pointers and allocate
exactly their result through `unsafeCreate`; no intermediate list or boxed element exists.
`laneFill`, `laneRamp`, `laneFromList`, `laneToList`, `laneGet`, `laneSet` (one copy plus one
store), `laneSlice`, `laneConcat`, `laneGather`, `laneScatter` (later index wins) and
`laneWhere` (positive indices), `laneScatterAdd` (repeats accumulate in order) and
`laneAffine3` (column-major 3x4 matrix over x/y/z lanes, written row order) complete it.
`laneInterleave` alternates two equal lanes and `laneToPcm16` clamps each value to [-1, 1],
scales by 32767, rounds half away from zero (NaN to zero) and writes little-endian 16-bit bytes.
Mismatched lengths and out-of-range indices answer `Nothing`. Folds run in index order, so
results equal the scalar loop written the same way.

## Grill Log

- **Q:** Scale PCM by 32768 to reach the negative extreme? **A:** No; one symmetric scale keeps
  +1 and -1 equally loud and makes the mapping odd, so inverted signals stay exact inverses.

- **Q:** Mutate lanes in place? **A:** No; Pudu values are persistent. Each kernel allocates one
  result, which costs a pass of memory traffic rather than per-element interpretation.
- **Q:** Pairwise summation for accuracy? **A:** No; index order keeps results identical to the
  scalar definition. Callers needing compensated sums build them on these kernels.

## Referenced by

[[Lane Kernel Identity]] · [[Eval Builtin Lanes]] · [[Std Lanes]]
