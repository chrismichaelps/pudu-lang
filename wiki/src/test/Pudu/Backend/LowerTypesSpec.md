---
type: module
path: "@root/test/Pudu/Backend/LowerTypesSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend]
aliases: [Native Solved Types Tests]
---
# Native Solved Types Tests

## Purpose and interface

lowerTypesProperties tests canonical formed projection, exact complete source
and generated span identity, missing analysis and missing schemes through the
real checked compiler. Located E6001 is required when facts are unavailable.

## Dependencies and consumers

[[Compiler Lower Types]] · [[Compiler Lower]] · [[Type Boundary]] · [[Source]].
Registered by [[Repository Test Runner]] and [[Pudu Test Cabal Manifest]].

## Resolved Grill Log

- **Q:** Can a same-spelling nominal Int select the scalar ABI? **A:** No; compare canonical identity. Reject tuple-empty as Unit too.
- **Q:** Can equal offsets in another snapshot select facts? **A:** No; source and generated origin are part of the key. Test collisions directly.
- **Q:** May missing facts silently fall back to annotation spelling? **A:** No; use real checked syntax and remove facts to require E6001 at the module/function boundary.

## Referenced by

[[Repository Test Runner]] · [[Pudu Test Cabal Manifest]] · [[Compiler Lower Types]]
