---
type: architecture
tags: [architecture, backend, native]
aliases: [Native Decimal]
---
# Native Decimal

The interpreter holds a Decimal as an exact coefficient and a non-negative
scale ([[architecture/SEMANTICS]]). Native code holds a reference-counted
`pudu_dec *` ([[Backend Decimal Values]]) whose coefficient is the BigInt
carrier of [[Native BigInt]], an owned cell like text. Core carries it as
`CoreDecimalType`, `CoreDecimalLiteral` and `CoreDecimalMethod`.

`+ - *` and comparison are exact; `/` is exact or fails with E7004 on a
zero divisor and E7010, with its help, when the quotient does not terminate.
The primitives behind `Std.Decimal` and `Str.toDecimal` lower through
[[Compiler Lower Decimal]]. Rendering shows exactly the scale's digits.

## Resolved Grill Log

- **Q:** Reuse the BigInt carrier? **A:** Yes; a coefficient is an
  unbounded integer, and its division, gcd and digits are already proved.
- **Q:** Why build binary64 bits by hand? **A:** The runtime links no math
  library, and the bits carry the exact rounding `fromRational` does.
- **Q:** `toInt` past Int's range? **A:** The interpreter answered `Some` of
  an Int no Int holds; #803 makes it None, and native follows.

## Evidence

[[Backend Decimal Programs]] under both evaluators, Clang, GCC 15 and
ASan/UBSan, with zero live allocations; the carrier's own differential runs.

## First-class primitives (#806)

The seven Decimal prelude values use the existing builtin closure ABI and
the same Core answer builder as direct calls. The checked reference type
must equal the primitive's monomorphic signature. Option builders receive
the callable result explicitly; a function-valued reference fact is never
read as an Option. Rendering and equality identify the builtin tag, including
when returned from main. No new runtime representation or inference path.

Resolved Grill Log: share conversion and rounding bodies, evaluate arguments
once in source order, retain ordinary closure cleanup, and use uncounted
intrinsic frames. [[Native Decimal Callable Delivery]] records validation
and pending independent review.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]]
