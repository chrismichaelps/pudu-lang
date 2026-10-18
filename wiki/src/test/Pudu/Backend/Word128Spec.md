---
type: module
path: "@root/test/Pudu/Backend/Word128Spec.hs"
fidelity: Active
aliases: [Native Word128 Tests]
grammar: "[[grammar/haskell]]"
---
# Native Word128 Tests

## Purpose and interface

Export word128Properties :: [(String, IO Property)]. Build the actual
[[Backend Word128 Kernel]] with strict C11, warnings as errors and optimization;
execute it with tables generated from independent arbitrary-precision Integer
answers. Reuse process, directory, temporary, filepath, text and QuickCheck.
Use PUDU_CC when supplied so sanitizer wrappers exercise the same test path.

## Algorithm and invariants

Check ordered endpoint cross-products and deterministic full-width samples.
Compare both words of addition/subtraction/multiplication, carry/overflow,
ordering, zero flags and quotient/remainder. Exercise zero divisors explicitly.
Shift cases cover every count 0..129 plus a large unsigned count. Independent
Integer modulo, quotient, remainder and Data.Bits shifts supply the answers;
no production arithmetic helper generates expected values. C checks report the
failing case/operation and nonzero process status. Missing compilers fail this
required kernel gate; do not silently pass. Fixed IO corpora execute once even
when the runner repeats the returned property.

## Resolved Grill Log

- **Q:** Merely check emitted strings? **A:** Compile and execute the real kernel.
- **Q:** Compare only low words? **A:** Both words and metadata are independently checked.
- **Q:** Omit undefined-boundary shifts or zero divisors? **A:** Exercise their total raw-kernel contracts explicitly.
- **Q:** Claim 200 independent binaries? **A:** No; record the actual number of table rows executed.

## Dependencies and consumers

[[Backend Word128 Kernel]] · [[Pudu Test Cabal Manifest]] · [[Repository Test Runner]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Wide Integer Delivery]]

## Local evidence (#501)

Execute 1,097 arithmetic rows and 3,799 shift rows under Clang strict C11,
Clang ASan/UBSan and GCC 15. All pass. All 19 clean repository gates pass,
including 670 named groups. These are local macOS/arm64 results; independent
review and additional platform evidence remain pending. No typed native
Int128/UInt128 admission is implied.
