---
type: module
path: "@root/src/Pudu/Type/Check/Collection.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 3.0
interface_stability: 0.9
tags: [module, shallow, collections]
aliases: [Type Check Collection]
---

# Type Check Collection

## Purpose

Own collection-literal checks that must run after ordinary expression inference has received its
surrounding constraints.

## Interface

```haskell
requireConcreteSetLiteral :: Span -> Expression -> Type -> Checker ()
```

### Governance

- A direct `#{}` is valid while its element variable may still receive context. At a declaration,
  statement, return, or checked-expression boundary, an element variable that remains unresolved is
  `E3037` with an annotation example.
- Non-empty Sets and empty Sets whose context supplied `T` are unchanged. This module neither
  infers members nor defaults a type.

### Linkage

- **Requires:** [[Syntax Tree]], [[Type Value]], [[Type Unify]], [[Type Env]].
- **Consumed by:** [[Type Check]] and [[Type Check Statement]].

## Algorithm

Recognize the direct empty Set syntax, zonk the already-unified type, and report only when it is
still `Set[variable]`.

## Negative Logic (Prohibited Paths)

- No collection inference, member unification, operator typing, or recursive syntax search.
- No diagnostic before surrounding constraints have been applied.

## Depth

DEPTH 0.30 (SHALLOW by intent). One boundary predicate and one diagnostic.

## Grill Log

- **Q:** Put this in the closed operator module? **A:** No. _Rationale:_ empty-literal ambiguity is
  a post-inference collection boundary, not an operator; that module is already beyond the default
  size ceiling. _Rejected:_ adding unrelated boundary policy to [[Type Check Rule]].
- **Q:** Search nested expressions for unresolved empty Sets? **A:** No. _Rationale:_ enclosing
  calls and returns may constrain nested literals after their own inference. Each expression's
  normal boundary owns its constraint timing. _Rejected:_ an eager recursive scan.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[Type Check Statement]]
