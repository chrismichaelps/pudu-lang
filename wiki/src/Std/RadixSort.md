---
type: module
path: "@root/lib/Std/RadixSort.pudu"
fidelity: Active
tags: [module, stdlib, sort, radix-sort, lsd, linear-time, low-level, algorithms]
aliases: [Std RadixSort]
---
# Std RadixSort

## Purpose

Provide a non-comparative, linear-time $O(N)$ Least Significant Digit (LSD) Radix Sort for 64-bit unsigned and signed integers, inspired by Haskell `Data.Vector.Algorithms.Radix` (Hoogle / Hackage) and Java numeric sorting.
Eliminates branch mispredictions and comparison overhead by operating directly on hardware byte slices with 256-bucket counting histograms.

## Interface

### Functions
- `sortU64(values: &Array[UInt64]) -> Array[UInt64]`: Sorts an array of 64-bit unsigned integers in strict $O(8 \cdot N)$ time.
- `sortInt(values: &Array[Int]) -> Array[Int]`: Sorts an array of 64-bit signed integers in strict $O(8 \cdot N)$ time, using sign-bit inversion on the final pass to order negative numbers before non-negative numbers without branching.
- `sortU32(values: &Array[UInt32]) -> Array[UInt32]`: 4-pass $O(4 \cdot N)$ radix sort for 32-bit unsigned words.

## Algorithm and boundaries

1. **8-Pass Counting Histogram:**
   A 64-bit word consists of 8 bytes. For each pass $p \in \{0 \dots 7\}$:
   - Extract byte key: $\text{bucket} = (v \gg (p \times 8)) \mathbin{\&} \text{0xFF}$.
   - Compute frequency histogram over 256 buckets.
   - Transform counts into prefix positions.
   - Scatter elements into a secondary buffer.
2. **Signed Two's Complement Ordering:**
   On the 8th pass (bits 56..63), the sign bit (bit 63) indicates negativity. To order negative numbers before positive numbers without comparison branches, the sign bit is inverted:
   $$\text{bucket}_7 = \left(\frac{v \gg 56}{\text{}} \mathbin{\&} \text{0xFF}\right) \oplus \text{0x80}$$
   This naturally maps $[-2^{63}, 2^{63}-1]$ onto an unbroken monotonic sequence $[0, 2^{64}-1]$.
3. **Linear Complexity:**
   Total running time is strictly $O(8 \cdot (N + 256))$, significantly outperforming $O(N \log N)$ comparison sorts on large numeric datasets.

## Grill Log

- **Q:** Why use LSD Radix Sort instead of Quicksort/Mergesort?
  **A:** Comparison sorts incur branch mispredictions and cache misses when elements bounce between branches. LSD Radix Sort has zero comparison branches and sequential memory access patterns, maximizing hardware throughput.
- **Q:** Does it preserve stability?
  **A:** Yes, LSD counting sort is strictly stable: elements with equal values maintain their original relative order.

## Referenced by

[[src/Std/_MOC]] · [[Std Math]] · [[architecture/STDLIB]]
