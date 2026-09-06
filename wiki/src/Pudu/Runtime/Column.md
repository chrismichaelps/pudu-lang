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
- `columnSumF64 :: ByteString -> ByteString -> Int -> Double` computes sum of 64-bit floating point column using machine registers.
- `columnMinF64 :: ByteString -> ByteString -> Int -> Maybe Double` computes minimum floating point scalar.
- `columnMaxF64 :: ByteString -> ByteString -> Int -> Maybe Double` computes maximum floating point scalar.
- `columnFilterGtF64 :: ByteString -> ByteString -> Int -> Double -> ByteString` produces selection bitmap for `val > threshold`.
- `columnFilterLtF64 :: ByteString -> ByteString -> Int -> Double -> ByteString` produces selection bitmap for `val < threshold`.
- `columnProjectF64 :: ByteString -> ByteString -> ByteString -> Int -> (ByteString, ByteString, Int)` projects floating point rows preserving validity.
- `columnAddF64 :: ByteString -> ByteString -> ByteString -> ByteString -> Int -> (ByteString, ByteString)` performs element-wise vector addition across two columns.
- `columnBitmapAnd :: ByteString -> ByteString -> Int -> ByteString` computes bitwise AND across 64-bit words for composite filters.
- `columnBitmapOr :: ByteString -> ByteString -> Int -> ByteString` computes bitwise OR across 64-bit words for composite filters.
- `columnBitmapNot :: ByteString -> Int -> ByteString` inverts active selection bits.
- `columnBitmapCount :: ByteString -> Int -> Int` calculates total active selected rows using hardware popcount.

## Memory layout

- Value buffer: Contiguous array of 64-bit scalar words ($8 \times N$ bytes).
- Null bitmap: Packed bitset where bit $i$ is set if row $i$ is valid (non-null), matching hardware bit-vector layouts.

## Grill Log

- **Q:** Why use columnar layouts over row records for database queries? **A:** Row records require dereferencing pointers and loading unused columns into L1/L2 cache. Columnar storage loads only queried columns, saturating memory bus bandwidth and enabling SIMD/SWAR vectorization.
- **Q:** How are null values handled in reductions? **A:** Bitmaps are checked in 64-row words (`Word64`). If a 64-row word is all-ones (`0xFFFFFFFFFFFFFFFF`), null checks are skipped completely for that block.
- **Q:** Does projection copy or allocate intermediate boxed values? **A:** No; valid rows are copied directly between unboxed buffers using machine word stores.
- **Q:** How are null bitmaps propagated during projection? **A:** The source column's validity bit is sampled for each selected row and written into the destination null bitmap, preserving null status.
- **Q:** How does bitmap algebra avoid temporary memory allocation in multi-predicate queries? **A:** Predicates emit packed bit-buffers that combine in 64-row machine cycles using single ALU instructions (`.&.`, `.|.`, `complement`), avoiding row ID array instantiation.



## Dependencies and consumers

- **Requires:** [[Runtime Buffer Kernels]], [[Runtime Word Kernels]].
- **Consumed by:** [[Eval Column]], [[Std Column]].

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]
