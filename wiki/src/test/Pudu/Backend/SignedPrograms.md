---
type: module
path: "@root/test/Pudu/Backend/SignedPrograms.hs"
fidelity: Active
aliases: [Native Signed Programs]
---
# Native Signed Programs

Deferred-boundary checks also pin checked settlement, wrapping, saturation and
right shifts at zero/one, including overflow when adding zero to the positive
boundary. Source values remain exact until those operations apply their policy.

## Purpose and interface

Export signedSuccessPrograms (label, source, independent stdout) and
signedRefusalPrograms (label, checked source). For each width 8/16/32/64, generate
matrices covering checked arithmetic, wrapping/saturation, bitwise, unary,
comparison and asymmetric shifts. Mathematical expectations use arbitrary
Integer arithmetic and explicit modular intervals, not production helpers.
Use boundary pairs and deterministic full-width samples. Additional programs
cover aliases/inferred signatures, selected unsuffixed literals, mutation/read
snapshots, loop results, Never, deferred boundary propagation and literal bases.
Failures cover each checked arithmetic boundary, division/remainder zero,
nonliteral negation and invalid shift counts with observable output prefixes.

## Resolved Grill Log

- **Q:** Merely compare native with an oracle sharing a bug? **A:** Independent Integer outputs also constrain success cases.
- **Q:** Count repetitions as new random programs? **A:** No; each deterministic source runs once per IO corpus.
- **Q:** Narrow deferred values to make matrices easier? **A:** No; explicitly preserve the positive boundary through calls and joins.

## Dependencies and consumers

[[Backend Integer Programs]] · [[Backend Native Tests]] · [[Native Signed Integers]]

## Referenced by

[[src/_MOC]] · [[Native Signed Integer Delivery]]
