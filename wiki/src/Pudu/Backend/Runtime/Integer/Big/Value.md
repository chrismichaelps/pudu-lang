---
type: module
path: "@root/src/Pudu/Backend/Runtime/Integer/Big/Value.hs"
fidelity: Active
aliases: [Backend BigInt Values]
grammar: "[[grammar/haskell]]"
---
# Backend BigInt Values

## Purpose and interface

Export bigValueRuntimeParts and bigValueRuntimeDependencies: the exact
BigInt carrier as C11 runtime parts, one part per function so a program
holds only the functions it reaches.

## Algorithm and invariants

- `pudu_big` is a reference count, a sign and a magnitude of 32-bit limbs,
  least significant first, with no high zero limb. NULL is zero, so a zero
  slot costs nothing and never needs a release.
- Addition and subtraction work on magnitudes with 64-bit carries;
  multiplication is schoolbook with 64-bit partial products.
- Division is Knuth's algorithm D on normalized limbs; `pudu_big_divide`
  truncates toward zero and gives the remainder the dividend's sign, as
  `quot` and `rem` do.
- `&`, `|` and `^` act on the infinite two's-complement patterns, widened
  by one sign limb; `~x` is `-x - 1`.
- `<<` is exact; `>>` is arithmetic, rounding a negative value toward
  negative infinity, as shifting its two's-complement pattern does.
- Decimal digits come from repeated division by 10^9.

## Negative logic

A size that cannot be allocated, a magnitude whose limb count overflows a
size, or a shift whose limb count does so ends in `pudu_memory_failure`.

## Resolved Grill Log

- **Q:** Sign-magnitude or two's complement? **A:** Sign-magnitude; only
  the bit operations need the pattern, and they build it for the operation.
- **Q:** Evidence? **A:** The carrier was differentially tested against
  arbitrary-precision answers: 80,000 random operations of every kind and
  217,800 structured divisions that exercise the quotient correction, under
  Clang with ASan/UBSan and GCC 15, all with `-Wall -Wextra -Werror`.

## Dependencies and consumers

[[Backend Runtime Integer]] registers the parts; [[Backend BigInt Operations]] calls them.

## Referenced by

[[Native BigInt]] · [[src/Pudu/Backend/_MOC]]
