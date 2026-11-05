---
type: module
path: "@root/lib/Std/StringView.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, view, text]
aliases: [Std StringView]
---

# Std StringView

## Purpose

A byte-addressed view of UTF-8 text whose size and slices take constant time and share the source's bytes.

## Interface

- `StringView = { text }`, `of(text)`.
- `View`: `size`, `isEmpty`, `toText`, `substr`, `removePrefix`, `removeSuffix`, `startsWith`, `endsWith`, `contains`, `find`, `findLast`, `findLastFrom`, `byteAt`, `byteUnits`, `compare`, `findFirstOf`, `findLastOf`, `findFirstNotOf`, `findLastNotOf`, `copyInto`, `scalarAt`, `front`, `back`, `trim`, `splitOnce`, `scalars`, `split`.
- `Scalars` (a `Sequence` of `Char`) and `Pieces` (a lazy `Sequence` of `StringView`).

## Invariants

- Offsets are UTF-8 bytes. Text slicing and scalar decoding refuse offsets inside scalars with `None`, never moved. Byte reads/searches/copy may use interior code units.
- Size and slicing are constant time ([[Eval TextView]]); `find` is a forward search, `findLast` a backward one that includes overlapping matches.
- `split` with an empty separator yields the whole view once; `Pieces` asks for each separator only when the walk reaches it.

## Grill Log

- **Q:** Bytes or scalars? **A:** Bytes. A scalar offset costs a walk from the start, which is what a view exists to avoid; `Str` already serves scalar positions.
- **Q:** Hold a source and two offsets? **A:** No; the runtime's byte slice already shares storage, so the view holds the slice itself and every method reads it directly.
- **Q:** `toText` as a member? **A:** Yes; a view's text is what it displays, so printing a view prints the text it shows.

## Dependencies and consumers

- **Requires:** [[Std Iter]], [[Eval TextView]], [[Std StringView Search]].
- **Consumed by:** programs; `test-fixtures/stdlib/UsesStringView.pudu`.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]

## Completion contract (#527)

Add byteAt, byteUnits, compare, findLastFrom, four byte-set searches and
copyInto. [[Std StringView Search]] owns pure helper algorithms and byte-unit
iteration, independent of StringView itself, so imports stay acyclic.
copyInto validates offsets/count/capacity before any destination write.
Bounded reverse search truncates a shared prefix at the preceding scalar
boundary, then uses the existing reverse kernel; no invalid Text or repeated
forward searches. Empty needles retain code-unit offset semantics.

Resolved Grill Log: preserve existing APIs and scalar-end methods; new byte
operations explicitly use UTF-8 code units. New searches accept explicit
positions rather than introducing overloads. See [[C++ Inspired View Coverage]].
