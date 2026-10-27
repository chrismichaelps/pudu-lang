---
type: module
path: "@root/test/Pudu/Backend/WideValueSpec.hs"
fidelity: Active
aliases: [Native Wide Value Tests]
---
# Native Wide Value Tests

Export wideValueProperties. Execute emitted C for 75 full-width/endpoint
values and 5,625 ordered comparisons against independent Integer answers.
Check both words, sign, make/magnitude/normal/from-bits/compare/limit and
transient negative zero. Compile and execute all 16 raw/wide helper selections
with their dependency closures, including type-only selections.

Use PUDU_CC or cc; a missing compiler fails. Existing text, containers,
process, directory, filepath, temporary and QuickCheck packages suffice.
Compile with -std=c11 -pedantic -O2 -Wall -Wextra -Werror. Require successful
status and empty compiler/program stdout/stderr. Report failing checks with
line/operation. Fixed IO tables execute once per property build.

## Resolved Grill Log

- Expected words/signs and comparisons come from Integer, not production code.
- Minimal helper selections catch missing dependencies and unused functions.
- Check both preserved negative zero and normalized value behavior.
- Primitive carrier tests do not prove typed source emission or diagnostics.

## Dependencies and consumers

[[Backend Wide Integer Values]] · [[Backend Word128 Kernel]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[src/_MOC]] · [[Native Wide Value Publication]]
