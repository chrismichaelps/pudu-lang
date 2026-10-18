---
type: module
path: "@root/test/Pudu/Backend/IntegerPrograms.hs"
fidelity: Active
aliases: [Backend Integer Programs]
---
# Backend Integer Programs

## Purpose and interface

Export integerSuccessPrograms :: [(String, Text, Text)] (label, source, expected stdout)
and integerRefusalPrograms :: [(String, Text)].
[[Backend Native Tests]] executes each checked source through the interpreter
and strict warning-free C11 compilation, comparing stdout/stderr/status.

## Coverage

Cover bitwise/complement, shifts at counts 0/1/63 and -1/64/extreme invalid
counts, wrapping and saturation across signed extrema and all sign pairs.
Use generated source matrices with parameterized functions to prevent constant
folding, and deterministic full-width samples from a fixed word generator for
independent mathematical expected stdout. The known seed is reproducible;
these samples complement explicit boundaries, not a proof over all integers.
Effects, reads before mutation, short circuit, abrupt operands, macros, Unicode
and tabbed source diagnostic spans remain observable. Separate helper-isolation
programs catch missing prerequisites and unused static functions.

## Resolved Grill Log

- **Q:** Only compare two implementations sharing a mistake? **A:** Include explicit expected mathematical stdout for generated samples, not only differential equality.
- **Q:** Compile every pair in a separate executable? **A:** Group matrices in ordinary helper functions to keep validation bounded while preserving runtime evaluation.
- **Q:** Admit other widths implicitly? **A:** No; width refusals remain in Backend Emit Tests.

## Dependencies and consumers

[[Backend Native Tests]] · [[Backend Runtime Integer]] · [[Pudu Core]]

## Referenced by

[[src/_MOC]] · [[Native Emission Coverage]] · [[Native C11 Backend Delivery]]
