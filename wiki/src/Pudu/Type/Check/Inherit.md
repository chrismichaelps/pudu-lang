---
type: module
path: "@root/src/Pudu/Type/Check/Inherit.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, traits]
aliases: [Type Check Inherit]
---

# Type Check Inherit

## Purpose

Decide which trait defaults an implementation inherits, and keep a default's
own type parameters apart from the implementation's when the default is
declared on the implementing type.

## Interface

```haskell
inheritedMembers :: Set (NominalId, Text) -> NominalId -> Trait -> Impl -> [Located Function]
renameApart :: [Text] -> [(Text, Int)] -> ([(Text, Int)], [(Text, Type)])
selfArguments :: [Text] -> Impl -> [Type]
```

- `inheritedMembers` answers the trait's members that carry a body, or that an
  interface records as defaults after stripping their bodies, and that the
  implementation does not provide itself.
- `renameApart taken parameters` renames each parameter whose name is in
  `taken` to the first name ending in primes that is not taken, and answers the
  renamed list beside the replacements that perform the renaming.
- `selfArguments parameters impl` answers the arguments `Self` carries inside
  the implementation: a written argument naming one of `parameters` is that
  rigid parameter, and anything else is formed as written.

## Invariants

- An inherited default takes its trait member's declared scheme and is then substituted:
  `Self` becomes the target, each trait parameter the implementation's argument,
  and each of the method's own parameters that shares a name with one of the
  implementation's becomes its renamed form. The substitution is simultaneous.
- A renamed parameter keeps its arity, and its bounds move with it.

## Grill Log

- **Q:** Why rename at all? **A:** `fn map[B](self: &Self, f: fn(T) -> B)` on
  `impl [S, A, B, Q: Seq[S, A]] Seq[S, B] for Mapped[Q, A, B]` makes the trait's
  `T` the implementation's `B`. Without renaming the method's own `B` would be
  the same rigid type, and `.map(|n| n.toText())` on a mapped Int sequence
  reports `expected Str, found Int`. _Rejected:_ forbidding shared names, which
  would make a generic trait's defaults depend on how each implementation
  happens to name its parameters (#528).
- **Q:** Rename every method parameter, colliding or not? **A:** No; only a
  collision changes meaning, and unchanged names keep diagnostics readable.

## Dependencies and consumers

- **Requires:** [[Type Value]], [[Syntax Tree]].
- **Consumed by:** [[Type Check Method]].

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check Method]]
