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
maps and sets; three need no library and also run under counted
allocation. Failures cover division by zero, a non-terminating quotient with
its help, an entry Decimal, and a long exact sum before a failing quotient.

## Callable regressions (#806)

All seven primitives run through values, including aliases, captured values,
higher-order calls, collections, equality/rendering and source-order effects.
Explicit answers cover parsing failures and zero division as None. Entry
results cover builtin rendering; argument failures preserve interpreter
diagnostics and stop later arguments. The library-free callable successes
also run in the counted-allocation corpus.

Resolved Grill Log: expected output is handwritten independently of both
execution engines. Reuse existing Decimal success/refusal groups so the
ordinary compiler matrix exercises these paths without a second harness.

## Dependencies and consumers

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[Native Decimal]] · [[src/Pudu/Backend/_MOC]]
