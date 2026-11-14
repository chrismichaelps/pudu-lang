---
type: module
path: "@root/src/Pudu/Backend/Runtime/Decimal/Value.hs"
fidelity: Active
aliases: [Backend Decimal Values]
grammar: "[[grammar/haskell]]"
---
# Backend Decimal Values

## Purpose and interface

Export decimalValueRuntimeParts and decimalValueRuntimeDependencies: the
Decimal carrier as C11 runtime parts, one per function.

## Algorithm and invariants

- `pudu_dec` is a reference count, a non-negative scale and a
  [[Backend BigInt Values]] coefficient; the value is coefficient / 10^scale.
  NULL is 0 at scale 0; any other zero keeps its scale for rendering.
- `+` and `-` align scales by powers of ten; `*` adds them; comparison
  aligns and compares, so 1.0 equals 1.00.
- Exact division reduces by the gcd and accepts a denominator with no prime
  factor but two and five, as `decimalDivideExact` does; otherwise it
  reports a zero divisor or a non-terminating quotient.
- Division to stated digits and rounding decide the last digit by the
  seven modes, as `roundedQuotient` does.
- Digits show exactly the scale's fractional places.

## Resolved Grill Log

- **Q:** Evidence? **A:** Differentially tested against a port of
  `Pudu.DecimalLiteral`: 45,000 random operations of every kind, all seven
  modes on ties, under Clang with ASan/UBSan and GCC 15.

## Referenced by

[[Native Decimal]] · [[src/Pudu/Backend/_MOC]]
