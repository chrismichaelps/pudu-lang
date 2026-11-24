---
type: module
path: "@root/src/Pudu/Backend/Runtime/Range.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Range Runtime]
---
# Native Range Runtime

## Purpose and interface

Export rangeRuntimeParts and rangeRuntimeDependencies. A range is a box of
five cells: whether it has a start, the start, whether it is inclusive,
whether it has an end, and the end. Every range is `Range[Int]`, so one set of
functions serves every program.

| Part | Provides |
| --- | --- |
| range | `pudu_range_make` and the field readers |
| range_length / range_is_empty / range_contains | `Eval.Range`'s arithmetic on the ends |
| range_elements / range_reversed / range_step / range_sum | the values, failing as `elements` does on an unbounded range |
| range_show / range_equal / range_compare | rendering as written, `==`, and `compareValues`' order |

## Semantics

`length` is the distance between the ends, plus one when inclusive, and nought
when the end is below the start; past Int it is E7005. A method that needs the
values fails with E7004 naming itself when an end is missing. `step` refuses a
stride below one before it looks at the ends. `sum` computes the exact
arithmetic progression and fails with E7005 only when the total does not fit. Two ranges compare by
start, then end, then inclusiveness, an absent end sorting first.

## Resolved Grill Log

- **Q:** Why a box rather than five loose values? **A:** A range is a value
  that is passed, stored in collections and compared; a box keeps it one cell
  like every other aggregate.
- **Q:** Why use a progression formula? **A:** The number of terms times
  the sum of the first and last included terms is always even. Exact
  multiplication and division preserve the final checked result without
  walking the interval.
- **Q:** Where do the failure texts come from? **A:** Each helper takes its
  sites, so the message names the method the program called.

## Dependencies and consumers

[[Backend Runtime Array]] · [[Backend Runtime Integer]]

## Referenced by

[[Backend Emit Range]] · [[Backend Frame Program]] · [[Native Range Values]] · [[src/Pudu/Backend/_MOC]]

## Exact endpoint storage

A range owns one exact integer for each present endpoint. Its flags
preserve absence and inclusiveness. Comparison, rendering, contains,
and finite extent use the original endpoints. The sum uses the exact
arithmetic progression formula.

Resolved Grill Log: a stored end and its presence are independent,
since zero has an empty integer allocation. Compare before converting
for a narrower consumer. Drop both owned ends with the range.

## Exact held range strides

Resolved Grill Log: Compute the stepped result count as one plus the exact quotient of extent minus one by stride. Allocate only the selected terms.
