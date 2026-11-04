---
type: architecture
aliases: [Native Word128 Kernel Contract]
---
# Native Word128 Kernel Contract

Represent an unsigned 128-bit word as low + 2^64 * high, using two
uint64_t members. Keep all arithmetic portable C11 without integer extensions,
allocation or global state. This prerequisite does not admit Pudu types.

Addition returns low bits and carry; subtraction is modulo 2^128.
Multiplication returns low bits and full-product overflow. Comparison returns
-1/0/1. Shifts return zero at counts >=128 and guard every storage-width shift.
Division returns quotient/remainder, or zero values with a zero-divisor flag.
Retain the 129th remainder bit before reducing a high-bit divisor.

The ordered helper catalogue exposes dependency closure for later selective
emission. Callers supply stdint.h. Typed signed policies, source diagnostics,
frame integration and behavioral parity remain subsequent delivery obligations.

## Resolved Grill Log

- Carry: preserve high-word overflow and the separate incoming low carry.
- Product: each base-2^32 limb accumulation is bounded by UINT64_MAX.
- Shifts: branch on zero, subword, crossword and out-of-range counts first.
- Division: preserve the extra remainder bit; never use C division by zero.
- Evidence: execute real C against independent Integer answers, including flags.

## Referenced by

[[architecture/_MOC]] · [[Backend Word128 Kernel]] · [[Native Word128 Tests]]
