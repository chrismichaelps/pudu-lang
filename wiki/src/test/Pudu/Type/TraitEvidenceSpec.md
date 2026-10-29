---
type: module
path: "@root/test/Pudu/Type/TraitEvidenceSpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, semantics, runtime]
aliases: [Trait Evidence Spec]
---

# Trait Evidence Spec

## Purpose and interface

`traitEvidenceProperties` compiles real multi-module programs and runs `main` under both the tree
and compiled evaluators, asserting identical output, for issues #734, #735 and #743.

## Coverage

- Two imported traits sharing a member for `Int`: importing both checks; bound-directed calls run
  their own trait, including a parameter bounded by both; module-qualified
  `First.Encode.encode(&1)` and the same through a bound; an unqualified concrete call reports
  exactly one `E3013` whose help names both module-qualified spellings.
- Two same-module traits sharing a member, with a default calling the shared name, and the #743
  reproducer: a bound selects its trait for `Int` and record receivers in both declaration orders.
- A generic implementation reached through a bound: the issue repro, an empty array, nested
  arrays, two levels of generic functions, and a bound trait without static members whose
  implementation calls its parameter statically.
- Static calls through parameters when two static traits share a member, and a static call now
  checked against its bound (`E3001`).
- A record deriving both `Std.Json.Encode` and a second `Encode` whose derive uses a
  `where F: Encode` closure, called through bounds, `Json.encode` and a module-qualified call.

## Negative logic and Grill Log

No stubs or hand-built syntax: every case goes through `compileProgram`. **Q:** Run only the default
evaluator? **A:** No; both must agree, since evidence reaches them by different paths (per call in
the tree walker, per call site in compiled code).

## Linkage and references

Requires [[Compiler Program]], [[Eval Program]], [[Diagnostic Model]].
Referenced by [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]] · [[src/_MOC]] · [[Trait Evidence Delivery]].
