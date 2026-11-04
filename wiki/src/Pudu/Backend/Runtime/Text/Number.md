---
type: module
path: "@root/src/Pudu/Backend/Runtime/Text/Number.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Text Number]
---
# Native Text Number

## Purpose and interface

Export textNumberRuntimeParts and textNumberRuntimeDependencies: reading an
Int or a Float64 back out of text, for `toInt` and `toFloat`.

| Part | Provides |
| --- | --- |
| text_int_read | `pudu_text_parses_int` and `pudu_text_int_of` |
| text_float_read | `pudu_text_parses_float` and `pudu_text_float_of` |

## Semantics

`Eval.Builtin.TextNumber` decides what is a number. An Int is an optional
sign and one or more ASCII digits inside the platform Int range, leading
zeros allowed; `-0` is zero. A float is an optional sign, digits with at most
one point and digits on at least one side, and an optional `e`/`E` exponent
with its own sign and one to six digits. The value is the correctly rounded
binary64 of the digits, negated afterwards, so `-0.0` keeps its sign; an
infinite result is not a number.

## Resolved Grill Log

- **Q:** Why a validity test and a separate read? **A:** Lowering builds
  `Some`/`None` in Core from the two, so no C code has to know an Option's
  layout. Parsing twice costs little next to building the option.
- **Q:** Is `strtod` the evaluator's answer? **A:** For every text the
  validator admits, yes: the evaluator converts the exact rational and rounds
  once, and the C library's `strtod` is correctly rounded too. The shortcuts
  the evaluator takes for huge and tiny exponents land on infinity and zero,
  which is where exact rounding lands as well. The text handed to `strtod` is
  the validated digits only, so locale and hex forms never come into it.
- **Q:** Overflow while reading digits? **A:** The magnitude is checked before
  each step against 2^63, the most a negative Int can hold, then against
  2^63 − 1 for a positive one.

## Dependencies and consumers

[[Native Text Methods]] · [[Backend Runtime Integer]]

## Referenced by

[[Backend Runtime]] · [[Native Runtime Dependencies]] · [[src/Pudu/Backend/_MOC]]
