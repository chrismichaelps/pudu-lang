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

## Bidirectional monotone bulk loading

The prefix scanner determines direction from the first unequal pair. Adjacent duplicates retain
the same representative policy before and after direction selection. Descending runs accumulate
in ascending order directly; ascending runs reverse once at completion. At a direction change,
the scanner returns the canonical ascending prefix and leaves the changing element for strict
insertion. Thus both sorted directions reach the distinct-ascending builder without sorting or
repeated insertion. Arbitrary input retains the persistent fallback.

### Resolved Grill Log
- **Q:** Sort every input to recognize reverse order? **A:** No; select direction during the existing scan.
- **Q:** Reverse duplicate precedence with descending keys? **A:** No; combine duplicates in original input order before ordering the canonical prefix.
