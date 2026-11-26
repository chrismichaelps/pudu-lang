---
type: module
path: "@root/src/Pudu/Type/Ownership/Pattern.hs"
fidelity: Active
domain: "[[Ownership]]"
subsystem: "[[Type Checker]]"
grammar: "[[grammar/haskell]]"
tags: [module, ownership, type]
aliases: [Type Ownership Pattern]
---

# Type Ownership Pattern

## Purpose

Check that a pattern over a value needing drop binds every part that needs
drop, so every value has an owner that will drop it. A type with its own
`Drop` is never taken apart, because its `drop` needs the whole value.

## Interface

`checkPattern :: Maybe Type -> Located Pattern -> Walk ()`.

## Algorithm

The subject's type decides whether the pattern is inspected at all. A type
that needs no drop may be matched freely.

For a subject that needs drop:

- a wildcard leaves the value behind: E4007 at the wildcard;
- a binding takes the whole value, which is the ordinary owning binder;
- a tuple checks each member against the corresponding part;
- a constructor checks each payload against the variant's declared payload,
  after substituting the use's type arguments;
- a record checks written fields against their field types, and an elided
  field that needs drop is E4007 at the pattern;
- alternatives check every alternative against the same subject.

Before descending into a nominal constructor or record pattern, the walk asks
whether the type implements `Drop`. If it does, the pattern is E4002: the
value must be bound whole and its fields read through that name.

## Negative Logic

An array pattern is not inspected here; arrays cannot hold values needing drop,
so the holder rule in [[Type Ownership]] refuses the value before a pattern
matters. A pattern whose subject type is unknown is not inspected.

## Edge Cases

`Some`, `Ok` and `Err` are constructors: their payloads are checked, and the
`None`/`Err` payload-less forms bind nothing. A nested `Option[Option[Res]]`
checks the inner pattern against the inner `Option`.

## Resolved Grill Log

- **Q:** Why refuse a wildcard over a droppable part instead of dropping it at
  the match? **A:** The value is being taken apart; a part left behind has no
  binding whose scope end could drop it. _Rationale:_ implicit destruction of
  a matched part would make the match a hidden owner.
- **Q:** Why is a `Drop` type refused even when every field is bound? **A:**
  Its `drop` runs on the whole value, and a pattern has already moved the
  fields out. _Rationale:_ the user's destructor would see a value it cannot
  clean up.
- **Q:** Why substitute type arguments here? **A:** A payload written as `T`
  may be `Res` at the use. _Rationale:_ the decision must follow the value the
  program actually matched.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Ownership]] · [[Type Drop]] · [[Type Check Pattern]]
