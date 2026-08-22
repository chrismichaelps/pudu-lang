---
type: module
path: "@root/src/Pudu/Type/Check/Method.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Check Method]
---

# Type Check Method

## Purpose

Give an implementation's functions the types they have as methods of their target, and let an implementation inherit the trait defaults it does not override.

## Interface

### Signatures

```haskell
declareMethods :: DeclaredTypes -> Map Text [Located Function] -> Impl -> Checker ()
implAliases :: DeclaredTypes -> Impl -> DeclaredTypes
traitTable :: [Located Declaration] -> Map Text [Located Function]
```

### Governance

- A method is bound under a key naming the type it implements for, not at module scope. A trait method is reached through a value, which is why `show(user)` does not resolve while `user.show()` does.
- `Self` inside an implementation is its target type. That is what lets a method read the fields of the value it was called on, and it is why the alias is installed before the body is checked.
- `Self` inside a trait stays rigid: the implementing type is unknown while the trait itself is checked.
- A trait member that carries a body is a default. An implementation that does not provide its own gets it, bound at the target type exactly as an overriding method would be.
- Coherence — that the trait or the target is declared in this module — and overlapping-implementation rejection belong to a later slice; nothing here silently picks between candidates.

### Linkage

- **Requires:** [[Type Env]], [[Type Formation]], [[Type Value]], [[Syntax Tree]], [[architecture/SEMANTICS]].
- **Consumed by:** [[Type Check]].

## Algorithm

Form the implementation's target, bind each of its functions under the target's method key with `Self` aliased to the target, then bind every trait default the implementation did not override.

## Negative Logic (Prohibited Paths)

- No coherence or overlap checking, no dynamic dispatch, no associated types or constants, no bound satisfaction, and no method resolution across modules.

## Edge Cases

- An implementation whose target is not a named type contributes no methods rather than inventing a key.
- A default and an override with the same name bind once, with the override winning, because the override is bound first and the default is filtered out.

## Depth

DEPTH 0.55 (MEDIUM). It hides method keying, `Self` aliasing, and default inheritance behind two calls.

## Grill Log

- **Q:** Should methods live at module scope? **A:** No; they are keyed by their target type. _Rationale:_ two types may implement the same trait, and a flat scope would make one shadow the other. _Rejected:_ flat method names; a global method table keyed by name alone.
- **Q:** Field or method when both spell the same name? **A:** The method, in callee position only. _Rationale:_ `value.name()` reads as a call, and a field holding a function can still be called by parenthesizing it. _Rejected:_ field always wins, which makes a method unreachable; method always wins, which hides a field.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[Evaluator]]
