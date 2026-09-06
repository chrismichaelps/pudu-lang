---
type: module
path: "@root/src/Pudu/Eval/Column.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, database, columnar]
aliases: [Eval Column]
---

# Eval Column

## Purpose, interface and invariants

`Pudu.Eval.Column` adapts [[Runtime Column Kernels]] for the evaluator, providing pure builtins for vectorized column operations:
- `callColumnSumU64`: Sums valid rows in a 64-bit integer column.
- `callColumnMinU64`: Answers minimum value as `Option[UInt64]`.
- `callColumnMaxU64`: Answers maximum value as `Option[UInt64]`.
- `callColumnFilterGtU64`: Evaluates `x > threshold` across column rows, answering a packed selection bitmap as `Bytes`.
- `callColumnProjectU64`: Gathers matching rows according to selection bitmap into a new column record.

## Grill Log

- **Q:** Return boxed lists from columnar aggregations? **A:** No; aggregations produce unboxed scalar results directly.
- **Q:** How are malformed column buffers validated? **A:** Lengths and byte sizes are checked against the row count. Mismatches abort with diagnostic E7001 or E7004.
- **Q:** How are selection masks integrated with BitSet? **A:** Selection bitmaps use the same packed 64-bit word format as `Std.BitSet`, enabling zero-cost conversions to bitsets.

## Dependencies and consumers

- **Requires:** [[Runtime Column Kernels]], [[Eval Env]], [[Eval Value]].
- **Consumed by:** [[Eval Builtin]], [[Std Column]].

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]
