---
type: module
path: "@root/src/Pudu/Runtime/Word.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Runtime Word Kernels]
---

# Runtime Word Kernels

## Purpose, interface and invariants

`countWords` accepts a fallible projection into Word64 and folds any Foldable container directly.
Each valid word uses Data.Bits.popCount with a strict Integer accumulator. Failure retains the
first projection error; subsequent payloads are not projected, although the container spine is
still traversed. No intermediate word collection, list or per-bit loop is constructed. INLINE
exposes the projection and fold at the consumer. Hardware instruction selection is GHC/target
controlled, not promised by this API. The module has no evaluator or frontend dependency.

## Grill Log

- **Q:** Count bits in Pudu callbacks? **A:** No; traverse the host container once and apply the
  native Word64 population count to each checked payload. This removes interpreted bit loops.
- **Q:** Claim an unboxed map or measured speedup? **A:** No; the map still stores boxed values.
  The change removes dispatch and staging, not the tree representation. No validation was run.

## Dependencies and consumers

[[Eval Word Map]] adapts [[Runtime Word Kernels]] for [[Std BitSet]] through [[Eval Builtin]].

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]
