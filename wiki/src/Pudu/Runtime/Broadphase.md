---
type: module
path: "@root/src/Pudu/Runtime/Broadphase.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, performance, physics]
aliases: [Runtime Broadphase]
---

# Runtime Broadphase

## Purpose and interface

`overlapPairs` takes six lanes of box bounds and answers flattened index pairs (i, j), i < j,
of boxes that overlap or touch, in ascending order. It sorts boxes by minimum x (ties by index)
and sweeps each against the following boxes while their x intervals overlap, testing y and z
only for those candidates. Mismatched counts, NaN bounds or a minimum above its maximum answer
Nothing. Exposed as the `lanesOverlapPairs` [[Lane Kernel Identity]] entry and
`Std.Lanes.overlapPairs`.

## Grill Log

- **Q:** Find pairs in Pudu with a spatial hash? **A:** No; per-body interpreted work dominates a
  physics step. Pair finding is the step's native kernel; narrow phase and response stay in Pudu.
- **Q:** Return pairs in discovery order? **A:** No; sorted pairs make contact order, and so the
  solver's result, deterministic.

## Referenced by

[[Std Lanes]] · [[Overlap Pairs Fixture]] · [[Broadphase Delivery]]
