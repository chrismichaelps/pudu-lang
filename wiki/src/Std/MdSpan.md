---
type: module
path: "@root/lib/Std/MdSpan.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, view, sequence]
aliases: [Std MdSpan]
---

# Std MdSpan

## Purpose

A non-owning multidimensional view of an `Array[T]`, with layouts, multi-index reads and slicing that never copies.

## Interface

- `MdSpan[T] = { source, offset, extents, strides }`; `rowMajor`, `columnMajor` and `strided` constructors answer `Option`.
- `Slice = All | At(Int) | Within(Int, Int) | Every{first, last, step}`.
- `Grid[T]`: `rank`, `extent(dimension) -> Option[Int]`, `size`, `get(indices)`, `get2`, `get3`, `slice(slices) -> Option[MdSpan[T]]`.
- `Sequence[Int, T]` in row-major order of the view, overriding `count` and `isEmpty`.

## Invariants

- Position `[i0, i1, ...]` is `source[offset + Σ i_d * strides[d]]`. Every constructor checks that the furthest reachable position is inside the array, so every in-range read is in bounds.
- Strides and extents are at least nought; a zero extent makes an empty view whatever the array holds.
- `At` drops its dimension; fixing every dimension leaves a rank-0 view of one item, read with `get([])`.
- `Every{first, last, step}` keeps `ceil((last - first) / step)` positions, and its stride is the dimension's stride times `step`.

## Grill Log

- **Q:** An index operator `grid[i, j]`? **A:** The language has no overloadable index operator; `get` takes the whole position and `get2`/`get3` cover the common ranks without building an array.
- **Q:** Negative strides? **A:** No, as in the reference API; a reversed walk is a different view, not a stride.
- **Q:** What does iteration carry? **A:** The ordinal in row-major order, decoded into a position on each step, so a step allocates nothing beyond the protocol's own pair.

## Dependencies and consumers

- **Requires:** [[Std Iter]].
- **Consumed by:** programs; `test-fixtures/stdlib/UsesMdSpan.pudu`.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
