---
type: module
path: "@root/src/Pudu/Compiler/Lower/Range.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Range]
---
# Compiler Lower Range

## Purpose and interface

`lowerRangeValue` builds a range from the ends written (start first), and
`lowerRangeMethod` lowers a method call on a range value.

## Methods

Arguments run before the receiver. `start` and `end` answer `Some` or `None`
in Core from the range's fields. `map`, `filter` and `reduce` reuse the array
loops of [[Compiler Lower Array]] over the range's values, which are listed
after the arguments and the range have run and fail, when an end is missing,
with the evaluator's message naming the method.

## Resolved Grill Log

- **Q:** Why not lower `map` over a range as its own loop? **A:** The array
  loops already call a closure once per item in order and push results; the
  range only has to supply the items, exactly when `elements` would.

## Dependencies and consumers

[[Compiler Lower Array]] · [[Compiler Lower State]] · [[Compiler Lower Types]] · [[Core IR]]

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower For]] · [[Compiler Lower Slice]] · [[Native Range Values]] · [[src/Pudu/Compiler/_MOC]]
