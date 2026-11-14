---
type: architecture
tags: [architecture, backend, native]
aliases: [Native BigInt]
---
# Native BigInt

The interpreter holds a BigInt as an unbounded integer of kind
`BigIntKind`; every integer operator applies, none can overflow. Native code
holds one as a reference-counted `pudu_big *` ([[Backend BigInt Values]]),
an owned cell like text: frames retain it on read and release it when a
slot is replaced or the frame ends, and aggregates, arrays, maps and sets
hold it as a member of their own.

Operators go through the integer ABI with a `big_` prefix
([[Backend BigInt Operations]]): `/` truncates and `%` takes the dividend's
sign, division by zero and a negative shift fail with the shared
diagnostics, and the wrapping and saturating forms equal the exact ones.
Rendering is decimal. `convertInteger` reaches every kind both ways, with
None when the value does not fit. A literal builds its limbs where it runs.

## Resolved Grill Log

- **Q:** Hold small values inline? **A:** No; NULL already makes zero free,
  and one representation keeps every helper total. A small-value fast path
  is a measurement away, not a semantic question.
- **Q:** Why one runtime part per function? **A:** Generated C is held to
  zero warnings, and Clang reports an unused static inline function in the
  program file; parts sized to a function keep only what is called.

## Evidence

[[Backend BigInt Programs]] under both evaluators, Clang, GCC 15 and
ASan/UBSan, with zero live allocations.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]]
