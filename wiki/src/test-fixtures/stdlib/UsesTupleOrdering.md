---
type: module
path: "@root/test-fixtures/stdlib/UsesTupleOrdering.pudu"
fidelity: Active
tags: [test, tuple, ordering]
aliases: [Uses Tuple Ordering]
---
# Uses Tuple Ordering

## Purpose and algorithm

Exercise tuple ordering through constants, ordinary calls, generic calls and stable array/list
sorting by two-part keys. Assert all four ordering relations, equal boundaries, nested tuples,
comparable aggregate fields and unchanged equality. Successful execution returns exactly zero.

## Resolved Grill Log

- **Q:** Normalize Decimal scale to compare? **A:** No; numeric order preserves representation.
- **Q:** Leave duplicate sort keys untested? **A:** No; inspect their original order in the result.

## Referenced by

[[Eval Arithmetic Tests]] · [[Eval Operator]] · [[src/_MOC]]
