---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer/Arithmetic.hs"
fidelity: Active
aliases: [Backend Integer Arithmetic]
grammar: "[[grammar/haskell]]"
---
# Backend Integer Arithmetic

## Purpose and interface

Export arithmeticRuntimeParts :: [(Text, [Text])], an ordered pure C11 runtime-part
catalogue consumed by [[Backend Runtime Integer]]. Use Data.Text only; no IO,
frontend, evaluator, extra package or platform extension.

## Algorithm and invariants

Own unsigned-magnitude addition/subtraction/multiplication kernels and
checked/saturating result settlement, plus negation, division and remainder.
Raw arithmetic retains overflow sign even if the low magnitude wraps to zero.
Checked settlement applies sign-specific kind limits and the provided failure
site, then normalizes zero. Saturation clamps before normalization. Subtraction
flips the second sign without checked unary negation. Division checks zero
before unsigned magnitude division, then checks the quotient; remainder retains
the dividend sign and only checks zero, matching the interpreter.

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

## Measured canonical addition path

For signed width 64, require both actual-negative flags to equal their unsigned
words' high bits before applying the unsigned signed-overflow predicate.
Noncanonical positive 2^63 and other widths use the full magnitude path. After
checked/clamped settlement, from_bits decodes the already proven in-range result
at its kind. Resolved Grill Log: the optimization has an explicit canonical
precondition, keeps the deferred path, and uses no signed C overflow or narrowing.
The local wrapping regression motivated bits/sign storage; remaining checked
kernel overhead is recorded in [[Exact Native Integer Carriers]].
