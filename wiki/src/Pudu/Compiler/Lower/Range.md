---
type: module
path: "@root/src/Pudu/Compiler/Lower/Range.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Range]
---
# Compiler Lower Range

Resolved Grill Log: forward the stored callback specializer into the
shared array loop when a held range supplies its items.

## Purpose and interface

`lowerRangeValue` builds a range from the ends written (start first), and
`lowerRangeMethod` lowers a method call on a range value.

## Methods

The receiver runs before arguments. `start` and `end` answer `Some` or `None`
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

## Runtime reduction carriers (#956)

Resolved Grill Log: range reduction uses the same accumulator
specialization as array reduction. The range is still converted to
items after evaluating both callback and seed.

## Held endpoint validation

Validate an already evaluated endpoint by its actual integer layout.
An incompatible endpoint reports the runtime kind at the range span.

Resolved Grill Log: the caller holds both written expressions before
validation. Evaluation of a later expression can transfer before any
endpoint-type failure. Type validation then checks the lower end first.

## Exact stored endpoints

Range construction validates the held integers after evaluation and
stores both at their original mathematical magnitude. Contains accepts
all held integer widths. Endpoint access keeps the ordinary Int layout
for values that fit and retains the mathematical value when wider.

Resolved Grill Log: no endpoint conversion can alter its sign or
magnitude. Open ranges retain the distinction between missing and zero.

## Exact materialized range members

Select the array element layout from the first and last included
members. The callback traversal uses that layout after retaining the
receiver. Finite sums use the exact progression and check only their
final Int result.

Resolved Grill Log: an exclusive upper endpoint one past Int maximum
can still have only Int members. An empty range has the ordinary array
layout regardless of its endpoints.

## Exact Int layout

Resolved Grill Log: Store mathematical endpoints as exact integers. Expose out-of-range members with their Int identity through endpoint reads, arrays and callbacks.

## Held collection member selection

Resolved Grill Log: Range calls consume the selected range and preserve its method result layout. A selected endpoint method fixes the Option payload from the range operation.

## Exact held range strides

Resolved Grill Log: The held stride uses integer selection. Materialization receives its original mathematical value. A wrong argument is diagnosed after operand evaluation.
