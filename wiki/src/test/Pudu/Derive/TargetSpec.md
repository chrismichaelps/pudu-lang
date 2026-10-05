---
type: module
path: "@root/test/Pudu/Derive/TargetSpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, tests]
aliases: [Derive Target Spec]
---

# Derive Target Spec

## Purpose and interface

`targetProperties` checks actual target preparation through parsed multi-module
catalogues. Concrete record aliases and positional/named sum payloads substitute
the actual argument vector; inline generic requests retain their own binders.
Prepared types re-form to canonical owners in the consumer scope.

## Evidence and invariants

Assert field/payload types and unchanged declaration names/order, attributes,
mutability and authored field anchors. Round-trip structured formed types through
bounded canonical syntax, including references, dynamic traits, unsafe/async
functions, tuples and higher-kind applications. Refuse unresolved/error types,
unrepresentable default arity and exhausted depth. Strategy selection compares
complete trait arguments rather than owners alone.

## Grill Log

- **Q:** Assert that a substitution map contains Int? **A:** Prepare parsed
  aggregate requests and re-form their actual payload syntax. _Rejected:_ a
  constructor-only oracle that never reaches declaration scopes or target aliases.
- **Q:** Claim executable derive delivery? **A:** These properties prove typed
  preparation only; loaded request generation and execution remain separate gates.

## Linkage and references

Requires [[Derive Target Application]], [[Derive Catalogue]] and [[Type Formation]].
Referenced by [[src/_MOC]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]].
