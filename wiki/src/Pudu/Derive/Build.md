---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Build.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, expansion]
aliases: [Derive Field Callbacks]
---

# Derive Field Callbacks

## Purpose and interface

`unrollCallback` unrolls a field callback, the function literal passed to
`Meta.build`, `Meta.collect`, `variant.build` or `variant.collect`, once per
field. `Gather` selects a construction (`Construct`) or an array (`Collect`).
`Walkers` carries the residualizer's own block, expression, type and
requirement walkers, so this module reaches back into [[Derive Record
Residualizer]] without a cyclic import. `exitWith`, `propagateTo` and
`answerNone` build the labelled breaks that lowered `return` and `?` use.

## Algorithm and invariants

Each copy binds the callback parameter to the field descriptor and its field
type F to the field's own type; `where` bounds become located field
obligations exactly as in a compile-time loop. A body that took an exit is
wrapped in `@__derive_value_N loop { break @__derive_value_N body }`, so
`return` answers the field's value. A `Result[F, E]` build binds every field
through a match that breaks `@__derive_build_N Err(e)`, then answers
`Ok(construction)`, so the first `Err` wins in declaration order. A
construction is one record literal or one canonical variant constructor.

A collect answers `Option[E]` per field. An answer that folded to `None` is
left out and one that folded to `Some(x)` contributes `x`; when every answer
folded the result is the array literal a person would write. Otherwise a
generated local accumulates the answers in declaration order. `?` in a collect
callback answers that field's `None`.

Labels and binders carry the unrolling depth and a `__derive_` prefix authored
code cannot write, so nested callbacks never capture each other's exits.

## Grill Log

- **Q:** Lower a Result build with nested matches, a closure, or a labelled
  loop? **A:** A labelled loop with one binding per field. _Rationale:_ flat,
  allocation-free, and identical in both evaluators. _Rejected:_ nesting depth
  proportional to field count; a closure per field.
- **Q:** Encode skips and renames with runtime pushes? **A:** No; `collect`
  folds to a literal. _Rationale:_ the measured push form was 25% slower than a
  hand-written literal, and user impls may redefine `push` on arrays, so a
  peephole over pushes would be unsound. _Rejected:_ rewriting `push` chains.
- **Q:** Decide `None` answers at run time? **A:** Only when folding could not.
  A compile-time `None` vanishes from the literal.

## References

Requires [[Derive Residual Context]], [[Derive Residual State]], [[Derive Sum
Residualizer]] and [[Syntax Tree]]. Referenced by [[Derive Record
Residualizer]] · [[Derive Design]] · [[src/_MOC]].
