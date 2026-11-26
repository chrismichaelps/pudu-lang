---
type: module
path: "@root/src/Pudu/Type/Drop.hs"
fidelity: Active
domain: "[[Ownership]]"
subsystem: "[[Type Checker]]"
grammar: "[[grammar/haskell]]"
tags: [module, ownership, type]
aliases: [Type Drop]
---

# Type Drop

## Purpose

Decide which types need drop. A type needs drop when it implements the prelude
`Drop`, or when it stores a part whose type needs drop. The answer drives the
ownership walk, the interpreter's drop scopes and native glue emission.

## Interface

`dropTrait`, `isDropTrait`, `needsDrop`, `implementsDrop`,
`substituteParameters`.

## Algorithm

`dropTrait` resolves `Drop` as the module under check sees it. A module that
declares its own `Drop` trait names that one, and it is not the drop trait.
`isDropTrait` accepts the prelude identity, written with or without its
`Core.Prelude` qualification.

`needsDrop` walks the formed type:

- a tuple needs drop when any member does;
- a restricted type is decided by its inner type;
- a nominal type implementing `Drop` needs it;
- `Option`, `Result`, `Array`, `Map`, `Set`, `Range`, `Task` and `Buckets`
  need drop when an argument does;
- any other nominal type is decided by its declared fields or variant
  payloads, with the use's type arguments substituted for the declaration's
  parameters.

References and function types never need drop: they borrow or hold nothing
the ownership check admits. A nominal type already being visited answers
`False`, so a self-holding type without its own `Drop` does not need one.

## Negative Logic

An unsettled or rigid type is not decided here. The ownership check refuses
the instantiation instead of assuming a copy or a drop.

A module's own `Drop` trait is not the prelude's; implementing it neither
needs nor runs a drop.

## Edge Cases

A record whose only droppable part is behind an `Option` needs drop when that
`Option`'s argument does. A sum needs drop when any variant payload does, even
if no written constructor uses that variant.

## Resolved Grill Log

- **Q:** Why is a cycle treated as "no drop" rather than an error? **A:** A
  type that only holds itself has no resource at the bottom, so there is
  nothing to release. An own `Drop` still answers `True` before the cycle
  guard applies. _Rationale:_ recursive data stays ordinary data.
- **Q:** Why include `Array`, `Map` and `Set` as holders if the checker refuses
  to store droppable values in them? **A:** The refusal is stated in terms of
  the element type, and `needsDrop` must answer for the aggregate the reader
  wrote. _Rationale:_ the diagnostic names the holder, not a missing decision.
- **Q:** Why substitute parameters here instead of at each caller? **A:** The
  declaration's parts are written in its own parameters; only the use knows
  the arguments. _Rationale:_ one substitution rule serves patterns, fields
  and payloads.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Ownership]] · [[Type Ownership Pattern]] · [[Eval Drop]] · [[Compiler Lower Drop]]
