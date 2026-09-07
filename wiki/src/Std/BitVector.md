---
type: module
path: "@root/lib/Std/BitVector.pudu"
fidelity: Active
tags: [module, stdlib, bitvector, bits, low-level, data-structures]
aliases: [Std BitVector]
---
# Std BitVector

## Purpose

Provide a dense, contiguous, hardware-aligned bit-vector packed into 64-bit words (`Array[UInt64]`),
inspired by Haskell `bitvec` (Hoogle / Hackage) and Java `java.util.BitSet`.
Executes bitwise operations (AND, OR, XOR, NOT, popcount, bit scans) across 64 bits in parallel per CPU cycle, avoiding per-bit heap allocations.

## Interface

### Types
- `BitVector = { words: Array[UInt64], length: Int }`: Dense bit-vector with exact bit capacity.

### Constructors
- `create(bitLength: Int, initVal: Bool) -> BitVector`: Allocates a bit-vector of exact bit length, initialized to all zeros (`false`) or all ones (`true`).
- `fromBits(bits: &Array[Bool]) -> BitVector`: Constructs a bit-vector from a boolean array.
- `toBits(vector: &BitVector) -> Array[Bool]`: Converts to an array of boolean flags.

### Queries & Element Access
- `length(vector: &BitVector) -> Int`: Total number of addressable bits.
- `get(vector: &BitVector, index: Int) -> Option[Bool]`: Tests the bit at `index` (0-based). Returns `None` if out of bounds.
- `set(vector: &BitVector, index: Int, value: Bool) -> Option[BitVector]`: Returns a new vector with bit at `index` set to `value`.
- `flip(vector: &BitVector, index: Int) -> Option[BitVector]`: Inverts the bit at `index`.

### Bitwise SIMD-Style Word Operations
- `bitAnd(left: &BitVector, right: &BitVector) -> Option[BitVector]`: Word-by-word parallel 64-bit hardware bitwise AND.
- `bitOr(left: &BitVector, right: &BitVector) -> Option[BitVector]`: Word-by-word parallel 64-bit hardware bitwise OR.
- `bitXor(left: &BitVector, right: &BitVector) -> Option[BitVector]`: Word-by-word parallel 64-bit hardware bitwise XOR.
- `bitNot(vector: &BitVector) -> BitVector`: Word-by-word bitwise complement (masking trailing unused bits to zero).

### Metrics & Scans
- `popCount(vector: &BitVector) -> Int`: Total number of set bits (`1`s) using 64-bit SWAR popcount.
- `countZeros(vector: &BitVector) -> Int`: Total number of clear bits (`0`s).
- `findFirstSet(vector: &BitVector) -> Option[Int]`: Finds the 0-based bit index of the lowest set bit (`ctz` acceleration), or `None` if all zero.
- `findFirstZero(vector: &BitVector) -> Option[Int]`: Finds the 0-based bit index of the lowest clear bit.
- `isZero(vector: &BitVector) -> Bool`: Tests if all bits are zero in $O(N/64)$ word checks.
- `isOnes(vector: &BitVector) -> Bool`: Tests if all bits are one.

## Algorithm and boundaries

Bits are indexed little-endian within 64-bit words:
$$\text{wordIndex} = \text{bitIndex} \gg 6, \quad \text{bitOffset} = \text{bitIndex} \mathbin{\&} 63$$
Trailing bits in the final word beyond `length` are masked to `0u64` to prevent phantom bit leakage during parallel word operations and popcounts.
`findFirstSet` scans whole 64-bit words: words with `0u64` are skipped in a single comparison, and non-zero words use branchless trailing-zero count (`ctz`) via isolate-lowest-bit (`v & (-v)`) and bit-index lookup.
Execution speed scales at 64 bits per CPU arithmetic operation.

## Grill Log

- **Q:** How does `BitVector` differ from `Std.BitSet`?
  **A:** `Std.BitSet` is a sparse map (`Map[UInt64, UInt64]`) optimized for scattered integer identifiers with vast empty spans. `Std.BitVector` is a dense, contiguous array of 64-bit words designed for tight memory packing, SIMD-style parallel word operations, and deterministic linear bit addressing.
- **Q:** Why mask trailing bits in the final word?
  **A:** Without masking, bitwise NOT or partial word initialization would leave non-zero garbage bits beyond `length`. Masking ensures `popCount`, `isZero`, and bitwise comparisons remain mathematically sound.

## Referenced by

[[src/Std/_MOC]] · [[Std BitSet]] · [[architecture/STDLIB]]
