---
type: module
path: "@root/test/Pudu/Backend/LowerTypesSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend]
aliases: [Native Solved Types Tests]
---
# Native Solved Types Tests

Add canonical UInt/UInt8/16/32/64/128 projections while rejecting user-owned
identities and applied primitive shapes. Resolved Grill Log: preserve signedness
and platform/fixed identity rather than selecting a signed carrier by width.

For #497, require canonical Int8/16/32/64 projection and reject same-spelling
user-owned identities and applied primitive shapes. Resolved Grill Log: pin Int64 versus
platform Int and malformed/generic nominal shapes without spelling-based inference.

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

## Explicit operator facts (#494)

Assert explicit Never-typed CoreOperatorFailure nodes, whole-operation spans, original literal diagnostic messages and operand counts from real checked Unit/Bool sources. Remove expression facts to prove trap admission refuses E6001. Resolved Grill Log: pure Core evidence does not replace native differential tests, and shared message factories cannot silently change both oracles together.

## Wide source admission (#507)

Require canonical Int128/UInt128 projections while rejecting user-owned identical spellings and applied primitive forms. Preserve missing-analysis and exact span identity tests. Resolved Grill Log: admission must not weaken nominal identity or reuse facts from another source. [[Native Wide Source Admission]].
