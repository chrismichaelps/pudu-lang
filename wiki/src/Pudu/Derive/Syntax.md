---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Syntax.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, expansion]
aliases: [Derive Syntax]
---

# Derive Syntax

## Purpose and interface

`sameTypeShape` compares complete written type structure without source locations.
`patternNames` finds lexical pattern binders. `instantiatePattern` retags every
pattern and nested name inside the existing bounded Residual state; `retag` is the
shared Located identity boundary. `isStaticValue` recognizes pure literal/tuple/
array values and literal unary expressions for compile-time array unrolling.

## Invariants and negative logic

Preserve reference mutability, function asyncness, unsafe capabilities, generic
applications and all pattern payload forms. No AST parsing, guessed canonical
owner, expression evaluation, mutable state, scope flattening or source strings.
An unrolled value is traversed and retagged again where it is inserted so no
integer-kind or expression identity is shared between distinct generated nodes.

## Grill Log

- **Q:** Duplicate source-independent type/pattern helpers in each kernel?
  **A:** Share one bounded syntax owner. _Rejected:_ Record growing beyond the
  source-size contract or comparing ASTs with their authored positions.
- **Q:** Treat every array expression as a compile-time list? **A:** Its members
  must be statically known pure values; unsupported calls cannot run at runtime
  as a metadata fallback. _Rejected:_ dropping effects or guessing unknown values.

## Linkage and references

Requires [[Derive Residual State]], [[Syntax Tree]] and [[Source]]. Referenced by
[[Derive Record Residualizer]] · [[Derive Graph]] · [[src/_MOC]].
