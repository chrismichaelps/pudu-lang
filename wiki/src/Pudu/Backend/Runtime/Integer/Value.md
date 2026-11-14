---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer/Value.hs"
fidelity: Active
aliases: [Backend Integer Value]
grammar: "[[grammar/haskell]]"
---
# Backend Integer Value

## Purpose and interface

Export valueRuntimeParts :: [(Text, [Text])], an ordered pure C11 runtime-part
catalogue consumed by [[Backend Runtime Integer]]. Use Data.Text only; no IO,
frontend, evaluator, extra package or platform extension.

## Algorithm and invariants

Define pudu_int { uint64_t bits; int negative; }, pudu_int_kind
{ uint64_t positive_max, negative_max; unsigned width; int is_signed; } and
pudu_calculation { pudu_int value; int overflow; } in the integer_value part.
Normalize zero and derive magnitude from an unsigned word and actual-negative
flag. Expose magnitude/make helpers for mathematical kernels. Construct width
masks, decode wrapped words with explicit narrow-kind sign extension, and
compare same-sign unsigned words directly.
No signed narrowing or arithmetic is used. A positive high bit on a deferred
magnitude must not make comparison treat the value as negative.

The exact private ABI and operation boundary rules are specified in
[[Exact Native Integer Carriers]]. Runtime selection supplies every prerequisite
in emission order and omits unused static functions.

## Resolved Grill Log

- **Q:** May internal storage truncate a deferred literal? **A:** No; retain its exact magnitude and sign until an operation applies its specified result policy.
- **Q:** Are unsigned overflow and signed overflow interchangeable? **A:** No; only unsigned operations are used for potentially overflowing magnitude/bit calculations, with explicit carry/refusal/clamp decisions.
- **Q:** Does this module change checking or Pudu type width? **A:** No; it projects the interpreter's existing behavior through a private runtime revision.

## Dependencies and consumers

[[Backend Runtime Integer]] · [[Exact Native Integer Carriers]] · [[Diagnostic Arithmetic]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native C11 Backend Delivery]]

Resolved measured refinement: store bits rather than magnitude to avoid repeated wrapping conversions. Actual sign remains independent of the high bit for deferred values. All conversions stay unsigned and exact.
