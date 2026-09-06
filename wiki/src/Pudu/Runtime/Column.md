---
type: module
path: "@root/src/Pudu/Runtime/Column.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, database, columnar, simd]
aliases: [Runtime Column Kernels]
---

# Runtime Column Kernels

## Purpose, interface and invariants

`Pudu.Runtime.Column` implements vectorized columnar storage layouts and hardware-accelerated analytical database primitives.
Columns store data contiguously in unboxed byte buffers paired with bit-packed validity bitmaps, enabling memory-bandwidth-speed scans, aggregations, and predicate evaluation.

Key operations:
- `columnSumU64 :: ByteString -> ByteString -> Int -> Word64` sums non-null rows in an unboxed 64-bit column using hardware registers.
- `columnMinU64 :: ByteString -> ByteString -> Int -> Maybe Word64` computes minimum value across non-null rows.
- `columnMaxU64 :: ByteString -> ByteString -> Int -> Maybe Word64` computes maximum value across non-null rows.
- `columnFilterGtU64 :: ByteString -> ByteString -> Int -> Word64 -> ByteString` branchlessly evaluates `x > threshold` in 64-row vector words, producing a selection bitmap.
- `columnProjectU64 :: ByteString -> ByteString -> ByteString -> Int -> (ByteString, ByteString, Int)` gathers rows matching a selection mask into a contiguous unboxed column.

## Memory layout

- Value buffer: Contiguous array of 64-bit scalar words ($8 \times N$ bytes).
- Null bitmap: Packed bitset where bit $i$ is set if row $i$ is valid (non-null), matching hardware bit-vector layouts.

## Grill Log

- **Q:** Why use columnar layouts over row records for database queries? **A:** Row records require dereferencing pointers and loading unused columns into L1/L2 cache. Columnar storage loads only queried columns, saturating memory bus bandwidth and enabling SIMD/SWAR vectorization.
- **Q:** How are null values handled in reductions? **A:** Bitmaps are checked in 64-row words (`Word64`). If a 64-row word is all-ones (`0xFFFFFFFFFFFFFFFF`), null checks are skipped completely for that block.
- **Q:** Does projection copy or allocate intermediate boxed values? **A:** No; valid rows are copied directly between unboxed buffers using machine word stores.
- **Q:** How are null bitmaps propagated during projection? **A:** The source column's validity bit is sampled for each selected row and written into the destination null bitmap, preserving null status.


## Dependencies and consumers

- **Requires:** [[Runtime Buffer Kernels]], [[Runtime Word Kernels]].
- **Consumed by:** [[Eval Column]], [[Std Column]].

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]
