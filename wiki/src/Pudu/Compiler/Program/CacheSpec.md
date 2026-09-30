---
type: module
path: "@root/test/Pudu/Compiler/Program/CacheSpec.hs"
fidelity: Active
subsystem: "[[Testing]]"
grammar: "[[grammar/haskell]]"
tags: [module, test]
aliases: [Program Cache Spec]
---

# Program Cache Spec

## Purpose

Verify compiled product cache equivalence, invalidation, corruption recovery and frozen constants.

## Interface

Exports `testCacheCorruption`, `testCacheEquivalence`, `testCacheInvalidation`,
`testFoldedConstants`, and `testImportedConstants`, each `IO Property`.

## Algorithm

Compile programs fresh, cold and warm, compare diagnostics, link order and execution. Modify
library content while preserving timestamps to prove invalidation uses content. Corrupt stored
bytes to exercise safe fallback. Compare tallied execution with and without frozen bindings.
Imported constant coverage creates temporary modules with explicit aliases, default qualifiers,
selected imports (including a function shadowing builtin `show`) and transitive constants, checks frozen values and warm-cache equivalence,
and refuses imported effectful calls before runtime.

## Invariants and failure cases

Cached products retain source identity and integer kinds. Failed compiles are never stored.
Function constants carry environments and cannot be frozen. Effects remain unavailable to folding.

## Grill Log

- **Q:** Can a constructor alias test stop at checking? **A:** No; assert frozen products and actual
  execution through cold and warm caches, because a checker-only fix can still fail at linking.
- **Q:** What regression boundary matters? **A:** Imported function calls must still refuse effects
  while pure imported calls and transitive frozen constants retain their declaration scopes.

## Linkage

Requires [[Compiler Program]], [[Compiler Cache]], [[Eval Program]] and [[Eval Frozen]].
Consumed by [[Program Spec]].

## Referenced by

[[Program Spec]] · [[Compiler Program]]
