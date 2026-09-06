---
type: module
path: "@root/lib/Std/Column.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, column, database, vector, performance]
aliases: [Std Column]
---

# Std Column

## Purpose

Vectorized columnar database primitives and unboxed column arrays for analytical queries,
scans, and filtering running at memory-bus speeds.

## Interface

Exports:
- `ColumnU64`: Contiguous column record `{ length: Int, nullCount: Int, nullBitmap: Buffer, data: Buffer }`.
- `createU64(capacity: Int) -> ColumnU64`: Allocate an empty columnar buffer.
- `appendU64(col: &ColumnU64, value: UInt64) -> Option[ColumnU64]`: Append a non-null scalar.
- `appendNullU64(col: &ColumnU64) -> Option[ColumnU64]`: Append a null row.
- `getU64(col: &ColumnU64, row: Int) -> Option[UInt64]`: Retrieve scalar at row (or `None` if null/out-of-bounds).
- `isNull(col: &ColumnU64, row: Int) -> Bool`: Check if row is null.
- `sum(col: &ColumnU64) -> UInt64`: Hardware-accelerated vector sum.
- `min(col: &ColumnU64) -> Option[UInt64]`: Hardware-accelerated vector minimum.
- `max(col: &ColumnU64) -> Option[UInt64]`: Hardware-accelerated vector maximum.
- `filterGt(col: &ColumnU64, threshold: UInt64) -> Buffer`: Vectorized predicate scan producing selection bitmap.
- `project(col: &ColumnU64, selection: &Buffer) -> ColumnU64`: Zero-copy gather into contiguous column.
- `ColumnF64`: Contiguous unboxed 64-bit float column record `{ length: Int, nullCount: Int, nullBitmap: Buffer, data: Buffer }`.
- `createF64(capacity: Int) -> ColumnF64`: Allocate empty float column.
- `appendF64(col: &ColumnF64, value: Float64) -> Option[ColumnF64]`: Append non-null float scalar.
- `appendNullF64(col: &ColumnF64) -> Option[ColumnF64]`: Append null float row.
- `getF64(col: &ColumnF64, row: Int) -> Option[Float64]`: Retrieve float at row.
- `isNullF64(col: &ColumnF64, row: Int) -> Bool`: Check if float row is null.
- `sumF64(col: &ColumnF64) -> Float64`: Hardware vector sum.
- `minF64(col: &ColumnF64) -> Option[Float64]`: Hardware vector minimum.
- `maxF64(col: &ColumnF64) -> Option[Float64]`: Hardware vector maximum.
- `filterGtF64(col: &ColumnF64, threshold: Float64) -> Buffer`: Predicate `val > threshold`.
- `filterLtF64(col: &ColumnF64, threshold: Float64) -> Buffer`: Predicate `val < threshold`.
- `projectF64(col: &ColumnF64, selection: &Buffer) -> ColumnF64`: Gather matching float rows into contiguous column.
- `addF64(colA: &ColumnF64, colB: &ColumnF64) -> Option[ColumnF64]`: Vectorized element-wise addition.
- `bitmapAnd(b1: &Buffer, b2: &Buffer, count: Int) -> Buffer`: Bitwise AND of two selection masks.
- `bitmapOr(b1: &Buffer, b2: &Buffer, count: Int) -> Buffer`: Bitwise OR of two selection masks.
- `bitmapNot(b: &Buffer, count: Int) -> Buffer`: Bitwise inversion of selection mask.
- `bitmapCount(b: &Buffer, count: Int) -> Int`: Total matching rows in selection mask.

## Governance

- All row accesses validate bounds against column length.
- Pure functional immutability: additions and projections return fresh snapshots without mutating inputs.
- Continuous unboxed storage eliminates per-cell heap boxing.

## Grill Log

- **Q:** How does Std.Column integrate with Std.Buffer and Std.BitSet? **A:** The data and null bitmaps are backed directly by unboxed `Buffer` instances, and selection bitmaps are compatible with `BitSet` bit-level operations.
- **Q:** What is the performance target? **A:** Aggregations and scans run at hardware memory bandwidth, outperforming row-based record iterations by orders of magnitude.
- **Q:** Can multiple predicates be combined without row ID materialization? **A:** Yes; `bitmapAnd`, `bitmapOr`, and `bitmapNot` combine selection masks at 64 rows per machine cycle with zero row ID array allocations.


## Referenced by

[[src/Std/_MOC]] · [[Backend Representation Specialization]] · [[Std Db]]
