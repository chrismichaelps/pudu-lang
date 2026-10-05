---
type: module
path: "@root/src/Pudu/Type/Substitute.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, types]
aliases: [Type Substitution]
---

# Type Substitution

## Purpose and interface

`substituteRigid :: [(Text, Type)] -> Type -> Type` replaces rigid parameters in
formed types without inference, mutation or obligations. One map is built per
substitution and shared through the recursive walk.

## Algorithm and invariants

Traverse nominal arguments, tuples, references, applied heads, function inputs and
results, and unsafe wrappers. Preserve function required-argument counts and
capabilities exactly. Collapse higher-kind applications when the replacement head
is a known constructor; preserve open heads. Variables, poison, unit, never and
dynamic nominal identities are unchanged.

## Negative logic and edge cases

No unification, fresh variables or recursive replacement of a substituted binder.
An absent binder remains rigid. Empty application arguments return the head.
Replacements are simultaneous, including mutually named parameters.

## Grill Log

- **Q:** Duplicate substitution for derive contracts? **A:** Share one pure
  utility with ordinary scheme instantiation and member substitution.
  _Rationale:_ default arity and unsafe wrappers must survive every path.
  _Rejected:_ repeated partial traversals that lose function metadata.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check Derive]] · [[Type Check Rule]]
