---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer/Bits.hs"
fidelity: Active
aliases: [Backend Integer Bits]
grammar: "[[grammar/haskell]]"
---
# Backend Integer Bits

## Purpose and interface

Export bitRuntimeParts :: [(Text, [Text])], an ordered pure C11 runtime-part
catalogue consumed by [[Backend Runtime Integer]]. Use Data.Text only; no IO,
frontend, evaluator, extra package or platform extension.

## Algorithm and invariants

Own bitwise/complement, wrapping and shift operations. Convert through
unsigned bit patterns; normalize width on result. Shifts validate actual count
sign/magnitude before any C shift. Right shift sign-fill uses the value's actual
negative flag only for signed kinds; count zero still wraps the result. Guard
zero before the width-minus-count fill shift. Limits are generated constants
for admitted widths 1..64; this does not admit unsupported Pudu kinds.

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
