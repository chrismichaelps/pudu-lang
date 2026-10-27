---
type: module
path: "@root/test/Pudu/Backend/FloatValueSpec.hs"
fidelity: Active
aliases: [Native Floating Value Tests]
grammar: "[[grammar/haskell]]"
---
# Native Floating Value Tests

## Purpose and interface

Export floatValueProperties :: [(String,IO Property)]. Compile actual selected
[[Native Floating Values]] as strict C11, honor PUDU_CC and require a compiler.
Use locked GHC Double arithmetic and FloatLiteral.normalizeFloat as the raw-bit
oracle. Check all result encodings, predicate flags, status, stderr and row count.

## Evidence contract

Exercise both widths with exceptional/signed-zero/extreme/subnormal operand
cross-products, each binary exponent class, seeded full-width pairs and binary32
midpoint neighborhoods. Normalize operands before width-sensitive arithmetic,
then test add/sub/mul/div/neg, six comparisons, direct normalization, exact
encode/decode round trips and a multiply-then-add chain. The chain must round at
each operation and cannot be contracted. Also retain independent locked values
for ties, subnormal conversion, signed zero and Float32-vs-Double precision.

Execute each public helper root with exactly its prerequisite closure, including
negation without any floating helper. Reject fast and finite-only C modes and
an injected wrong ABI dimension; require the expected diagnostic text. The
formatter and arithmetic helpers remain distinct contracts. Run Clang/GCC,
ASan/UBSan, fresh optimized warning gate and the complete repository gates.
Fixed returned properties are not independent repeated IO executions.

The normalization oracle has a NOINLINE boundary: GHC 9.14.1 constant-folds
a known double2Float/float2Double conversion without runtime Float32 rounding.
External optimized constant/dynamic probes reproduce the discrepancy; fixed
encodings calibrate runtime conversion rather than accepting changed goldens.

## Resolved Grill Log

- **Q:** Compare display only? **A:** Compare raw bits, including NaN sign/payloads and both zeros, before source integration.
- **Q:** Use only normalized finite inputs? **A:** Arithmetic operands are width-normalized; transport/normalization also exercise all raw encoding classes.
- **Q:** Quietly skip missing compilers? **A:** Fail the property.
- **Q:** Declare public float support from helper tests? **A:** No; Core/frame/source and supported-platform evidence remain required.

## Dependencies and consumers

[[Native Floating Values]] · [[Float Literal]] · [[Pudu Test Cabal Manifest]] · [[Repository Test Runner]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Floating Value Delivery]]
