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
- `appendU64(col: &ColumnU64, value: UInt64) -> ColumnU64`: Append a non-null scalar.
- `appendNullU64(col: &ColumnU64) -> ColumnU64`: Append a null row.
- `getU64(col: &ColumnU64, row: Int) -> Option[UInt64]`: Retrieve scalar at row (or `None` if null/out-of-bounds).
- `isNull(col: &ColumnU64, row: Int) -> Bool`: Check if row is null.
- `sum(col: &ColumnU64) -> Option[UInt64]`: Hardware-accelerated vector sum.
- `min(col: &ColumnU64) -> Option[UInt64]`: Hardware-accelerated vector minimum.
- `max(col: &ColumnU64) -> Option[UInt64]`: Hardware-accelerated vector maximum.
- `filterGt(col: &ColumnU64, threshold: UInt64) -> Buffer`: Vectorized predicate scan producing selection bitmap.
- `project(col: &ColumnU64, selection: &Buffer) -> ColumnU64`: Zero-copy gather into contiguous column.

## Governance

- All row accesses validate bounds against column length.
- Pure functional immutability: additions and projections return fresh snapshots without mutating inputs.
- Continuous unboxed storage eliminates per-cell heap boxing.

## Grill Log

- **Q:** How does Std.Column integrate with Std.Buffer and Std.BitSet? **A:** The data and null bitmaps are backed directly by unboxed `Buffer` instances, and selection bitmaps are compatible with `BitSet` bit-level operations.
- **Q:** What is the performance target? **A:** Aggregations and scans run at hardware memory bandwidth, outperforming row-based record iterations by orders of magnitude.

## Referenced by

[[src/Std/_MOC]] · [[Backend Representation Specialization]] · [[Std Db]]
