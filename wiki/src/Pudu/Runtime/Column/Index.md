---
type: module
path: "@root/src/Pudu/Runtime/Column/Index.hs"
fidelity: Active
domain: "[[Runtime]]"
subsystem: "[[Performance]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 1.5
interface_stability: 0.9
tags: [module, medium, runtime, columnar, index]
aliases: [Runtime Column Index]
---

# Runtime Column Index

## Purpose

Vectorized permutation indexing, sorting, binary search, and gather operations for columnar storage layouts.

## Interface

```haskell
isRowValid :: ByteString -> Int -> Bool
columnSortIndicesU64 :: ByteString -> ByteString -> Int -> ByteString
columnSortIndicesF64 :: ByteString -> ByteString -> Int -> ByteString
columnBinarySearchU64 :: ByteString -> ByteString -> Int -> Word64 -> Maybe Int
columnBinarySearchF64 :: ByteString -> ByteString -> Int -> Double -> Maybe Int
columnGatherU64 :: ByteString -> ByteString -> ByteString -> Int -> (ByteString, ByteString, Int)
columnGatherF64 :: ByteString -> ByteString -> ByteString -> Int -> (ByteString, ByteString, Int)
```

## Governance

- **Permutation Index Buffer:** Unboxed 64-bit row offsets ($8 \times N$ bytes), enabling zero-copy logical sorting without rewriting underlying columnar data.
- **Nulls Last Sorting:** `columnSortIndicesU64` and `columnSortIndicesF64` partition non-null rows from null rows, sorting non-null values in ascending order and placing all null rows at the end (`NULLS LAST`).
- **Logarithmic Search:** `columnBinarySearchU64` and `columnBinarySearchF64` perform $O(\log N)$ binary search over the valid segment of the permutation index buffer.
- **Gather:** `columnGatherU64` and `columnGatherF64` project row elements in permutation order into a new contiguous unboxed column buffer with reconstructed null bitmap.

## Linkage

- **Requires:** `Pudu.Runtime.Buffer`.
- **Consumed by:** `Pudu.Runtime.Column`.

## Negative Logic (Prohibited Paths)

- No in-place buffer mutation of existing column value buffers.
- No boxing of row elements or intermediate arrays during gather.

## Grill Log

- **Q:** Why extract permutation indexing into `Pudu.Runtime.Column.Index`? **A:** Permutation sorting, binary search, and gather kernels represent an index-acceleration layer (~135 lines) distinct from base columnar aggregations and filtering, keeping `Pudu.Runtime.Column` well below 500 lines.
