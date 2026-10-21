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
- `View`: `size`, `isEmpty`, `toText`, `substr`, `removePrefix`, `removeSuffix`, `startsWith`, `endsWith`, `contains`, `find`, `findLast`, `scalarAt`, `front`, `back`, `trim`, `splitOnce`, `scalars`, `split`.
- `Scalars` (a `Sequence` of `Char`) and `Pieces` (a lazy `Sequence` of `StringView`).

## Invariants

- Offsets are UTF-8 bytes. An offset that falls inside a scalar is refused with `None`, never moved.
- Size and slicing are constant time ([[Eval TextView]]); `find` is a forward search, `findLast` a backward one that includes overlapping matches.
- `split` with an empty separator yields the whole view once; `Pieces` asks for each separator only when the walk reaches it.

## Grill Log

- **Q:** Bytes or scalars? **A:** Bytes. A scalar offset costs a walk from the start, which is what a view exists to avoid; `Str` already serves scalar positions.
- **Q:** Hold a source and two offsets? **A:** No; the runtime's byte slice already shares storage, so the view holds the slice itself and every method reads it directly.
- **Q:** `toText` as a member? **A:** Yes; a view's text is what it displays, so printing a view prints the text it shows.

## Dependencies and consumers

- **Requires:** [[Std Iter]], [[Eval TextView]].
- **Consumed by:** programs; `test-fixtures/stdlib/UsesStringView.pudu`.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
