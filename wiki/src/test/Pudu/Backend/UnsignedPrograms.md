---
type: module
path: "@root/test/Pudu/Backend/UnsignedPrograms.hs"
fidelity: Active
aliases: [Native Unsigned Programs]
---
# Native Unsigned Programs

## Purpose and interface

Export unsignedSuccessPrograms (label, source, mathematical stdout) and
unsignedRefusalPrograms (label, checked source) for UInt and UInt8/16/32/64.
Generate independent Integer reference answers for checked arithmetic, modular
and saturated arithmetic, bitwise/complement, logical shifts, comparison and
zero negation over endpoints/high-bit/deterministic full-width samples. Cover
context-selected literals and suffix/base forms, aliases/inference, mutation,
Never/loops and preserved high values. Runtime failures pin overflow, underflow,
division/remainder zero, nonzero negation and invalid shift counts.

## Resolved Grill Log

- **Q:** Use signed host arithmetic for golden answers? **A:** No; arbitrary Integer and the explicit nonnegative interval define expectations.
- **Q:** Test UInt64 only below 2^63? **A:** No; include its high bit and maximum everywhere.
- **Q:** Count repeats as random programs? **A:** No; these are fixed source matrices executed once per IO corpus.

## Dependencies and consumers

[[Backend Integer Programs]] · [[Backend Native Tests]] · [[Native Unsigned Integers]]

## Referenced by

[[src/_MOC]] · [[Native Unsigned Integer Delivery]]
