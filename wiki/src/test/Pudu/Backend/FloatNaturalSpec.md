---
type: module
path: "@root/test/Pudu/Backend/FloatNaturalSpec.hs"
fidelity: Active
aliases: [Native Floating Natural Tests]
grammar: "[[grammar/haskell]]"
---
# Native Floating Natural Tests

## Purpose and interface

Export floatNaturalProperties :: [(String, IO Property)]. Compile and execute
actual C11 from [[Native Floating Natural Kernel]] with independent Haskell
Integer expectations and existing text/process/temp dependencies. Honor PUDU_CC
and require a compiler. Print actual corpus sizes; fixed returned Properties
are not independent repeated IO executions.

## Evidence contract

Cover zero, single-/cross-limb endpoints, full 1280-bit bounds, binary64-related
1075/1127-bit temporaries, seeded dense/sparse values and aliasing outputs.
Pin success results and atomic failure preservation for oversized shifts,
add/multiply/scale overflow, subtraction underflow, zero division and quotient
>=10. Check normalized length and every value limb. Large shift/exponent
inputs must terminate without undefined C operations or proportional work.
Compile every individual root with exactly the declared prerequisite closure.
Use strict Clang/GCC C11 and ASan/UBSan, followed by complete repository gates.

## Resolved Grill Log

- **Q:** Use the production kernel to calculate expected words? **A:** No; arbitrary Integer arithmetic defines success, capacity and expected outputs.
- **Q:** Compare only low limbs? **A:** Check all 1280 bits and normalized length, including unchanged sentinels on failure.
- **Q:** Mask missing dependencies with all helpers? **A:** Also compile and run each root independently.
- **Q:** Describe this as admitted Float/BigInt coverage? **A:** No; exact formatting and source integration remain separate requirements.

## Dependencies and consumers

[[Native Floating Natural Kernel]] · [[Pudu Test Cabal Manifest]] · [[Repository Test Runner]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Floating Natural Delivery]]
