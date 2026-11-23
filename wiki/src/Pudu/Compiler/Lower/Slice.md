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
runtime's clamping slice has nothing left to clamp. A failure reports at the range, the span `readIndex` is given for the key.

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

## Range values (#564)

A range held in a value is checked at run time from its fields, with the
same messages; absent ends read as nought and the end test applies only when
there is an end.

## Bytes (#565)

Bytes slice by written ranges and range values like arrays, counting bytes.

## Referenced by

[[Compiler Lower Body]] · [[Native Arrays]] · [[src/Pudu/Compiler/_MOC]]

## Failure location (#958)

Resolved Grill Log: the range is where a slice fails in both engines, whether the slice is bound, passed or used as a method receiver (#958).

## Array runtime elements (#956)

Resolved Grill Log: a slice preserves its lowered receiver's element
carrier for written bounds and ranges held in a value.

## Selected receiver layouts (#956)

Resolved Grill Log: Select the held slice receiver and preserve the order of all written range ends before reporting an unsupported receiver.

## Exact written slice endpoints

Written and stored slice keys share the same checked slice operation.
A written endpoint can retain any integer width. Check its original
mathematical value against the length, then convert for the actual
slice. Select stored keys and receivers independently.

Resolved Grill Log: evaluate the receiver and both written expressions
before validating endpoints. A wrong endpoint type therefore precedes
receiver dispatch and bounds validation. Only a proven in-bounds
inclusive end may be incremented.
