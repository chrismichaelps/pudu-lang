---
type: module
path: "@root/test/Pudu/Backend/Word128Spec.hs"
fidelity: Active
aliases: [Native Word128 Tests]
---
# Native Word128 Tests

Export word128Properties. Compile the actual [[Backend Word128 Kernel]] using
-std=c11 -pedantic -O2 -Wall -Wextra -Werror, then execute it. Honor PUDU_CC;
a missing compiler fails. Reuse existing process, temporary and QuickCheck
packages. Compare both words and flags with independent Haskell Integer and
Data.Bits answers: 1,097 arithmetic rows and 3,799 shift rows.

Endpoint cross-products and deterministic full-width samples cover carry,
borrow, overflow, ordering, zero divisors and quotient/remainder. Shifts cover
0..129 and UINT_MAX. Failures report case and operation on stderr and require
nonzero status; successful execution requires empty stdout/stderr and zero
status. This raw kernel has no source diagnostic contract.

## Resolved Grill Log

- Execute real compiled C rather than compare emitted strings.
- Check upper words and metadata as well as low bits.
- Include high-bit divisors and all storage-width shift boundaries.
- Fixed IO tables run once; repeated QuickCheck results are not extra binaries.

## Dependencies and consumers

[[Backend Word128 Kernel]] · [[Pudu Test Cabal Manifest]] · [[Repository Test Runner]]

## Referenced by

[[src/_MOC]] · [[Native Word128 Publication]]

## Focused evidence

The complete tables pass Clang, GCC 15 and Clang ASan/UBSan on macOS arm64.
Forced GHC -Wall -Werror compilation and both manifest checks pass. Full CI
and independent review remain pending in [[Native Word128 Publication]].
