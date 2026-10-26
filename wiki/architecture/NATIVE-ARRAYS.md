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

## Not yet

`sortBy` (its comparison order must be the evaluator's natural merge sort),
sequence patterns, slicing by a range, and arrays of types without a native
form refuse with E6001. Lambdas whose facts checking left unsolved (#557)
refuse too.

## Resolved Grill Log

- A box around a separate buffer, so growing never moves what slots point at.
- Moves for dead temporaries rather than an ownership analysis: the store is
  the last use by construction, and binding a pattern from a match subject
  keeps copying because a failed guard reads the subject again.

## Referenced by

[[Native Emission Coverage]] · [[Compiler Lower Array]] · [[Backend Array Programs]]
