---
type: module
path: "@root/src/Pudu/Eval/Drop.hs"
fidelity: Active
domain: "[[Ownership]]"
subsystem: "[[Evaluator]]"
grammar: "[[grammar/haskell]]"
tags: [module, evaluator, ownership]
aliases: [Eval Drop]
---

# Eval Drop

## Purpose

Run the drops a value's ownership end requires in the tree interpreter: the
type's own `drop` first, with the value still whole, then each part that needs
drop in declaration order.

## Interface

`dropValue :: CallNeeds -> Value -> Evaluator ()` and
`implementsDropAnywhere :: Map Text Value -> Bool`.

## Algorithm

`dropValue` matches the value's representation:

- a record drops its own `drop`, then its fields in declaration order;
- a sum drops its own `drop`, then its payload;
- a named sum drops its own `drop`, then its fields in declaration order;
- a tuple drops its members in order.

The own drop is found through the value's receiver owners: the first owner
with an installed `Drop.<owner>.drop` method runs as a lent closure with the
whole value as `self`, so the user's `&mut Self` sees the value before any
part is released.

`implementsDropAnywhere` looks for any installed method key with the `Drop.`
prefix. A program with no implementation pays nothing for drop scopes.

## Negative Logic

Arrays, maps, sets, tasks and other holders are not traversed. Ownership
checking refuses a value that needs drop inside them, so a value reaching
`dropValue` is a record, sum, named sum or tuple.

A value with no installed `Drop` method still drops its parts; a structural
type needs drop because a part does, not because it has its own method.

## Edge Cases

A value already emptied by a move is never passed here: the move cleared the
binding, and the scope's drop table no longer holds it. A sum's payload is
dropped even when the variant that holds it was not the one written at the
construction site, because the runtime value carries its variant.

## Resolved Grill Log

- **Q:** Why run the user's `drop` before the parts? **A:** The destructor is
  written against the whole value and may read fields the parts would release.
  _Rationale:_ declaration order after the whole value is the order the
  specification promises.
- **Q:** Why find the method through receiver owners instead of the static
  type? **A:** A dynamic value's concrete owner is known only at run time.
  _Rationale:_ the same lookup serves every value representation.
- **Q:** Why is `implementsDropAnywhere` a key scan? **A:** It decides whether
  a program needs drop scopes at all, before any value is dropped. _Rationale:_
  a program without `Drop` keeps the old scope cost.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Type Ownership]] · [[Eval Env]] · [[Compiler Lower Drop]]
