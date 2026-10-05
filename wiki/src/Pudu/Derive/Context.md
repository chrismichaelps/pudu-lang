---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/Context.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, expansion]
aliases: [Derive Residual Context]
---

# Derive Residual Context

## Purpose and interface

`Context` is what one residualization knows: reflected Meta references, the
canonical target and its fields or variants, descriptors bound by loops and
callbacks, known compile-time values, type substitutions, and the active
callback `Exits`. `Propagation` says how `?` lowers inside a callback:
`FailBuild` breaks the build with `Err`, `AnswerNone` answers the field's
`None`, `Unpropagated` leaves it ordinary.

Pure helpers: `descriptor`, `variantDescriptor`, `reflectedName`,
`typeArguments`, `attributes`, `shadow`, `foldBinary`, `fieldLabel`,
`variantLabel` and `writtenLiteral`.

## Invariants

`shadow` removes descriptors, known values and variant descriptors a nested
binding hides, so authored names always win. `fieldLabel` names a field as a
reader does (`Order.lines`, `Shape.Circle.0`) for E3092. `writtenLiteral`
answers an attribute argument's written form when its reader's fallback is
text, so `@default(0)` and `@default("0")` reach a text reader alike.

## Grill Log

- **Q:** Keep the context inside the residualizer? **A:** No; it is shared by
  the residualizer and callback unrolling and keeps both below 500 lines.
- **Q:** Coerce attribute literals in general? **A:** Only to text, and only
  for a text fallback. Other kinds answer their literal unchanged.

## References

Referenced by [[Derive Record Residualizer]] · [[Derive Field Callbacks]] ·
[[src/_MOC]].
