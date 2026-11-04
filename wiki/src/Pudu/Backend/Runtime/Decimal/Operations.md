---
type: module
path: "@root/src/Pudu/Backend/Runtime/Decimal/Operations.hs"
fidelity: Active
aliases: [Backend Decimal Operations]
grammar: "[[grammar/haskell]]"
---
# Backend Decimal Operations

## Purpose and interface

Export decimalOperationRuntimeParts and decimalOperationRuntimeDependencies:
Decimal parsing, the nearest binary64, `/` with its two failure sites,
display, and the helpers behind each `CoreDecimalMethod`.

## Algorithm and invariants

- Parsing is `parseDecimalText` on text trimmed as Data.Text strips it:
  underscores dropped, an exponent of at most 6144 in size, a sign, digits
  with at most one point. `Str.toDecimal` first refuses `_`, space, tab,
  newline and return anywhere.
- The nearest binary64 is built as its bits, rounding half to even with a
  sticky bit, subnormal near zero and infinite past the largest finite
  value, as `fromRational` gives it; no libm call is made.
- `toInt` is offered only for a whole number an Int can hold (#803).
- A rounding code 0 to 5 names its mode; any other is half-even.

## Resolved Grill Log

- **Q:** Evidence? **A:** 661 binary64 edge cases (exact 2^-1075 ties,
  halfway points, overflow) and 20,000 fuzzed parses against the port, under
  Clang with ASan/UBSan and GCC 15.

The parts follow the BigInt operations in [[Backend Runtime]], after the
text parts that display and parsing need.

## Referenced by

[[Native Decimal]] · [[Backend Decimal Values]] · [[src/Pudu/Backend/_MOC]]
