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

## Native word-map algebra

Four pure primitives `wordMapUnion`, `wordMapIntersection`, `wordMapDifference`, and
`wordMapSymmetricDifference` each take two Map[K, UInt64] values and return Map[K, UInt64].
Absent keys denote zero words; zero results are omitted. Shared keys retain the left key
representative. UInt64 payloads are validated in ascending key order, left input before right,
including entries the operation will discard. Invalid runtime values report E7001; wrong arity
reports E7003. Existing argument evaluation remains left to right. These names are installed,
typed and dispatched as pure primitives; Std.BitSet uses them directly.

The internal `WordOperation` enum selects `combineMaps`: tree-native mergeWithKey applies OR,
AND, AND-complement or XOR without interpreted callbacks or entry arrays. The evaluator first
projects each map to checked Word64 payloads and maps the result back to UInt64 values. These
intermediate native-word trees are an explicit allocation tradeoff, not an unboxed-storage claim.

Resolved Grill Log: Validate all payloads before algebra so malformed values cannot hide in a
discarded branch. Drop all zero results, including unmatched zeros, for canonical sparse output.
No tests, builds, reviews or measurements run.
