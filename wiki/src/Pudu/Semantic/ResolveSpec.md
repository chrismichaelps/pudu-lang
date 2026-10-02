---
type: module
path: "test/Pudu/Semantic/ResolveSpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, tests, resolution]
aliases: [Name Resolution Spec]
---

# Name Resolution Spec

## Purpose and interface

`resolveProperties` proves declaration order, namespaces, generic and pattern
scope, imports, exports, diagnostics and derive rigid binding through compiler
entry points. A resolution-only helper isolates reflection's lexical contract
when no imported typing interface has been provided.

## Algorithm and evidence

Assert exact codes, related locations, exports and reference counts. Positive
metadata resolution uses the frontend and real resolver directly, because an
isolated whole-compiler run cannot type an imported generic function without its
interface. Loaded-program type integration belongs to program/checker fixtures.

## Negative logic

Do not mistake a missing typing interface for a name-resolution error, suppress
unknown names, or equate two failed executions with correct behavior.

## Grill Log

- **Q:** Test reflection resolution using a whole compile without imported type
  interfaces? **A:** Isolate lexical resolution for this property, and separately
  test graph compilation. _Rationale:_ phase evidence must match its claim.
  _Rejected:_ ignoring arbitrary diagnostics or accepting an opaque missing scheme.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Name Resolution]] · [[Repository Test Runner]]
