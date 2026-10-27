---
type: module
path: "@root/src/Pudu/Compiler/Lower/Slice.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Slice]
---
# Compiler Lower Slice

## Purpose and interface

`lowerRangeIndex` lowers `items[a..b]`, `items[a..=b]`, `items[a..]`,
`items[..b]` and `items[..]` on an array or a Str when the range is written
in the brackets. It answers Nothing for anything else, and
[[Compiler Lower Body]] falls through to ordinary indexing.

## Algorithm

The receiver runs, then the start, then the end, the order `readIndex` sees
them in. The length is read once (characters for Str). Then the checks are
`rangeBounds`' own: a start below zero or past the length, or an end below
zero or past the length (at it, for `..=`), fails with E7004 "slice range out
of bounds" and help naming the length; an end before the start fails with
"slice range ends before it starts". Only then does the slice run, so the
runtime's clamping slice has nothing left to clamp. Failures report at the
range.

## Resolved Grill Log

- **Q:** Why build the checks in Core rather than a runtime helper? **A:** The
  comparisons are ordinary Int operations and the slices already exist. The
  one new thing is help text that names the length, which `CoreFailText` now
  carries.
- **Q:** Can the inclusive end overflow when it becomes exclusive? **A:** No.
  It is only incremented after the check proved it is below the length.
- A range held in a variable is a range value and is not covered here.

## Dependencies and consumers

[[Compiler Lower Array]] · [[Compiler Lower State]] · [[Compiler Lower Types]] · [[Core IR]]

## Referenced by

[[Compiler Lower Body]] · [[Native Arrays]] · [[src/Pudu/Compiler/_MOC]]
