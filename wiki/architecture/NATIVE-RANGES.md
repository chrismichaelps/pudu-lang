---
type: architecture
status: IMPLEMENTED
tags: [architecture, backend, ranges]
aliases: [Native Range Values]
---
# Native Range Values

A range value is a small box of its two optional ends and whether the end is
included ([[Native Range Runtime]]). Ranges written directly in a `for` head
or in brackets keep their faster lowering; anything else is a value.

## Contract

- **Methods.** All fourteen, with `Eval.Range`'s answers and failures; the
  closures of `map`, `filter` and `reduce` run once per value, in order
  ([[Compiler Lower Range]]).
- **Values.** Rendered as written (`1..3`, `..=5`, `2..`, `..`); equal when
  their ends and inclusiveness are; ordered by start, end, then inclusiveness.
- **Iteration and slicing.** `for` walks a bounded range and fails with E7001
  on an unbounded one; slicing by a range value checks it as `rangeBounds` does.

## Referenced by

[[Native Emission Coverage]] · [[Compiler Lower Range]] · [[Backend Emit Range]] · [[Native Range Runtime]]
