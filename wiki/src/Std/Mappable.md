---
type: module
path: "@root/lib/Std/Mappable.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.35
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.6
tags: [module, stdlib, medium]
aliases: [Std Mappable]
---

# Std Mappable

## Purpose

A trait over the container itself, so a definition that transforms what a container holds is written
once rather than once per container.

## Interface

3 exports: the `Mappable` trait with its single member `mapped`, and `over` and `filled` written
against it. Implementations ship for `Array`, `Option`, and [[Std Tree]].

### Governance

- `F` stands for a **constructor**, not a type. `F[_]` declares that it takes one argument, so a
  member may write `F[A]` and `F[B]` and mean the same container holding different things. This is
  what [[ADR-0014 Parameters of Higher Kind]] admits.
- The law asked of an implementation and **not checked**: transforming by a function that answers
  what it was given must leave the container as it was. A `mapped` that reordered, dropped, or
  duplicated satisfies the type and breaks every caller relying on the shape surviving.
- `over` and `filled` name no container. A definition that named one would prove nothing about the
  trait, which is the whole reason the trait exists.

### Linkage

- **Requires:** [[Std List]], [[Std Tree]].
- **Consumed by:** programs.

## Algorithm

Each implementation delegates to the `map` its own module already had. The trait adds no traversal;
it adds the ability to name one.

## Negative Logic (Prohibited Paths)

- No implementation for a constructor of other than one argument. `Result[T, E]` would need partial
  application, which [[ADR-0014 Parameters of Higher Kind]] deliberately excludes.
- No law checking. The shape-preserving law is documentation, and saying so is honest where implying
  enforcement would not be.

## Edge Cases

- An empty container transforms to an empty container of the new type.
- A single-node tree stays a single node; the shape is what `mapped` may not change.
- The transform may change the type held, which is what `F[A] -> F[B]` says and what a same-type
  signature would have hidden.

## Depth

DEPTH 0.35 (MEDIUM). One member, two implementations, and two definitions written against it.

## Grill Log

- **Q:** Why does this exist when every container already has `map`? **A:** Because those five
  `map`s could not be related to one another, so no definition could take the container it was given.
  _Rationale:_ `over` and `filled` are each written once here and serve every implementation; before
  parameters could stand for a constructor, each would have been written per container or not at
  all. _Rejected:_ leaving the per-container names alone, which is what shipped until now and is
  what this is measured against.
- **Q:** Why was `Option` missing at first? **A:** Because it would not have run. _Rationale:_ a
  trait implemented for a sum checked and then failed at the call, since the value is a variant and
  the member was looked for there. The implementation arrived once a variant found what its own sum
  implements, which is the shape the trait needed to be worth having: `Option` is the container a
  reader reaches for first.
- **Q:** Should the shape-preserving law be checked? **A:** It cannot be, and the documentation says
  so rather than implying otherwise. _Rationale:_ the law quantifies over every function a caller
  might pass, which is not something a type states. _Rejected:_ wording that suggests the compiler
  enforces it.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[ADR-0014 Parameters of Higher Kind]]
