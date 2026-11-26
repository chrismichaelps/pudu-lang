---
type: module
path: "@root/src/Pudu/Type/Ownership/Declaration.hs"
fidelity: Active
domain: "[[Ownership]]"
subsystem: "[[Type Checker]]"
grammar: "[[grammar/haskell]]"
tags: [module, ownership, type]
aliases: [Type Ownership Declaration]
---

# Type Ownership Declaration

## Purpose

Check that an implementation of `Drop` has exactly the shape the runtime
calls. The implementation is a declaration, not a body the program may invoke.

## Interface

`checkDropImplementation :: Located Declaration -> Checker ()`.

## Contract

An implementation of the prelude `Drop` is valid only when:

- its target is a record or sum the program declares—not a builtin type, a
  type parameter or `Self`;
- it has exactly one member, named `drop`;
- the member is not async and has no type parameters;
- its result is unit, written or omitted;
- its only parameter is named `self` and has type `&mut Self`.

Anything else is E4008 at the target, the member or the implementation, with a
help that shows the required spelling.

## Negative Logic

`Drop` cannot be implemented for a builtin or an alias target. A trait with a
different name is not checked here, even if it declares a `drop` member.

## Edge Cases

A missing result annotation is accepted as unit, matching a Pudu function that
writes no result. A `Self` target is refused because it names no declaration
whose values could be cleaned up.

## Resolved Grill Log

- **Q:** Why require `&mut Self` rather than any receiver? **A:** Drop runs
  with the value still whole and may clear the fields it owns. _Rationale:_ a
  shared receiver could not release a field, and a by-value receiver would
  move the value out of the frame that is dropping it.
- **Q:** Why refuse a generic `Drop` implementation? **A:** A generic body
  would need a drop obligation for every instantiation, and v1 has no such
  obligation. _Rationale:_ the boundary is stated instead of silently
  specializing.
- **Q:** Why report at the target for a builtin implementation? **A:** The
  reader can point at the type that has no declaration to clean up.
  _Rationale:_ the member shape is not the first thing wrong.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Ownership]] · [[Type Drop]] · [[Semantics]]
