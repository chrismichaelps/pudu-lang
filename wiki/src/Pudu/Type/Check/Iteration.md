---
type: module
path: "@root/src/Pudu/Type/Check/Iteration.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium, semantics]
aliases: [Type Check Iteration]
---

# Type Check Iteration

## Purpose

Decide the type a `for` loop's binder takes, from whatever is being iterated.

## Interface

```haskell
iterationElement :: Span -> Type -> Checker Type
```

### Governance

- **The binder used to be an unconstrained fresh variable.** `for x in [1, 2, 3]` left `x` free, so
  `x.length()` on a whole number passed the checker. A loop is the one place a binder's type is
  decided entirely by the value beside it, and deciding nothing there let every use of it through.
- A user type answers through its own `advance`, whose result shape `Option[(State, Item)]` is what
  `Std.Iter.Sequence` requires — the same method [[Evaluator]] calls to walk it. The type a `for`
  binds is therefore the type the loop will actually produce, not a guess that happens to agree.
- An unresolved type stays unconstrained rather than reported. Inference may still settle it, and
  refusing early would reject a program that is fine.
- References are followed before the shape is read, so iterating a borrow binds what iterating the
  value would.

### Linkage

- **Requires:** [[Type Env]], [[Type Unify]], [[Type Check Method]], [[Type Value]].
- **Consumed by:** [[Type Check]].

## Algorithm

Follow references to the underlying type, match the built-in sequence shapes directly, and otherwise
look for the `Sequence` implementation's `advance` and read the item out of its declared result.

## Negative Logic (Prohibited Paths)

- No expression checking; the iterated expression's type arrives already inferred.
- No reporting on an unresolved type.

## Referenced by

[[src/Pudu/Type/Check/_MOC]] · [[Type Check]] · [[architecture/STDLIB]]
