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
- **Q:** Import `Data.List (foldl')` under GHC 9.10? **A:** No; `foldl'` is in Prelude; omit redundant import for -Werror compliance.

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

## Balanced monotone-run assembly

Bulk construction now scans every monotone run, not only the initial prefix. Each canonical run
builds a tree directly. A binary carry stack merges equally ranked groups; its roots represent
chronologically contiguous runs, with newer groups nearest the front. Final folding combines older
groups before newer ones. Map merging keeps the older key representative and newer payload;
Set merging keeps the older representative. Rank counts runs, not entries, and bounds the number
of pending roots logarithmically in the run count. A single monotone input still builds once.

This supersedes strict per-element fallback after the first direction change. It targets partially
ordered workloads without changing immutable output or equality. Merge cost depends on run sizes
and overlap; no measured speedup or universal improvement over incremental construction is claimed.

### Resolved Grill Log
- **Q:** Merge each new run into one growing tree immediately? **A:** No; equal-rank carries prevent repeatedly joining every short run against the full history.
- **Q:** Reorder runs by size and lose duplicate precedence? **A:** No; stack groups preserve chronological order, and merge argument order is explicit.
