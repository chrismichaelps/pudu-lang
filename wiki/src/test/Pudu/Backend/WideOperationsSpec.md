---
type: module
path: "@root/test/Pudu/Backend/WideOperationsSpec.hs"
fidelity: Active
aliases: [Native Wide Operation Tests]
grammar: "[[grammar/haskell]]"
---
# Native Wide Operation Tests

## Purpose and interface

Export wideOperationProperties :: [(String, IO Property)]. Execute selected
[[Backend Wide Operations]] against independent Integer arithmetic, bounds,
wrap/clamp and bitwise/shift answers. Reuse existing test dependencies and
PUDU_CC/cc. Compile strict optimized C11 and inspect status/stdout/stderr.

## Algorithm and invariants

Use signed/unsigned endpoints, full-width deterministic samples, deferred
positive 2^127, negative/zero/127/128/deferred-high shift counts. Compare both
words and actual sign. A nonreturning failure stub records the supplied site
identity using setjmp/longjmp; no modified automatic variable is read after a
jump. Check zero-divisor, checked overflow, negative count and wide count
separately, including minimum/-1 versus minimum%-1. Minimal single-helper
selections reject missing dependencies/unused functions. No production helper
generates expected answers. Fixed IO corpora execute once, not 200 binaries.

## Resolved Grill Log

- **Q:** Replace source parity with a C stub? **A:** No; this proves primitive routing only, full source parity remains pending.
- **Q:** Check only successful arithmetic? **A:** No; exact failure identity is required for every invalid row.
- **Q:** Read changed locals after longjmp? **A:** No; use stable case metadata and a global failure identity.
- **Q:** Count primitive tests as full native admission? **A:** No; frame, print, status and language admission remain required.

## Dependencies and consumers

[[Backend Wide Operations]] · [[Pudu Test Cabal Manifest]] · [[Repository Test Runner]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Wide Integer Delivery]]
