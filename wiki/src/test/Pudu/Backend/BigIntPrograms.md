---
type: module
path: "@root/test/Pudu/Backend/BigIntPrograms.hs"
fidelity: Active
aliases: [Backend BigInt Programs]
---
# Backend BigInt Programs

Export bigIntSuccessPrograms and bigIntRefusalPrograms. Successes cover
literals past 128 bits, every operator on mixed signs, wrapping and
saturating forms, bit operations and shifts on negative values, a match
on a 129-bit literal, conversions to and from UInt8, Int, Int64, Int128 and
UInt128 (including the None answers), records, sums, maps, sets, tuples,
loops and closures holding BigInt, a 300! recursion, the 400th Fibonacci
number and thousand-bit shifts. Failures cover division and remainder by
zero, a negative shift count, and an entry BigInt exiting with 255 and 1.

## Resolved Grill Log

Expectations come from the tree interpreter and are rechecked against the
compiled evaluator; healthy programs also run under counted allocation.

## Dependencies and consumers

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[Native BigInt]] · [[src/Pudu/Backend/_MOC]]
