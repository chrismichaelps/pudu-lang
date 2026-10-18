---
type: module
path: "@root/test/Pudu/Backend/WideValueSpec.hs"
fidelity: Active
aliases: [Native Wide Value Tests]
grammar: "[[grammar/haskell]]"
---
# Native Wide Value Tests

## Purpose and interface

Export wideValueProperties :: [(String, IO Property)]. Execute actual C from
[[Backend Wide Integer Values]] against independent Integer answers for
make/magnitude/normal/from-bits/compare/limit and requested negative zero.
Compile and run each raw/wide single-helper dependency closure independently,
including type-only selection, so missing dependencies and unused functions
fail strict C11 warnings. Use PUDU_CC or cc; missing compiler is a failure.

## Algorithm and invariants

Reuse existing text/process/directory/filepath/temporary/QuickCheck packages.
Use explicit full-width boundary and deterministic sampled values. Compare both
words and actual sign against Integer calculations, never production helpers.
Compile with -std=c11 -pedantic -O2 -Wall -Wextra -Werror; inspect status, stdout
and stderr. Honor sanitizer wrappers and run GCC separately. Fixed IO corpora
execute once; 200 repeated properties are not 200 independent binaries.

## Resolved Grill Log

- **Q:** A full catalogue can hide missing edges? **A:** Execute every individual helper's closure as well.
- **Q:** Use production comparison to verify all values? **A:** No; directly compare words and sign against independent constants.
- **Q:** Omit transient negative zero? **A:** Check preserved make sign and explicit normalization separately.
- **Q:** Count this as typed emission? **A:** No; operation policies and source integration remain pending.

## Dependencies and consumers

[[Backend Wide Integer Values]] · [[Backend Word128 Kernel]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Wide Integer Delivery]]

## Local evidence (#502)

75 values, 5,625 comparisons and 16 independent helper selections pass as
strict C11 under Clang, GCC 15 and Clang ASan/UBSan on macOS/arm64. The raw
kernel corpus remains unchanged and passes. All 19 clean repository gates
pass with 672 named groups. Additional platforms and independent review
remain pending; primitive values do not imply typed source admission.
