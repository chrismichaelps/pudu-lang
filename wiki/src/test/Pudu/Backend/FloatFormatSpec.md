---
type: module
path: "@root/test/Pudu/Backend/FloatFormatSpec.hs"
fidelity: Active
aliases: [Native Binary64 Formatter Tests]
grammar: "[[grammar/haskell]]"
---
# Native Binary64 Formatter Tests

## Purpose and interface

Export floatFormatProperties :: [(String,IO Property)]. Compile actual selected
formatter parts as strict C11, honoring PUDU_CC and requiring a compiler. Compare
raw binary64 outputs byte-for-byte with installed GHC show Double, the evaluator's
rendering oracle. Require each new helper root to compile with its exact closure.

## Evidence contract

Pin independent locked spellings for zero/-zero, fixed/exponent thresholds,
1e23, infinities, NaNs and widened Float32 0.1. Also require GHC show to retain
those spellings so a toolchain change cannot silently update both expectations.
Enumerate binary exponent endpoints with low/high fraction boundaries and both
signs, neighborhoods of decimal powers, widened binary32 boundaries and seeded
full-width bit patterns. Print actual unique-case counts. Flush each result;
compare line counts, process status and stderr as well as all payload bytes.
Surround the 32-byte output with canaries and require returned length <=31.
No representation domain may be skipped because a case is inconvenient.

Check emitted adapted roots contain the exact [[Native Floating Notices]] text.
Use Clang/GCC and ASan/UBSan, source-distribution notice inspection, real binary
archive notice/extraction checks and complete repository gates. Fixed returned
Properties are not independent repeated IO corpora. Public float source remains
refused until the subsequent typed integration slice.

## Resolved Grill Log

- **Q:** Round-trip equality alone? **A:** No; output bytes and locked GHC spellings must agree.
- **Q:** Test only normal finite inputs? **A:** Include every exponent class, subnormals, signed zeros and exceptional encodings.
- **Q:** Infer buffer safety from matching text? **A:** Check boundary canaries and the newline reserve explicitly.

## Dependencies and consumers

[[Native Binary64 Formatter]] · [[Native Floating Notices]] · [[Pudu Test Cabal Manifest]] · [[Repository Test Runner]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Binary64 Formatter Delivery]]
