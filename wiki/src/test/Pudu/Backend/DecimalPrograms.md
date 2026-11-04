---
type: module
path: "@root/test/Pudu/Backend/DecimalPrograms.hs"
fidelity: Active
aliases: [Backend Decimal Programs]
---
# Backend Decimal Programs

Export decimalSuccessPrograms, decimalLeakPrograms and
decimalRefusalPrograms. Successes run `Std.Decimal`'s primitives, every
operator across signs and scales, the seven rounding modes on ties and
non-ties, exact and rounded division, parsing with separators and
exponents, `Str.toDecimal`, conversion to Float64 and Int, records, sums,
maps and sets; one needs no library and also runs under counted
allocation. Failures cover division by zero, a non-terminating quotient with
its help, an entry Decimal, and a long exact sum before a failing quotient.

## Dependencies and consumers

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[Native Decimal]] · [[src/Pudu/Backend/_MOC]]
