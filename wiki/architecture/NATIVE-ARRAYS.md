---
type: architecture
status: IMPLEMENTED
tags: [architecture, backend, arrays]
aliases: [Native Arrays]
---
# Native Arrays

`Array[T]` is a box whose single field points at a growable buffer of cells.
The box is what slots hold and count; the buffer changes only while the box has
one owner.

## Contract

- **Values.** Literals, indexing, `for` and every runtime method follow
  `Eval.Array` and `callArrayMethod`, edge cases included. Rendering is
  `renderValue`'s `[a, b]`. Equality is item by item, ordering inside tuples is
  `compareLists`, and ordering arrays directly is E7001, as in the evaluator.
- **Callbacks.** `map`, `filter` and `reduce` are loops calling the closure once
  per item, in order ([[Compiler Lower Array]]).
- **Cost.** The evaluator's arrays are persistent, so building one item by item
  is linear there, and it must stay linear natively. `x = x.push(...)` takes `x`,
  and every store from a finished temporary moves instead of copying
  ([[Compiler Frame State]]). The buffer therefore keeps one owner and grows in
  place. A million pushes run in about a third of a second.
- **Safety.** Every update checks the box's count. Anything that might still be
  observed is copied first.

- **Sorting.** `sortBy` asks its comparison exactly what `Eval.Sort.sortWith`
  asks, in the same order ([[Compiler Lower Sort]]).
- **Patterns and slices.** Sequence patterns test the length first, as
  `matchPattern` does, and a bound rest is a slice. `items[a..b]` and its other
  written shapes check the range as `rangeBounds` does and fail with the same
  E7004 text, help included ([[Compiler Lower Slice]]). (#558)

## Not yet

Arrays of types without a native form refuse with E6001. A range held in a
variable is a range value, which is not native yet. Lambdas whose facts
checking left unsolved (#557) refuse too.

## Resolved Grill Log

- A box around a separate buffer, so growing never moves what slots point at.
- Moves for dead temporaries rather than an ownership analysis: the store is
  the last use by construction, and binding a pattern from a match subject
  keeps copying because a failed guard reads the subject again.

## Referenced by

[[Native Emission Coverage]] · [[Compiler Lower Array]] · [[Backend Array Programs]] · [[Backend Array Pattern Programs]]
