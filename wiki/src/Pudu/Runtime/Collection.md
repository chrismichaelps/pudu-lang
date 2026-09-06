---
type: module
path: "@root/src/Pudu/Runtime/Collection.hs"
fidelity: Active
tags: [module, runtime, internal, collections]
aliases: [Runtime Collection Kernels]
---
# Runtime Collection Kernels

## Purpose and interface
Pure internal storage kernels shared by Map, Set and indexed HashMap runtime adapters. The module
has no evaluator Value, syntax, IO or diagnostic dependency. `buildMap` and `buildSet` establish
ascending prefixes before bulk loading, then apply strict persistent updates to remaining input.
`mapSequence`, `setSequence` and `intMapSequence` project ordered storage directly into sequences.

## Invariants
Map duplicate keys retain the first representative and latest payload. Set duplicates retain the
first representative. Only a proven strictly ascending canonical prefix enters a distinct-ascending
builder. Enumeration preserves native ascending key order. Input containers remain immutable and
no raw storage pointer escapes. Generic kernels expose INLINE boundaries for concrete callers.

## Resolved Grill Log
- **Q:** Couple low-level kernels to evaluator values? **A:** No; comparability and projections are supplied through normal static types.
- **Q:** Accept an unchecked sorted-input flag? **A:** No; the scan establishes the precondition internally.
- **Q:** Add a public unsafe capability to accelerate collections? **A:** No; persistent kernels remain pure and internal.

## Referenced by
[[src/_MOC]] · [[Eval Keyed]] · [[Eval Hash Map]] · [[Pudu Cabal Manifest]]
