---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer/Convert.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Integer Conversion]
---
# Native Integer Conversion

## Purpose and interface

Export integerConversionRuntimeParts and integerConversionRuntimeDependencies:
whether an integer fits another kind, and the value at that kind once it
does, for `convertInteger`.

| Part | Provides |
| --- | --- |
| int_fits | a narrow value against a narrow kind |
| int_fits_wide | a narrow value against Int128 or UInt128 |
| wide_fits_int | a 128-bit value against a narrow kind |
| wide_fits | a 128-bit value against Int128 or UInt128 |
| int_to_wide / wide_to_int | the same value in the other representation |

## Semantics

`integerKindFits`: a value fits when it lies inside the kind's bounds, ends
included. Narrow kinds share one sign-and-bits form, so a narrow-to-narrow
conversion is the same value; only the test differs by kind.

## Resolved Grill Log

- **Q:** Why a test and a conversion rather than one call? **A:** Lowering
  builds `Some`/`None` in Core, so the C code never needs an Option's layout,
  and the conversion only ever runs on a value that fits.
- **Q:** Is negative zero possible? **A:** Values are normalised before the
  test, so zero is never negative.

## Dependencies and consumers

[[Backend Wide Integer Values]] · [[Backend Runtime Integer]]

## Referenced by

[[Backend Frame Values]] · [[src/Pudu/Backend/_MOC]]
